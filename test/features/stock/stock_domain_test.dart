import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/constants/app_enums.dart';
import 'package:gestion_stock/features/stock/data/repositories/in_memory_product_repository.dart';
import 'package:gestion_stock/features/stock/domain/entities/product.dart';
import 'package:gestion_stock/features/stock/domain/entities/stock_movement.dart';
import 'package:gestion_stock/features/stock/presentation/controllers/stock_providers.dart';

Product buildProduct({
  String id = 'p-test',
  String name = 'Tomate',
  double currentStock = 95,
  double minStock = 40,
  double maxStock = 120,
  double unitPrice = 6,
  String categoryId = 'cat-1',
  String categoryName = 'Légumes',
}) {
  return Product(
    id: id,
    name: name,
    categoryId: categoryId,
    categoryName: categoryName,
    unit: 'kg',
    currentStock: currentStock,
    minStock: minStock,
    maxStock: maxStock,
    unitPrice: unitPrice,
  );
}

void main() {
  group('Product', () {
    test('le statut suit le seuil minimum', () {
      expect(buildProduct(currentStock: 95).status, StockStatus.ok);
      expect(buildProduct(currentStock: 40).status, StockStatus.faible);
      expect(buildProduct(currentStock: 12).status, StockStatus.faible);
      expect(buildProduct(currentStock: 0).status, StockStatus.rupture);
    });

    test('la valeur du stock est la quantité fois le prix unitaire', () {
      expect(buildProduct(currentStock: 95, unitPrice: 6).stockValue, 570);
    });

    test('la quantité à commander ramène au stock maximum', () {
      expect(buildProduct(currentStock: 95, maxStock: 120).quantityToOrder, 25);
      expect(buildProduct(currentStock: 150, maxStock: 120).quantityToOrder, 0);
    });

    test('le fournisseur principal est celui marqué comme tel', () {
      const ProductSupplier primary = ProductSupplier(
        id: 's2',
        name: 'AgriPlus',
        unitPrice: 6,
        isPrimary: true,
      );
      final Product product = buildProduct().copyWith(
        suppliers: const <ProductSupplier>[
          ProductSupplier(id: 's1', name: 'FreshFood', unitPrice: 6.4),
          primary,
        ],
      );
      expect(product.primarySupplier?.name, 'AgriPlus');
    });
  });

  group('StockQuery', () {
    final List<Product> products = <Product>[
      buildProduct(id: 'p1', name: 'Tomate', currentStock: 95),
      buildProduct(id: 'p2', name: 'Carotte', currentStock: 20),
      buildProduct(
        id: 'p3',
        name: 'Riz 10kg',
        categoryId: 'cat-2',
        categoryName: 'Épicerie',
        currentStock: 80,
      ),
    ];

    test('sans critère, tout est renvoyé et trié par nom', () {
      final List<Product> result = const StockQuery().apply(products);
      expect(
        result.map((Product p) => p.name),
        <String>['Carotte', 'Riz 10kg', 'Tomate'],
      );
    });

    test('le filtre « stock faible » écarte les produits OK', () {
      final List<Product> result =
          const StockQuery(filter: StockFilter.faible).apply(products);
      expect(result.map((Product p) => p.name), <String>['Carotte']);
    });

    test('la recherche porte sur le nom et la catégorie', () {
      expect(
        const StockQuery(search: 'tom').apply(products).single.name,
        'Tomate',
      );
      expect(
        const StockQuery(search: 'épicerie').apply(products).single.name,
        'Riz 10kg',
      );
    });

    test('le filtre par catégorie restreint la liste', () {
      final List<Product> result =
          const StockQuery(categoryId: 'cat-2').apply(products);
      expect(result.single.name, 'Riz 10kg');
    });
  });

  group('InMemoryProductRepository', () {
    late InMemoryProductRepository repository;

    setUp(() {
      repository = InMemoryProductRepository(latency: Duration.zero);
    });

    test('une entrée augmente le stock du produit', () async {
      final List<Product> before = await repository.fetchProducts();
      final Product tomate =
          before.firstWhere((Product p) => p.name == 'Tomate');

      final Product after = await repository.registerMovement(
        StockMovement(
          id: '',
          productId: tomate.id,
          date: DateTime(2024, 6),
          type: MovementType.entree,
          quantity: 25,
          user: 'Admin',
        ),
      );

      expect(after.currentStock, tomate.currentStock + 25);
    });

    test('une sortie diminue le stock sans passer sous zéro', () async {
      final List<Product> products = await repository.fetchProducts();
      final Product product = products.first;

      final Product after = await repository.registerMovement(
        StockMovement(
          id: '',
          productId: product.id,
          date: DateTime(2024, 6),
          type: MovementType.sortie,
          quantity: -(product.currentStock + 1000),
          user: 'Ahmed',
        ),
      );

      expect(after.currentStock, 0);
      expect(after.status, StockStatus.rupture);
    });

    test('le mouvement enregistré apparaît en tête de l’historique', () async {
      final List<Product> products = await repository.fetchProducts();
      final Product product = products.first;

      await repository.registerMovement(
        StockMovement(
          id: '',
          productId: product.id,
          date: DateTime(2030),
          type: MovementType.entree,
          quantity: 10,
          reference: 'CMD-999',
          user: 'Admin',
        ),
      );

      final List<StockMovement> movements =
          await repository.fetchMovements(product.id);
      expect(movements.first.reference, 'CMD-999');
    });

    test('la recherche par code-barres retrouve le produit', () async {
      final Product? found = await repository.findByBarcode('6111000000011');
      expect(found?.name, 'Tomate');
      expect(await repository.findByBarcode('inconnu'), isNull);
    });

    test('la suppression retire le produit et ses mouvements', () async {
      final List<Product> products = await repository.fetchProducts();
      final Product product = products.first;

      await repository.deleteProduct(product.id);

      final List<Product> after = await repository.fetchProducts();
      expect(after.any((Product p) => p.id == product.id), isFalse);
      expect(await repository.fetchMovements(product.id), isEmpty);
    });

    test('saveProduct crée puis met à jour', () async {
      final Product created = await repository.saveProduct(
        buildProduct(id: 'p-new', name: 'Basilic'),
      );
      expect(created.name, 'Basilic');
      expect((await repository.fetchProducts()).length, 16);

      await repository.saveProduct(created.copyWith(name: 'Basilic frais'));
      final Product? updated = await repository.fetchProduct('p-new');
      expect(updated?.name, 'Basilic frais');
      expect((await repository.fetchProducts()).length, 16);
    });
  });
}
