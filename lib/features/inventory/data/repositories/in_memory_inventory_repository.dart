import '../../../../core/constants/app_enums.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/inventory_line.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../fixtures/inventory_fixtures.dart';

/// Implémentation en mémoire de [InventoryRepository].
///
/// Même principe que le module Stock : une liste mutable et une latence
/// simulée, pour que les états de chargement soient visibles pendant le
/// développement et neutralisables dans les tests.
class InMemoryInventoryRepository implements InventoryRepository {
  InMemoryInventoryRepository({
    this.latency = const Duration(milliseconds: 300),
  });

  final Duration latency;

  final List<Inventory> _inventories = InventoryFixtures.inventories();
  int _sequence = InventoryFixtures.nextSequence;

  Future<void> _wait() => Future<void>.delayed(latency);

  int _indexOf(String id) {
    for (int i = 0; i < _inventories.length; i++) {
      if (_inventories[i].id == id) return i;
    }
    return -1;
  }

  Inventory _require(String id) {
    final int index = _indexOf(id);
    if (index == -1) throw StateError('Inventaire introuvable : $id');
    return _inventories[index];
  }

  @override
  Future<List<Inventory>> fetchInventories() async {
    await _wait();
    return List<Inventory>.unmodifiable(_inventories);
  }

  @override
  Future<Inventory?> fetchInventory(String id) async {
    await _wait();
    final int index = _indexOf(id);
    return index == -1 ? null : _inventories[index];
  }

  @override
  Future<Inventory> createInventory({
    required InventoryScope scope,
    required List<InventoryLine> lines,
    required String createdBy,
    String? categoryId,
    String? categoryName,
  }) async {
    await _wait();

    final int number = _sequence++;
    final Inventory inventory = Inventory(
      id: 'inv-${number.toString().padLeft(3, '0')}',
      reference: 'INV-${DateTime.now().year}-'
          '${number.toString().padLeft(3, '0')}',
      createdAt: DateTime.now(),
      status: InventoryStatus.brouillon,
      scope: scope,
      categoryId: categoryId,
      categoryName: categoryName,
      lines: lines,
      createdBy: createdBy,
    );

    _inventories.insert(0, inventory);
    return inventory;
  }

  @override
  Future<Inventory> saveCount({
    required String inventoryId,
    required String productId,
    required double? countedStock,
  }) async {
    // Pas de latence ici : la saisie du comptage doit rester instantanée,
    // y compris hors connexion. La synchronisation viendra plus tard, en
    // arrière-plan.
    final Inventory inventory = _require(inventoryId);
    if (!inventory.isCountable) {
      throw StateError(
        'Le comptage de ${inventory.reference} est clos, il ne peut plus '
        'être modifié.',
      );
    }

    final List<InventoryLine> lines = inventory.lines
        .map(
          (InventoryLine line) => line.productId == productId
              ? line.copyWith(
                  countedStock: countedStock,
                  countedAt: DateTime.now(),
                  clearCount: countedStock == null,
                )
              : line,
        )
        .toList();

    // Le premier comptage fait sortir l'inventaire du brouillon.
    final InventoryStatus status =
        inventory.status == InventoryStatus.brouillon &&
                lines.any((InventoryLine l) => l.isCounted)
            ? InventoryStatus.enCours
            : inventory.status;

    final Inventory updated = inventory.copyWith(lines: lines, status: status);
    _inventories[_indexOf(inventoryId)] = updated;
    return updated;
  }

  @override
  Future<Inventory> updateStatus(
    String inventoryId,
    InventoryStatus status,
  ) async {
    await _wait();
    final Inventory inventory = _require(inventoryId);
    final Inventory updated = inventory.copyWith(
      status: status,
      closedAt: status == InventoryStatus.termine ? DateTime.now() : null,
    );
    _inventories[_indexOf(inventoryId)] = updated;
    return updated;
  }

  @override
  Future<Inventory> markValidated({
    required String inventoryId,
    required String validatedBy,
    required DateTime at,
  }) async {
    await _wait();
    final Inventory inventory = _require(inventoryId);
    final Inventory updated = inventory.copyWith(
      status: InventoryStatus.valide,
      validatedAt: at,
      validatedBy: validatedBy,
    );
    _inventories[_indexOf(inventoryId)] = updated;
    return updated;
  }

  @override
  Future<void> deleteInventory(String id) async {
    await _wait();
    _inventories.removeWhere((Inventory i) => i.id == id);
  }
}
