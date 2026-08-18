import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../stock/presentation/controllers/stock_providers.dart';
import '../../data/repositories/in_memory_inventory_repository.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/inventory_line.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/usecases/create_inventory.dart';
import '../../domain/usecases/validate_inventory.dart';

/// Source de données du module. Seul point de branchement du backend.
final Provider<InventoryRepository> inventoryRepositoryProvider =
    Provider<InventoryRepository>((Ref ref) => InMemoryInventoryRepository());

/// Les deux cas d'usage qui font dialoguer Inventaire et Stock.
final Provider<CreateInventory> createInventoryProvider =
    Provider<CreateInventory>(
  (Ref ref) => CreateInventory(
    inventories: ref.watch(inventoryRepositoryProvider),
    products: ref.watch(productRepositoryProvider),
  ),
);

final Provider<ValidateInventory> validateInventoryProvider =
    Provider<ValidateInventory>(
  (Ref ref) => ValidateInventory(
    inventories: ref.watch(inventoryRepositoryProvider),
    products: ref.watch(productRepositoryProvider),
  ),
);

// ---------------------------------------------------------------------------
// Liste des inventaires
// ---------------------------------------------------------------------------

/// Détient la liste des inventaires et les opérations qui la modifient.
class InventoryController extends StateNotifier<AsyncValue<List<Inventory>>> {
  InventoryController(this._ref)
      : _repository = _ref.read(inventoryRepositoryProvider),
        super(const AsyncValue<List<Inventory>>.loading()) {
    load();
  }

  final Ref _ref;
  final InventoryRepository _repository;

  Future<void> load() async {
    state = const AsyncValue<List<Inventory>>.loading();
    state = await AsyncValue.guard(() => _repository.fetchInventories());
  }

  /// Ouvre un inventaire et le sélectionne pour démarrer le comptage.
  Future<Inventory> create({
    required InventoryScope scope,
    required String createdBy,
    String? categoryId,
    String? categoryName,
  }) async {
    final Inventory created = await _ref.read(createInventoryProvider)(
      scope: scope,
      createdBy: createdBy,
      categoryId: categoryId,
      categoryName: categoryName,
    );
    await load();
    _ref.read(selectedInventoryIdProvider.notifier).state = created.id;
    return created;
  }

  /// Enregistre la quantité comptée d'une ligne.
  ///
  /// Volontairement optimiste : l'état local est mis à jour immédiatement,
  /// sans repasser par un chargement, pour que la saisie reste fluide même
  /// avec plusieurs centaines de lignes.
  Future<void> saveCount({
    required String inventoryId,
    required String productId,
    required double? countedStock,
  }) async {
    final Inventory updated = await _repository.saveCount(
      inventoryId: inventoryId,
      productId: productId,
      countedStock: countedStock,
    );
    _replace(updated);
  }

  /// Clôt le comptage : l'inventaire passe en « Terminé » et n'est plus
  /// modifiable. Le stock n'a pas encore bougé.
  Future<void> close(String inventoryId) async {
    final Inventory updated = await _repository.updateStatus(
      inventoryId,
      InventoryStatus.termine,
    );
    _replace(updated);
  }

  /// Rouvre un comptage clos par erreur. Impossible après validation.
  Future<void> reopen(String inventoryId) async {
    final Inventory updated = await _repository.updateStatus(
      inventoryId,
      InventoryStatus.enCours,
    );
    _replace(updated);
  }

  /// Applique les écarts au stock. Opération irréversible.
  Future<InventoryValidationResult> validate(
    Inventory inventory, {
    required String validatedBy,
  }) async {
    final InventoryValidationResult result =
        await _ref.read(validateInventoryProvider)(
      inventory,
      validatedBy: validatedBy,
    );
    _replace(result.inventory);
    // Le stock des produits corrigés a changé, et leur historique de
    // mouvements vient de gagner une ligne : c'est au module Stock de
    // rafraîchir ce qu'il faut, on lui dit seulement quels produits.
    await _ref
        .read(stockControllerProvider.notifier)
        .refreshProducts(result.adjustedProductIds);
    return result;
  }

  Future<void> delete(String inventoryId) async {
    await _repository.deleteInventory(inventoryId);
    if (_ref.read(selectedInventoryIdProvider) == inventoryId) {
      _ref.read(selectedInventoryIdProvider.notifier).state = null;
    }
    await load();
  }

  /// Remplace un inventaire dans la liste sans tout recharger.
  void _replace(Inventory updated) {
    final List<Inventory>? current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<List<Inventory>>.data(
      current
          .map((Inventory i) => i.id == updated.id ? updated : i)
          .toList(),
    );
  }
}

final StateNotifierProvider<InventoryController, AsyncValue<List<Inventory>>>
    inventoryControllerProvider =
    StateNotifierProvider<InventoryController, AsyncValue<List<Inventory>>>(
  InventoryController.new,
);

// ---------------------------------------------------------------------------
// Recherche et filtres de la liste
// ---------------------------------------------------------------------------

/// Onglets de la liste, repris de la maquette.
enum InventoryFilter {
  tous,
  enCours,
  brouillon,
  termine;

  String get label => switch (this) {
        InventoryFilter.tous => 'Tous',
        InventoryFilter.enCours => 'En cours',
        InventoryFilter.brouillon => 'Brouillon',
        InventoryFilter.termine => 'Terminé',
      };

  /// Statuts couverts par l'onglet. « Terminé » regroupe les inventaires
  /// clos et validés : pour l'utilisateur, le comptage est fini dans les
  /// deux cas.
  bool matches(InventoryStatus status) => switch (this) {
        InventoryFilter.tous => true,
        InventoryFilter.enCours => status == InventoryStatus.enCours,
        InventoryFilter.brouillon => status == InventoryStatus.brouillon,
        InventoryFilter.termine => status == InventoryStatus.termine ||
            status == InventoryStatus.valide,
      };
}

class InventoryQuery {
  const InventoryQuery({this.search = '', this.filter = InventoryFilter.tous});

  final String search;
  final InventoryFilter filter;

  InventoryQuery copyWith({String? search, InventoryFilter? filter}) =>
      InventoryQuery(
        search: search ?? this.search,
        filter: filter ?? this.filter,
      );

  List<Inventory> apply(List<Inventory> inventories) {
    final String needle = search.trim().toLowerCase();

    return inventories.where((Inventory i) {
      if (!filter.matches(i.status)) return false;
      if (needle.isEmpty) return true;
      return i.reference.toLowerCase().contains(needle) ||
          (i.categoryName?.toLowerCase().contains(needle) ?? false) ||
          i.createdBy.toLowerCase().contains(needle);
    }).toList()
      ..sort((Inventory a, Inventory b) => b.createdAt.compareTo(a.createdAt));
  }
}

class InventoryQueryController extends StateNotifier<InventoryQuery> {
  InventoryQueryController() : super(const InventoryQuery());

  void setSearch(String value) => state = state.copyWith(search: value);
  void setFilter(InventoryFilter filter) =>
      state = state.copyWith(filter: filter);
}

final StateNotifierProvider<InventoryQueryController, InventoryQuery>
    inventoryQueryProvider =
    StateNotifierProvider<InventoryQueryController, InventoryQuery>(
  (Ref ref) => InventoryQueryController(),
);

final Provider<AsyncValue<List<Inventory>>> visibleInventoriesProvider =
    Provider<AsyncValue<List<Inventory>>>((Ref ref) {
  final InventoryQuery query = ref.watch(inventoryQueryProvider);
  return ref
      .watch(inventoryControllerProvider)
      .whenData((List<Inventory> list) => query.apply(list));
});

/// Compteurs des onglets de filtre.
final Provider<Map<InventoryFilter, int>> inventoryCountersProvider =
    Provider<Map<InventoryFilter, int>>((Ref ref) {
  final List<Inventory> all =
      ref.watch(inventoryControllerProvider).valueOrNull ?? const <Inventory>[];
  return <InventoryFilter, int>{
    for (final InventoryFilter f in InventoryFilter.values)
      f: all.where((Inventory i) => f.matches(i.status)).length,
  };
});

// ---------------------------------------------------------------------------
// Inventaire ouvert et écran de comptage
// ---------------------------------------------------------------------------

/// Inventaire ouvert en comptage. `null` = on est sur la liste.
final StateProvider<String?> selectedInventoryIdProvider =
    StateProvider<String?>((Ref ref) => null);

final Provider<Inventory?> selectedInventoryProvider =
    Provider<Inventory?>((Ref ref) {
  final String? id = ref.watch(selectedInventoryIdProvider);
  if (id == null) return null;
  final List<Inventory> all =
      ref.watch(inventoryControllerProvider).valueOrNull ?? const <Inventory>[];
  for (final Inventory inventory in all) {
    if (inventory.id == id) return inventory;
  }
  return null;
});

/// Filtres internes à l'écran de comptage.
enum CountingFilter {
  tous,
  nonComptes,
  ecarts;

  String get label => switch (this) {
        CountingFilter.tous => 'Tous',
        CountingFilter.nonComptes => 'Non comptés',
        CountingFilter.ecarts => 'Écarts',
      };

  bool matches(InventoryLine line) => switch (this) {
        CountingFilter.tous => true,
        CountingFilter.nonComptes => !line.isCounted,
        CountingFilter.ecarts => line.hasVariance,
      };
}

class CountingQuery {
  const CountingQuery({this.search = '', this.filter = CountingFilter.tous});

  final String search;
  final CountingFilter filter;

  CountingQuery copyWith({String? search, CountingFilter? filter}) =>
      CountingQuery(
        search: search ?? this.search,
        filter: filter ?? this.filter,
      );

  List<InventoryLine> apply(List<InventoryLine> lines) {
    final String needle = search.trim().toLowerCase();
    return lines.where((InventoryLine l) {
      if (!filter.matches(l)) return false;
      if (needle.isEmpty) return true;
      return l.productName.toLowerCase().contains(needle) ||
          l.categoryName.toLowerCase().contains(needle) ||
          (l.barcode?.contains(needle) ?? false);
    }).toList();
  }
}

class CountingQueryController extends StateNotifier<CountingQuery> {
  CountingQueryController() : super(const CountingQuery());

  void setSearch(String value) => state = state.copyWith(search: value);
  void setFilter(CountingFilter filter) =>
      state = state.copyWith(filter: filter);
  void reset() => state = const CountingQuery();
}

final StateNotifierProvider<CountingQueryController, CountingQuery>
    countingQueryProvider =
    StateNotifierProvider<CountingQueryController, CountingQuery>(
  (Ref ref) => CountingQueryController(),
);

/// Lignes affichées dans le tableau de comptage.
final Provider<List<InventoryLine>> visibleCountingLinesProvider =
    Provider<List<InventoryLine>>((Ref ref) {
  final Inventory? inventory = ref.watch(selectedInventoryProvider);
  if (inventory == null) return const <InventoryLine>[];
  return ref.watch(countingQueryProvider).apply(inventory.lines);
});
