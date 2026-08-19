import '../../../../core/constants/app_enums.dart';
import '../../domain/entities/measurement_unit.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/product_repository.dart';
import '../fixtures/stock_fixtures.dart';

/// Implémentation en mémoire de [ProductRepository], alimentée par les
/// fixtures.
///
/// Elle permet de manipuler réellement l'interface (créer un produit, saisir
/// une entrée de stock, voir le statut changer) sans backend. Un délai
/// artificiel reproduit l'attente réseau afin que les états de chargement
/// soient visibles et testés dès maintenant.
class InMemoryProductRepository implements ProductRepository {
  InMemoryProductRepository({this.latency = const Duration(milliseconds: 350)});

  /// Délai simulé. Mettre `Duration.zero` dans les tests.
  final Duration latency;

  final List<Product> _products = StockFixtures.products();
  final List<StockMovement> _movements = StockFixtures.movements();
  int _sequence = 100;

  Future<void> _wait() => Future<void>.delayed(latency);

  String _nextId(String prefix) => '$prefix-${++_sequence}';

  @override
  Future<List<Product>> fetchProducts() async {
    await _wait();
    return List<Product>.unmodifiable(_products);
  }

  @override
  Future<Product?> fetchProduct(String id) async {
    await _wait();
    return _indexOf(id) == -1 ? null : _products[_indexOf(id)];
  }

  @override
  Future<Product?> findByBarcode(String barcode) async {
    await _wait();
    final String needle = barcode.trim();
    for (final Product product in _products) {
      if (product.barcode == needle) return product;
    }
    return null;
  }

  @override
  Future<Product> saveProduct(Product product) async {
    await _wait();
    final int index = _indexOf(product.id);
    final Product saved = product.copyWith(updatedAt: DateTime.now());
    if (index == -1) {
      _products.add(saved);
    } else {
      _products[index] = saved;
    }
    return saved;
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _wait();
    _products.removeWhere((Product p) => p.id == id);
    _movements.removeWhere((StockMovement m) => m.productId == id);
  }

  @override
  Future<List<ProductCategory>> fetchCategories() async {
    await _wait();
    return StockFixtures.categories;
  }

  @override
  Future<List<MeasurementUnit>> fetchUnits() async {
    await _wait();
    return StockFixtures.units;
  }

  @override
  Future<List<StockMovement>> fetchMovements(String productId) async {
    await _wait();
    final List<StockMovement> result = _movements
        .where((StockMovement m) => m.productId == productId)
        .toList()
      ..sort((StockMovement a, StockMovement b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<Product> registerMovement(StockMovement movement) async {
    await _wait();
    final int index = _indexOf(movement.productId);
    if (index == -1) {
      throw StateError('Produit introuvable : ${movement.productId}');
    }

    // `copyWith` plutôt qu'une reconstruction champ par champ : la liste
    // manuelle oubliait silencieusement tout champ ajouté à l'entité.
    final StockMovement stored =
        movement.id.isEmpty ? movement.copyWith(id: _nextId('m')) : movement;
    _movements.add(stored);

    final Product product = _products[index];
    final double updatedStock = product.currentStock + stored.quantity;
    final Product updated = product.copyWith(
      currentStock: updatedStock < 0 ? 0 : updatedStock,
      updatedAt: stored.date,
    );
    _products[index] = updated;
    return updated;
  }

  @override
  Future<Product> recordSupplierPrice({
    required String productId,
    required String supplierId,
    required double unitPrice,
    DateTime? validFrom,
    PriceSource source = PriceSource.saisieManuelle,
    String? note,
  }) async {
    await _wait();
    final int index = _indexOf(productId);
    if (index == -1) {
      throw StateError('Produit introuvable : $productId');
    }

    final Product product = _products[index];
    final ProductSupplier? supplier = product.supplierById(supplierId);
    if (supplier == null) {
      throw StateError(
        'Le fournisseur $supplierId n’est pas associé à ${product.name}.',
      );
    }

    final Product updated = product.copyWith(
      suppliers: <ProductSupplier>[
        for (final ProductSupplier s in product.suppliers)
          if (s.id == supplierId)
            s.withPrice(
              unitPrice,
              validFrom: validFrom ?? DateTime.now(),
              source: source,
              note: note,
            )
          else
            s,
      ],
      updatedAt: DateTime.now(),
    );
    _products[index] = updated;
    return updated;
  }

  /// Identifiant à attribuer à un nouveau produit.
  String newProductId() => _nextId('p');

  int _indexOf(String id) {
    for (int i = 0; i < _products.length; i++) {
      if (_products[i].id == id) return i;
    }
    return -1;
  }
}
