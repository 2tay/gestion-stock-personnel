import '../../../../core/constants/app_enums.dart';
import '../../../stock/domain/entities/stock_movement.dart';
import '../../../stock/domain/repositories/product_repository.dart';
import '../entities/inventory.dart';
import '../entities/inventory_line.dart';
import '../repositories/inventory_repository.dart';

/// Résultat d'une validation, affiché à l'utilisateur dans la confirmation.
class InventoryValidationResult {
  const InventoryValidationResult({
    required this.inventory,
    required this.adjustmentsApplied,
    required this.linesSkipped,
    required this.totalVarianceValue,
  });

  final Inventory inventory;

  /// Nombre de mouvements d'ajustement écrits dans le stock.
  final int adjustmentsApplied;

  /// Lignes non comptées, laissées telles quelles.
  final int linesSkipped;

  final double totalVarianceValue;
}

/// Applique les écarts d'un inventaire au stock, puis marque l'inventaire
/// comme validé.
///
/// C'est le point de rencontre des deux modules, et la seule opération
/// irréversible du module Inventaire. Trois règles la gouvernent :
///
/// 1. **Seules les lignes comptées produisent un mouvement.** Une ligne non
///    comptée (`countedStock == null`) est ignorée : son stock reste
///    inchangé. Sans cette règle, un inventaire partiel viderait le stock de
///    tout ce que personne n'a compté.
/// 2. **Seuls les écarts non nuls produisent un mouvement.** Compter la même
///    quantité que le théorique n'écrit rien.
/// 3. **Chaque ajustement porte la référence de l'inventaire**, sa date et
///    son utilisateur — l'exigence de traçabilité du cahier des charges.
class ValidateInventory {
  const ValidateInventory({
    required InventoryRepository inventories,
    required ProductRepository products,
  })  : _inventories = inventories,
        _products = products;

  final InventoryRepository _inventories;
  final ProductRepository _products;

  Future<InventoryValidationResult> call(
    Inventory inventory, {
    required String validatedBy,
  }) async {
    if (!inventory.canValidate) {
      throw StateError(
        'Seul un inventaire terminé peut être validé '
        '(statut actuel : ${inventory.status.name}).',
      );
    }

    final DateTime now = DateTime.now();
    int adjustments = 0;

    for (final InventoryLine line in inventory.lines) {
      if (!line.hasVariance) continue;

      await _products.registerMovement(
        StockMovement(
          id: '',
          productId: line.productId,
          date: now,
          type: MovementType.ajustement,
          // L'écart est déjà signé : positif si on a trouvé plus que prévu.
          quantity: line.variance!,
          reference: inventory.reference,
          user: validatedBy,
          note: 'Écart constaté lors de l’inventaire',
        ),
      );
      adjustments++;
    }

    final Inventory validated = await _inventories.markValidated(
      inventoryId: inventory.id,
      validatedBy: validatedBy,
      at: now,
    );

    return InventoryValidationResult(
      inventory: validated,
      adjustmentsApplied: adjustments,
      linesSkipped: inventory.remainingCount,
      totalVarianceValue: inventory.totalVarianceValue,
    );
  }
}
