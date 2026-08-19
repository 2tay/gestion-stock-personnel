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
  double averageCost = 6,
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
    averageCost: averageCost,
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

    test('la valeur du stock est la quantité fois le coût moyen', () {
      expect(buildProduct(currentStock: 95, averageCost: 6).stockValue, 570);
    });

    test('la quantité à commander ramène au stock maximum', () {
      expect(buildProduct(currentStock: 95, maxStock: 120).quantityToOrder, 25);
      expect(buildProduct(currentStock: 150, maxStock: 120).quantityToOrder, 0);
    });

    test('le fournisseur principal est celui marqué comme tel', () {
      final ProductSupplier primary = ProductSupplier(
        id: 's2',
        name: 'AgriPlus',
        unitPrice: 6,
        isPrimary: true,
      );
      final Product product = buildProduct().copyWith(
        suppliers: <ProductSupplier>[
          ProductSupplier(id: 's1', name: 'FreshFood', unitPrice: 6.4),
          primary,
        ],
      );
      expect(product.primarySupplier?.name, 'AgriPlus');
    });
  });

  group('Product.averageCostAfter — le coût moyen pondéré', () {
    test('le cas de référence : 100 à 12, puis 20 à 18', () {
      final Product product =
          buildProduct(currentStock: 100, averageCost: 12);

      final double cost =
          product.averageCostAfter(quantity: 20, unitPrice: 18);

      // (100 × 12 + 20 × 18) / 120 = 1 560 / 120
      expect(cost, 13);
      // Et la valeur du stock vaut exactement ce qui a été dépensé, au lieu
      // des 2 160 MAD qu'affichait l'ancien champ unique.
      expect(
        product.copyWith(currentStock: 120, averageCost: cost).stockValue,
        1560,
      );
    });

    test('une correction restitue exactement le coût moyen d’avant', () {
      final Product avant =
          buildProduct(currentStock: 100, averageCost: 12);
      final double apresEntree =
          avant.averageCostAfter(quantity: 20, unitPrice: 18);

      final Product apres = avant.copyWith(
        currentStock: 120,
        averageCost: apresEntree,
      );
      // On annule l'entrée, au prix de l'entrée d'origine.
      final double restitue =
          apres.averageCostAfter(quantity: -20, unitPrice: 18);

      expect(restitue, closeTo(12, 0.000001));
    });

    test('une baisse de prix fait baisser le coût moyen', () {
      final Product product =
          buildProduct(currentStock: 100, averageCost: 12);
      expect(
        product.averageCostAfter(quantity: 100, unitPrice: 10),
        11,
      );
    });

    test('sans stock avant, la marchandise reçue fixe seule le coût', () {
      final Product product = buildProduct(currentStock: 0, averageCost: 12);
      // Il ne reste rien à pondérer : le vieux coût n'a plus d'objet.
      expect(product.averageCostAfter(quantity: 50, unitPrice: 18), 18);
    });

    test('sans stock après, le dernier coût connu est conservé', () {
      final Product product = buildProduct(currentStock: 20, averageCost: 12);
      // Une division par zéro n'apprendrait rien ; perdre le coût non plus.
      expect(product.averageCostAfter(quantity: -20, unitPrice: 12), 12);
    });

    test('un prix identique laisse le coût moyen inchangé', () {
      final Product product = buildProduct(currentStock: 100, averageCost: 12);
      expect(product.averageCostAfter(quantity: 50, unitPrice: 12), 12);
    });
  });

  group('ProductSupplier — historique des tarifs', () {
    ProductSupplier build() => ProductSupplier(
          id: 'sup-1',
          name: 'AgriPlus',
          unitPrice: 6.20,
          since: DateTime(2026, 8, 13),
          history: <SupplierPrice>[
            SupplierPrice(unitPrice: 5.80, validFrom: DateTime(2026, 7, 10)),
            SupplierPrice(unitPrice: 5.50, validFrom: DateTime(2026, 5)),
          ],
        );

    test('le tarif en vigueur est le plus récent', () {
      final ProductSupplier supplier = build();
      expect(supplier.unitPrice, 6.20);
      expect(supplier.prices.length, 3);
      // Du plus récent au plus ancien, quel que soit l'ordre de saisie.
      expect(
        supplier.prices.map((SupplierPrice p) => p.unitPrice).toList(),
        <double>[6.20, 5.80, 5.50],
      );
    });

    test('un nouveau tarif n’efface pas le précédent', () {
      final ProductSupplier supplier = build().withPrice(
        6.60,
        validFrom: DateTime(2026, 8, 19),
        source: PriceSource.reception,
      );

      expect(supplier.unitPrice, 6.60);
      expect(supplier.previousPrice?.unitPrice, 6.20);
      expect(supplier.prices.length, 4);
      // Le tarif d'origine est toujours là, tout au fond.
      expect(supplier.prices.last.unitPrice, 5.50);
    });

    test('un prix identique ne crée pas de ligne', () {
      final ProductSupplier supplier = build();
      final ProductSupplier again = supplier.withPrice(6.20);
      // L'historique consigne les changements, pas les confirmations.
      expect(again.prices.length, supplier.prices.length);
    });

    test('l’écart avec le tarif précédent est mesurable', () {
      final ProductSupplier supplier = build();
      expect(supplier.priceChange, closeTo(0.40, 0.0001));
      expect(supplier.priceChangeRatio, closeTo(0.40 / 5.80, 0.0001));
    });

    test('sans historique, l’écart est inconnu et non nul', () {
      final ProductSupplier supplier =
          ProductSupplier(id: 's', name: 'FreshFood', unitPrice: 6.4);
      // `null` et non 0 : afficher « 0 % » annoncerait une stabilité qui n'a
      // jamais été observée.
      expect(supplier.previousPrice, isNull);
      expect(supplier.priceChange, isNull);
      expect(supplier.priceChangeRatio, isNull);
    });

    test('on retrouve le tarif applicable à une date passée', () {
      final ProductSupplier supplier = build();
      expect(supplier.priceOn(DateTime(2026, 8, 19))?.unitPrice, 6.20);
      expect(supplier.priceOn(DateTime(2026, 7, 20))?.unitPrice, 5.80);
      expect(supplier.priceOn(DateTime(2026, 6))?.unitPrice, 5.50);
      // Avant le premier tarif connu, on ne sait pas — et on le dit.
      expect(supplier.priceOn(DateTime(2026, 1)), isNull);
    });

    test('un tarif sans date est traité comme le plus ancien', () {
      final ProductSupplier supplier = ProductSupplier(
        id: 'sup-9',
        name: 'DistriFood',
        unitPrice: 10,
        since: DateTime(2026, 8),
        history: <SupplierPrice>[const SupplierPrice(unitPrice: 8)],
      );
      expect(supplier.prices.last.unitPrice, 8);
      expect(supplier.priceOn(DateTime(2020))?.unitPrice, 8);
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

    test('le coût survit à l’attribution d’un identifiant', () async {
      final List<Product> products = await repository.fetchProducts();
      final Product product = products.first;

      await repository.registerMovement(
        StockMovement(
          id: '',
          productId: product.id,
          date: DateTime(2030),
          type: MovementType.entree,
          quantity: 10,
          user: 'Admin',
          unitCost: 7.25,
          supplierId: 'sup-9',
        ),
      );

      final StockMovement stored =
          (await repository.fetchMovements(product.id)).first;
      expect(stored.id, isNotEmpty);
      expect(stored.unitCost, 7.25);
      expect(stored.supplierId, 'sup-9');
      expect(stored.totalCost, 72.5);
    });

    test('un mouvement sans coût vaut « inconnu », pas zéro', () async {
      final List<Product> products = await repository.fetchProducts();
      final Product product = products.first;

      await repository.registerMovement(
        StockMovement(
          id: '',
          productId: product.id,
          date: DateTime(2030),
          type: MovementType.entree,
          quantity: 10,
          user: 'Admin',
        ),
      );

      final StockMovement stored =
          (await repository.fetchMovements(product.id)).first;
      // `null` et non 0 : un zéro laisserait croire que la marchandise n'a
      // rien coûté et fausserait toute somme.
      expect(stored.unitCost, isNull);
      expect(stored.totalCost, isNull);
    });

    test('enregistrer un tarif ajoute une ligne sans écraser', () async {
      final Product tomate = (await repository.fetchProducts())
          .firstWhere((Product p) => p.name == 'Tomate');
      final ProductSupplier before = tomate.supplierById('sup-1')!;
      final int lignesAvant = before.prices.length;

      final Product after = await repository.recordSupplierPrice(
        productId: tomate.id,
        supplierId: 'sup-1',
        unitPrice: 6.60,
        validFrom: DateTime(2026, 8, 19),
        source: PriceSource.reception,
      );

      final ProductSupplier updated = after.supplierById('sup-1')!;
      expect(updated.unitPrice, 6.60);
      expect(updated.prices.length, lignesAvant + 1);
      expect(updated.previousPrice?.unitPrice, before.unitPrice);
      expect(updated.currentPrice.source, PriceSource.reception);
    });

    test('enregistrer un tarif ne touche pas aux autres fournisseurs',
        () async {
      final Product tomate = (await repository.fetchProducts())
          .firstWhere((Product p) => p.name == 'Tomate');
      final double freshFoodAvant = tomate.supplierById('sup-2')!.unitPrice;

      final Product after = await repository.recordSupplierPrice(
        productId: tomate.id,
        supplierId: 'sup-1',
        unitPrice: 7,
      );

      expect(after.supplierById('sup-2')!.unitPrice, freshFoodAvant);
    });

    test('un fournisseur non associé est refusé', () async {
      final Product tomate = (await repository.fetchProducts())
          .firstWhere((Product p) => p.name == 'Tomate');

      expect(
        () => repository.recordSupplierPrice(
          productId: tomate.id,
          supplierId: 'sup-inconnu',
          unitPrice: 7,
        ),
        throwsStateError,
      );
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
