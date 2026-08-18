import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../data/repositories/in_memory_product_repository.dart';
import '../../domain/entities/measurement_unit.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/product_repository.dart';

/// Source de données du module Stock.
///
/// En phase frontend, une implémentation en mémoire. Le jour où l'API
/// arrive, seule cette ligne change — rien dans les pages.
final Provider<ProductRepository> productRepositoryProvider =
    Provider<ProductRepository>((Ref ref) => InMemoryProductRepository());

// ---------------------------------------------------------------------------
// Liste des produits
// ---------------------------------------------------------------------------

/// Détient la liste des produits et les opérations qui la modifient.
class StockController extends StateNotifier<AsyncValue<List<Product>>> {
  StockController(this._ref)
      : _repository = _ref.read(productRepositoryProvider),
        super(const AsyncValue<List<Product>>.loading()) {
    load();
  }

  final Ref _ref;
  final ProductRepository _repository;

  Future<void> load() async {
    state = const AsyncValue<List<Product>>.loading();
    state = await AsyncValue.guard(() => _repository.fetchProducts());
  }

  /// Crée ou met à jour un produit, puis rafraîchit la liste.
  Future<void> save(Product product) async {
    await _repository.saveProduct(product);
    await load();
  }

  Future<void> delete(String productId) async {
    await _repository.deleteProduct(productId);
    if (_ref.read(selectedProductIdProvider) == productId) {
      _ref.read(selectedProductIdProvider.notifier).state = null;
    }
    await load();
  }

  /// Enregistre une entrée, une sortie ou un ajustement de stock.
  Future<void> registerMovement(StockMovement movement) async {
    await _repository.registerMovement(movement);
    _ref.invalidate(productMovementsProvider(movement.productId));
    await load();
  }

  /// Identifiant à attribuer à un produit créé depuis l'interface.
  String nextProductId() {
    final ProductRepository repository = _repository;
    return repository is InMemoryProductRepository
        ? repository.newProductId()
        : DateTime.now().microsecondsSinceEpoch.toString();
  }
}

final StateNotifierProvider<StockController, AsyncValue<List<Product>>>
    stockControllerProvider =
    StateNotifierProvider<StockController, AsyncValue<List<Product>>>(
  StockController.new,
);

final FutureProvider<List<ProductCategory>> categoriesProvider =
    FutureProvider<List<ProductCategory>>(
  (Ref ref) => ref.watch(productRepositoryProvider).fetchCategories(),
);

final FutureProvider<List<MeasurementUnit>> unitsProvider =
    FutureProvider<List<MeasurementUnit>>(
  (Ref ref) => ref.watch(productRepositoryProvider).fetchUnits(),
);

final FutureProviderFamily<List<StockMovement>, String>
    productMovementsProvider = FutureProvider.family<List<StockMovement>, String>(
  (Ref ref, String productId) =>
      ref.watch(productRepositoryProvider).fetchMovements(productId),
);

// ---------------------------------------------------------------------------
// Recherche et filtres
// ---------------------------------------------------------------------------

/// Onglets de la liste des produits, repris de la maquette.
enum StockFilter {
  tous,
  categories,
  faible;

  String get label => switch (this) {
        StockFilter.tous => 'Tous',
        StockFilter.categories => 'Catégories',
        StockFilter.faible => 'Stock faible',
      };
}

/// Critères de filtrage de la liste des produits.
class StockQuery {
  const StockQuery({
    this.search = '',
    this.filter = StockFilter.tous,
    this.categoryId,
  });

  final String search;
  final StockFilter filter;

  /// Catégorie sélectionnée depuis l'onglet « Catégories ».
  final String? categoryId;

  StockQuery copyWith({
    String? search,
    StockFilter? filter,
    String? categoryId,
    bool clearCategory = false,
  }) {
    return StockQuery(
      search: search ?? this.search,
      filter: filter ?? this.filter,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  /// Applique la recherche et les filtres à une liste de produits.
  List<Product> apply(List<Product> products) {
    final String needle = search.trim().toLowerCase();

    return products.where((Product p) {
      if (filter == StockFilter.faible && p.status == StockStatus.ok) {
        return false;
      }
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (needle.isEmpty) return true;
      return p.name.toLowerCase().contains(needle) ||
          p.categoryName.toLowerCase().contains(needle) ||
          (p.barcode?.contains(needle) ?? false);
    }).toList()
      ..sort((Product a, Product b) => a.name.compareTo(b.name));
  }
}

class StockQueryController extends StateNotifier<StockQuery> {
  StockQueryController() : super(const StockQuery());

  void setSearch(String value) => state = state.copyWith(search: value);

  void setFilter(StockFilter filter) {
    // Quitter l'onglet « Catégories » lève la sélection de catégorie.
    state = filter == StockFilter.categories
        ? state.copyWith(filter: filter, clearCategory: true)
        : state.copyWith(filter: filter);
  }

  /// Sélectionne une catégorie et bascule sur la liste des produits.
  void selectCategory(String categoryId) {
    state = state.copyWith(
      filter: StockFilter.tous,
      categoryId: categoryId,
    );
  }

  void clearCategory() => state = state.copyWith(clearCategory: true);
}

final StateNotifierProvider<StockQueryController, StockQuery>
    stockQueryProvider =
    StateNotifierProvider<StockQueryController, StockQuery>(
  (Ref ref) => StockQueryController(),
);

/// Produits affichés dans le tableau, après recherche et filtres.
final Provider<AsyncValue<List<Product>>> visibleProductsProvider =
    Provider<AsyncValue<List<Product>>>((Ref ref) {
  final StockQuery query = ref.watch(stockQueryProvider);
  return ref
      .watch(stockControllerProvider)
      .whenData((List<Product> products) => query.apply(products));
});

/// Compteurs affichés sur les onglets de filtre.
class StockCounters {
  const StockCounters({
    required this.total,
    required this.low,
    required this.categories,
  });

  final int total;
  final int low;
  final int categories;
}

final Provider<StockCounters> stockCountersProvider =
    Provider<StockCounters>((Ref ref) {
  final List<Product> products =
      ref.watch(stockControllerProvider).valueOrNull ?? const <Product>[];
  final int low = products
      .where((Product p) => p.status != StockStatus.ok)
      .length;
  final int categories =
      products.map((Product p) => p.categoryId).toSet().length;
  return StockCounters(
    total: products.length,
    low: low,
    categories: categories,
  );
});

// ---------------------------------------------------------------------------
// Vue par catégorie
// ---------------------------------------------------------------------------

/// Ligne de l'onglet « Catégories » : une catégorie et ses agrégats.
class CategoryStats {
  const CategoryStats({
    required this.category,
    required this.productCount,
    required this.lowCount,
    required this.stockValue,
  });

  final ProductCategory category;
  final int productCount;

  /// Produits en stock faible ou en rupture dans cette catégorie.
  final int lowCount;

  final double stockValue;
}

final Provider<List<CategoryStats>> categoryStatsProvider =
    Provider<List<CategoryStats>>((Ref ref) {
  final List<Product> products =
      ref.watch(stockControllerProvider).valueOrNull ?? const <Product>[];
  final List<ProductCategory> categories =
      ref.watch(categoriesProvider).valueOrNull ?? const <ProductCategory>[];

  return categories.map((ProductCategory category) {
    final List<Product> inCategory = products
        .where((Product p) => p.categoryId == category.id)
        .toList();
    return CategoryStats(
      category: category,
      productCount: inCategory.length,
      lowCount: inCategory
          .where((Product p) => p.status != StockStatus.ok)
          .length,
      stockValue: inCategory.fold<double>(
        0,
        (double sum, Product p) => sum + p.stockValue,
      ),
    );
  }).toList()
    ..sort(
      (CategoryStats a, CategoryStats b) =>
          b.productCount.compareTo(a.productCount),
    );
});

// ---------------------------------------------------------------------------
// Sélection
// ---------------------------------------------------------------------------

/// Produit ouvert dans le panneau de détail. `null` = aucun.
final StateProvider<String?> selectedProductIdProvider =
    StateProvider<String?>((Ref ref) => null);

final Provider<Product?> selectedProductProvider =
    Provider<Product?>((Ref ref) {
  final String? id = ref.watch(selectedProductIdProvider);
  if (id == null) return null;
  final List<Product> products =
      ref.watch(stockControllerProvider).valueOrNull ?? const <Product>[];
  for (final Product product in products) {
    if (product.id == id) return product;
  }
  return null;
});
