import '../../../../core/constants/app_enums.dart';
import '../../../stock/domain/repositories/product_repository.dart';
import 'receive_order.dart';

/// Applique au catalogue les tarifs constatés lors d'une réception.
///
/// Quatrième cas d'usage inter-modules, et le plus court : il traduit une
/// décision de l'utilisateur en écritures dans le module Stock.
///
/// Il existe séparément de [ReceiveOrder] pour une raison de fond :
/// **recevoir de la marchandise et apprendre un tarif sont deux décisions
/// distinctes.** La première est un fait — la livraison est arrivée. La
/// seconde est un jugement : ce prix va-t-il durer ? Les mélanger dans une
/// seule opération, c'est ce que faisait l'ancien code, et c'est ainsi qu'un
/// prix promotionnel devenait silencieusement le tarif de référence.
///
/// L'écriture est un **ajout** : `recordSupplierPrice` empile un nouveau
/// tarif sans effacer le précédent, avec `PriceSource.reception` pour qu'on
/// sache plus tard qu'il a été constaté à la livraison et non négocié.
class ApplySupplierPrices {
  const ApplySupplierPrices({required ProductRepository products})
      : _products = products;

  final ProductRepository _products;

  /// Renvoie les identifiants des produits dont le tarif a changé, pour que
  /// le module Stock sache quoi rafraîchir.
  Future<List<String>> call(
    Iterable<SupplierPriceDiscrepancy> discrepancies, {
    DateTime? at,
    String? note,
  }) async {
    final DateTime validFrom = at ?? DateTime.now();
    final List<String> updated = <String>[];

    for (final SupplierPriceDiscrepancy discrepancy in discrepancies) {
      await _products.recordSupplierPrice(
        productId: discrepancy.productId,
        supplierId: discrepancy.supplierId,
        unitPrice: discrepancy.paidPrice,
        validFrom: validFrom,
        source: PriceSource.reception,
        note: note,
      );
      updated.add(discrepancy.productId);
    }

    return updated;
  }
}
