import '../../../../core/constants/app_enums.dart';
import '../entities/inventory.dart';
import '../entities/inventory_line.dart';

/// Contrat d'accès aux données du module Inventaire.
///
/// Ce dépôt ne connaît que les inventaires. Tout ce qui touche au stock
/// (lecture des produits à la création, écriture des ajustements à la
/// validation) passe par les cas d'usage de `domain/usecases/`, qui
/// orchestrent les deux dépôts.
abstract interface class InventoryRepository {
  Future<List<Inventory>> fetchInventories();

  Future<Inventory?> fetchInventory(String id);

  /// Crée un inventaire avec ses lignes déjà figées.
  ///
  /// Les lignes sont construites par `CreateInventory`, qui seul sait lire le
  /// stock des produits.
  Future<Inventory> createInventory({
    required InventoryScope scope,
    required List<InventoryLine> lines,
    required String createdBy,
    String? categoryId,
    String? categoryName,
  });

  /// Enregistre la quantité comptée d'une ligne.
  ///
  /// `countedStock` à `null` annule le comptage de cette ligne — ce n'est pas
  /// la même chose que compter zéro. Le premier comptage fait passer
  /// l'inventaire de `brouillon` à `enCours`.
  Future<Inventory> saveCount({
    required String inventoryId,
    required String productId,
    required double? countedStock,
  });

  Future<Inventory> updateStatus(String inventoryId, InventoryStatus status);

  /// Marque l'inventaire comme validé. Appelé par `ValidateInventory`
  /// **après** que les ajustements de stock ont été écrits.
  Future<Inventory> markValidated({
    required String inventoryId,
    required String validatedBy,
    required DateTime at,
  });

  Future<void> deleteInventory(String id);
}
