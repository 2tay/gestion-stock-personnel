import '../../../../core/constants/app_enums.dart';
import '../../../stock/domain/entities/product.dart';
import '../../../stock/domain/entities/stock_movement.dart';
import '../../../stock/domain/repositories/product_repository.dart';
import '../entities/purchase_order.dart';
import '../repositories/purchasing_repositories.dart';

/// Un prix payé qui ne correspond pas au tarif enregistré du fournisseur.
///
/// Constaté, jamais appliqué d'office : une promotion ponctuelle et une
/// hausse durable sont indiscernables par la machine, et seul l'utilisateur
/// sait laquelle il vient de vivre. Appliquer automatiquement reviendrait à
/// apprendre un tarif faux une fois sur deux.
class SupplierPriceDiscrepancy {
  const SupplierPriceDiscrepancy({
    required this.productId,
    required this.productName,
    required this.emoji,
    required this.unit,
    required this.supplierId,
    required this.supplierName,
    required this.paidPrice,
    required this.knownPrice,
  });

  final String productId;
  final String productName;
  final String emoji;
  final String unit;
  final String supplierId;
  final String supplierName;

  /// Prix de la ligne de commande, celui qui vient d'être payé.
  final double paidPrice;

  /// Tarif enregistré pour ce fournisseur au moment de la réception.
  final double knownPrice;

  double get difference => paidPrice - knownPrice;

  double? get ratio =>
      knownPrice == 0 ? null : (paidPrice - knownPrice) / knownPrice;

  bool get isIncrease => paidPrice > knownPrice;
}

/// Résultat d'une réception, affiché à l'utilisateur et utilisé pour
/// rafraîchir le module Stock.
class OrderReceptionResult {
  const OrderReceptionResult({
    required this.order,
    required this.receivedProductIds,
    required this.correctedProductIds,
    required this.priceDiscrepancies,
    required this.receivedValue,
  });

  final PurchaseOrder order;

  /// Produits dont le stock a augmenté lors de cette réception.
  final List<String> receivedProductIds;

  /// Produits dont la quantité reçue a été corrigée à la baisse.
  final List<String> correctedProductIds;

  /// Écarts entre le prix payé et le tarif enregistré du fournisseur.
  ///
  /// Rien n'a été modifié : c'est à l'appelant de demander à l'utilisateur
  /// s'il veut mettre les tarifs à jour, puis d'appeler `ApplySupplierPrices`.
  final List<SupplierPriceDiscrepancy> priceDiscrepancies;

  bool get hasPriceDiscrepancies => priceDiscrepancies.isNotEmpty;

  /// Valeur de ce qui vient d'être reçu, aux prix de la commande.
  final double receivedValue;

  int get linesReceived => receivedProductIds.length;
  int get linesCorrected => correctedProductIds.length;

  /// Tous les produits touchés — c'est ce que le module Stock doit
  /// rafraîchir.
  List<String> get touchedProductIds => <String>{
        ...receivedProductIds,
        ...correctedProductIds,
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
/// 3. **Le coût moyen est recalculé, jamais écrasé.** Recevoir 20 kg à 18
///    quand on en détient 100 à 12 porte le coût moyen à 13, pas à 18 : la
///    valeur du stock devient 1 560 MAD, exactement ce qui a été dépensé.
///    Le calcul lui-même vit dans `Product.averageCostAfter`, parce qu'il
///    relève du stock et non des achats. Une correction à la baisse applique
///    la même formule au prix de l'entrée d'origine, et restitue donc
///    exactement le coût moyen d'avant.
///
///    Le dernier prix payé est consigné à part — `lastPurchasePrice`,
///    `lastPurchaseDate`, `lastSupplierId` — et reste **informatif** : c'est
///    la fiche produit qui l'affiche, aucun calcul de valeur ne s'en sert.
///    Une correction n'est pas un achat et ne le met donc pas à jour.
/// 4. **Le tarif du fournisseur ne bouge pas tout seul.** Un prix payé
///    différent du tarif enregistré est *constaté* et remonté dans
///    `priceDiscrepancies` ; c'est l'interface qui demande à l'utilisateur
///    s'il faut mettre le tarif à jour, et `ApplySupplierPrices` qui écrit.
///    Une promotion ponctuelle et une hausse durable se ressemblent trop
///    pour être départagées sans lui.
/// 5. **Chaque mouvement porte la référence de la commande**, sa date, son
///    utilisateur, le prix payé et le fournisseur. Le prix figé sur le
///    mouvement est ce qui permettra de valoriser le stock sans réécrire
///    l'historique (`ROADMAP.md`, phase 6c).
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
    final List<SupplierPriceDiscrepancy> discrepancies =
        <SupplierPriceDiscrepancy>[];
    double receivedValue = 0;

    for (final OrderLine line in order.lines) {
      final double? cumulative = receivedQuantities[line.productId];
      if (cumulative == null) continue;

      // Ce qui vient réellement d'arriver depuis la dernière réception.
      final double delta = cumulative - line.quantityReceived;
      if (delta == 0) continue;

      // Lu avant le mouvement : c'est le stock d'avant qui pondère l'ancien
      // coût moyen.
      final Product? before = await _products.fetchProduct(line.productId);
      if (before == null) continue;
      final double newAverageCost = before.averageCostAfter(
        quantity: delta,
        unitPrice: line.unitPrice,
      );

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
          // Le prix négocié sur la ligne, figé à la commande. Une correction
          // à la baisse reprend le même prix : elle annule une entrée de
          // cette commande, donc au prix de cette commande.
          unitCost: line.unitPrice,
          supplierId: order.supplierId,
        ),
      );

      if (delta > 0) {
        received.add(line.productId);
        receivedValue += delta * line.unitPrice;

        // Le tarif enregistré diffère-t-il de ce qu'on vient de payer ?
        // On le constate ; on ne l'applique pas.
        final ProductSupplier? supplier =
            before.supplierById(order.supplierId);
        if (supplier != null && supplier.unitPrice != line.unitPrice) {
          discrepancies.add(
            SupplierPriceDiscrepancy(
              productId: line.productId,
              productName: line.productName,
              emoji: line.emoji,
              unit: line.unit,
              supplierId: order.supplierId,
              supplierName: order.supplierName,
              paidPrice: line.unitPrice,
              knownPrice: supplier.unitPrice,
            ),
          );
        }

        await _products.saveProduct(
          updated.copyWith(
            averageCost: newAverageCost,
            lastPurchasePrice: line.unitPrice,
            lastPurchaseDate: now,
            lastSupplierId: order.supplierId,
          ),
        );
      } else {
        corrected.add(line.productId);
        // Une correction annule une entrée : le coût moyen revient en
        // arrière, mais le dernier prix payé n'est pas réécrit — cette
        // livraison a bien eu lieu à ce prix-là.
        await _products.saveProduct(
          updated.copyWith(averageCost: newAverageCost),
        );
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
      priceDiscrepancies: discrepancies,
      receivedValue: receivedValue,
    );
  }
}
