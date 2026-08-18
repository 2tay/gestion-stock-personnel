import '../../../../core/constants/app_enums.dart';
import '../../../stock/domain/entities/product.dart';
import '../../../stock/domain/entities/stock_movement.dart';
import '../../../stock/domain/repositories/product_repository.dart';
import '../entities/purchase_order.dart';
import '../repositories/purchasing_repositories.dart';

/// Résultat d'une réception, affiché à l'utilisateur et utilisé pour
/// rafraîchir le module Stock.
class OrderReceptionResult {
  const OrderReceptionResult({
    required this.order,
    required this.receivedProductIds,
    required this.correctedProductIds,
    required this.repricedProductIds,
    required this.receivedValue,
  });

  final PurchaseOrder order;

  /// Produits dont le stock a augmenté lors de cette réception.
  final List<String> receivedProductIds;

  /// Produits dont la quantité reçue a été corrigée à la baisse.
  final List<String> correctedProductIds;

  /// Produits dont le prix d'achat de référence a été mis à jour.
  final List<String> repricedProductIds;

  /// Valeur de ce qui vient d'être reçu, aux prix de la commande.
  final double receivedValue;

  int get linesReceived => receivedProductIds.length;
  int get linesCorrected => correctedProductIds.length;

  /// Tous les produits touchés — c'est ce que le module Stock doit
  /// rafraîchir.
  List<String> get touchedProductIds => <String>{
        ...receivedProductIds,
        ...correctedProductIds,
        ...repricedProductIds,
      }.toList();
}

/// Enregistre une réception : met le stock à jour et met à jour la commande.
///
/// Deuxième point de rencontre entre deux modules, après la validation
/// d'inventaire, et construit exactement de la même façon : le cas d'usage
/// reçoit les deux **interfaces** de dépôt, n'implémente qu'une règle métier
/// et ne connaît ni Flutter ni Riverpod.
///
/// Quatre règles :
///
/// 1. **On écrit l'écart, pas le cumul.** L'interface saisit la quantité
///    totale reçue depuis le début (« 40 sur 50 »), parce que c'est ce qui
///    fait sens pour l'utilisateur. Le mouvement de stock, lui, ne porte que
///    ce qui vient d'arriver. Sans cela, recevoir 40 puis 50 ajouterait 90 au
///    stock.
/// 2. **Une correction à la baisse est un ajustement, pas une entrée.** Si on
///    s'est trompé et qu'on ramène 40 à 35, le stock baisse de 5 avec le type
///    `ajustement` : une entrée négative n'aurait aucun sens dans
///    l'historique.
/// 3. **Le prix d'achat de référence du produit suit le prix de la
///    commande.** `Product.unitPrice` est défini comme le dernier prix
///    d'achat ; recevoir de la marchandise à un nouveau prix le met à jour, ce
///    qui fait évoluer la valeur du stock.
/// 4. **Chaque mouvement porte la référence de la commande**, sa date et son
///    utilisateur.
class ReceiveOrder {
  const ReceiveOrder({
    required PurchaseOrderRepository orders,
    required ProductRepository products,
  })  : _orders = orders,
        _products = products;

  final PurchaseOrderRepository _orders;
  final ProductRepository _products;

  /// [receivedQuantities] contient, par produit, la quantité **cumulée**
  /// reçue telle qu'elle est saisie dans l'écran de réception.
  Future<OrderReceptionResult> call(
    PurchaseOrder order, {
    required Map<String, double> receivedQuantities,
    required String receivedBy,
  }) async {
    if (!order.isReceivable) {
      throw StateError(
        'La commande ${order.reference} n’accepte plus de réception '
        '(statut : ${order.status.name}).',
      );
    }

    final DateTime now = DateTime.now();
    final List<String> received = <String>[];
    final List<String> corrected = <String>[];
    final List<String> repriced = <String>[];
    double receivedValue = 0;

    for (final OrderLine line in order.lines) {
      final double? cumulative = receivedQuantities[line.productId];
      if (cumulative == null) continue;

      // Ce qui vient réellement d'arriver depuis la dernière réception.
      final double delta = cumulative - line.quantityReceived;
      if (delta == 0) continue;

      final Product updated = await _products.registerMovement(
        StockMovement(
          id: '',
          productId: line.productId,
          date: now,
          type: delta > 0 ? MovementType.entree : MovementType.ajustement,
          quantity: delta,
          reference: order.reference,
          user: receivedBy,
          note: delta > 0 ? null : 'Correction de réception',
        ),
      );

      if (delta > 0) {
        received.add(line.productId);
        receivedValue += delta * line.unitPrice;

        // Le prix de la commande devient le dernier prix d'achat connu.
        if (updated.unitPrice != line.unitPrice) {
          await _products.saveProduct(
            updated.copyWith(unitPrice: line.unitPrice),
          );
          repriced.add(line.productId);
        }
      } else {
        corrected.add(line.productId);
      }
    }

    final PurchaseOrder saved = await _orders.saveReceivedQuantities(
      orderId: order.id,
      quantitiesByProductId: receivedQuantities,
    );

    return OrderReceptionResult(
      order: saved,
      receivedProductIds: received,
      correctedProductIds: corrected,
      repricedProductIds: repriced,
      receivedValue: receivedValue,
    );
  }
}
