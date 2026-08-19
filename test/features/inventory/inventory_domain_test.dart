import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/constants/app_enums.dart';
import 'package:gestion_stock/features/inventory/data/repositories/in_memory_inventory_repository.dart';
import 'package:gestion_stock/features/inventory/domain/entities/inventory.dart';
import 'package:gestion_stock/features/inventory/domain/entities/inventory_line.dart';
import 'package:gestion_stock/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:gestion_stock/features/inventory/domain/usecases/create_inventory.dart';
import 'package:gestion_stock/features/inventory/domain/usecases/validate_inventory.dart';
import 'package:gestion_stock/features/stock/data/repositories/in_memory_product_repository.dart';
import 'package:gestion_stock/features/stock/domain/entities/product.dart';
import 'package:gestion_stock/features/stock/domain/entities/stock_movement.dart';

InventoryLine buildLine({
  String productId = 'p-001',
  String productName = 'Tomate',
  double theoretical = 100,
  double unitPrice = 6,
  double? counted,
}) {
  return InventoryLine(
    productId: productId,
    productName: productName,
    unit: 'kg',
    theoreticalStock: theoretical,
    unitPrice: unitPrice,
    countedStock: counted,
  );
}

Inventory buildInventory({
  InventoryStatus status = InventoryStatus.enCours,
  List<InventoryLine>? lines,
}) {
  return Inventory(
    id: 'inv-test',
    reference: 'INV-2024-999',
    createdAt: DateTime(2024, 5, 30),
    status: status,
    scope: InventoryScope.tous,
    createdBy: 'Admin',
    lines: lines ?? <InventoryLine>[buildLine()],
  );
}

void main() {
  group('InventoryLine', () {
    test('non compté n’est pas compté à zéro', () {
      final InventoryLine notCounted = buildLine();
      final InventoryLine countedZero = buildLine(counted: 0);

      expect(notCounted.isCounted, isFalse);
      expect(notCounted.variance, isNull);
      expect(notCounted.hasVariance, isFalse);

      expect(countedZero.isCounted, isTrue);
      expect(countedZero.variance, -100);
      expect(countedZero.hasVariance, isTrue);
    });

    test('l’écart est signé et valorisé au prix figé', () {
      expect(buildLine(theoretical: 100, counted: 95).variance, -5);
      expect(buildLine(theoretical: 80, counted: 82).variance, 2);
      expect(
        buildLine(theoretical: 100, counted: 95, unitPrice: 6).varianceValue,
        -30,
      );
    });

    test('compter la quantité théorique ne crée pas d’écart', () {
      final InventoryLine line = buildLine(theoretical: 50, counted: 50);
      expect(line.isCounted, isTrue);
      expect(line.variance, 0);
      expect(line.hasVariance, isFalse);
    });
  });

  group('Inventory', () {
    final Inventory inventory = buildInventory(
      lines: <InventoryLine>[
        buildLine(productId: 'a', theoretical: 100, counted: 95, unitPrice: 6),
        buildLine(productId: 'b', theoretical: 50, counted: 50, unitPrice: 4),
        buildLine(productId: 'c', theoretical: 80, counted: 82, unitPrice: 5),
        buildLine(productId: 'd', theoretical: 30),
      ],
    );

    test('l’avancement ne compte que les lignes saisies', () {
      expect(inventory.totalCount, 4);
      expect(inventory.countedCount, 3);
      expect(inventory.remainingCount, 1);
      expect(inventory.progress, 0.75);
    });

    test('seules les lignes comptées et non conformes sont des écarts', () {
      expect(inventory.varianceCount, 2);
      expect(
        inventory.variances.map((InventoryLine l) => l.productId),
        <String>['a', 'c'],
      );
    });

    test('l’écart total est valorisé', () {
      // a : -5 x 6 = -30 ; c : +2 x 5 = +10
      expect(inventory.totalVarianceValue, -20);
    });

    test('les transitions suivent le cycle de vie', () {
      expect(buildInventory(status: InventoryStatus.brouillon).isCountable, isTrue);
      expect(buildInventory(status: InventoryStatus.enCours).isCountable, isTrue);
      expect(buildInventory(status: InventoryStatus.termine).isCountable, isFalse);

      expect(buildInventory(status: InventoryStatus.termine).canValidate, isTrue);
      expect(buildInventory(status: InventoryStatus.enCours).canValidate, isFalse);
      expect(buildInventory(status: InventoryStatus.valide).isFinal, isTrue);
    });

    test('on ne peut clore qu’après au moins un comptage', () {
      expect(buildInventory().canClose, isFalse);
      expect(
        buildInventory(lines: <InventoryLine>[buildLine(counted: 10)]).canClose,
        isTrue,
      );
    });
  });

  group('CreateInventory', () {
    late InMemoryProductRepository products;
    late InventoryRepository inventories;
    late CreateInventory createInventory;

    setUp(() {
      products = InMemoryProductRepository(latency: Duration.zero);
      inventories = InMemoryInventoryRepository(latency: Duration.zero);
      createInventory = CreateInventory(
        inventories: inventories,
        products: products,
      );
    });

    test('un inventaire complet couvre tous les produits', () async {
      final Inventory inventory = await createInventory(
        scope: InventoryScope.tous,
        createdBy: 'Admin',
      );

      expect(inventory.totalCount, (await products.fetchProducts()).length);
      expect(inventory.status, InventoryStatus.brouillon);
      expect(inventory.countedCount, 0);
    });

    test('un inventaire par catégorie ne prend que cette catégorie', () async {
      final Inventory inventory = await createInventory(
        scope: InventoryScope.categorie,
        categoryId: 'cat-2',
        categoryName: 'Épicerie',
        createdBy: 'Admin',
      );

      expect(inventory.totalCount, 3);
      expect(inventory.categoryName, 'Épicerie');
      expect(
        inventory.lines.every((InventoryLine l) => l.categoryName == 'Épicerie'),
        isTrue,
      );
    });

    test('le stock théorique est figé à l’ouverture', () async {
      final Inventory inventory = await createInventory(
        scope: InventoryScope.tous,
        createdBy: 'Admin',
      );
      final InventoryLine line = inventory.lines
          .firstWhere((InventoryLine l) => l.productName == 'Tomate');
      final double snapshot = line.theoreticalStock;

      // Le service continue : une sortie est enregistrée pendant le comptage.
      await products.registerMovement(
        StockMovement(
          id: '',
          productId: line.productId,
          date: DateTime(2024, 5, 30),
          type: MovementType.sortie,
          quantity: -30,
          user: 'Ahmed',
        ),
      );

      final Inventory reloaded = (await inventories.fetchInventory(
        inventory.id,
      ))!;
      final InventoryLine after = reloaded.lines
          .firstWhere((InventoryLine l) => l.productId == line.productId);

      expect(after.theoreticalStock, snapshot);
    });
  });

  group('ValidateInventory', () {
    late InMemoryProductRepository products;
    late InventoryRepository inventories;
    late CreateInventory createInventory;
    late ValidateInventory validateInventory;

    setUp(() {
      products = InMemoryProductRepository(latency: Duration.zero);
      inventories = InMemoryInventoryRepository(latency: Duration.zero);
      createInventory = CreateInventory(
        inventories: inventories,
        products: products,
      );
      validateInventory = ValidateInventory(
        inventories: inventories,
        products: products,
      );
    });

    /// Ouvre un inventaire, compte une ligne, puis clôt le comptage.
    Future<(Inventory, InventoryLine)> prepare({
      required double counted,
    }) async {
      Inventory inventory = await createInventory(
        scope: InventoryScope.tous,
        createdBy: 'Admin',
      );
      final InventoryLine target = inventory.lines
          .firstWhere((InventoryLine l) => l.productName == 'Tomate');

      inventory = await inventories.saveCount(
        inventoryId: inventory.id,
        productId: target.productId,
        countedStock: counted,
      );
      inventory = await inventories.updateStatus(
        inventory.id,
        InventoryStatus.termine,
      );
      return (inventory, target);
    }

    test('l’ajustement porte le prix figé de la ligne', () async {
      final (Inventory inventory, InventoryLine line) =
          await prepare(counted: 80);

      await validateInventory(inventory, validatedBy: 'Admin Demo');

      final StockMovement movement =
          (await products.fetchMovements(line.productId)).first;
      // Le prix vient de l'inventaire, figé à son ouverture : un écart de
      // comptage n'est pas un achat et ne fixe aucun prix nouveau.
      expect(movement.unitCost, line.unitPrice);
    });

    test('un écart génère un ajustement et corrige le stock', () async {
      final (Inventory inventory, InventoryLine line) =
          await prepare(counted: 80);

      final InventoryValidationResult result = await validateInventory(
        inventory,
        validatedBy: 'Admin Demo',
      );

      expect(result.adjustmentsApplied, 1);
      expect(result.inventory.status, InventoryStatus.valide);

      final Product? product = await products.fetchProduct(line.productId);
      expect(product!.currentStock, 80);
    });

    test('l’ajustement est tracé avec la référence de l’inventaire', () async {
      final (Inventory inventory, InventoryLine line) =
          await prepare(counted: 80);

      await validateInventory(inventory, validatedBy: 'Admin Demo');

      final List<StockMovement> movements =
          await products.fetchMovements(line.productId);
      final StockMovement adjustment = movements.first;

      expect(adjustment.type, MovementType.ajustement);
      expect(adjustment.reference, inventory.reference);
      expect(adjustment.user, 'Admin Demo');
      expect(adjustment.quantity, line.theoreticalStock * -1 + 80);
    });

    test('les produits non comptés gardent leur stock', () async {
      final (Inventory inventory, InventoryLine _) = await prepare(counted: 80);
      final List<Product> before = await products.fetchProducts();
      final Product untouched =
          before.firstWhere((Product p) => p.name == 'Carotte');

      final InventoryValidationResult result = await validateInventory(
        inventory,
        validatedBy: 'Admin Demo',
      );

      final Product? after = await products.fetchProduct(untouched.id);
      expect(after!.currentStock, untouched.currentStock);
      expect(result.linesSkipped, inventory.remainingCount);
      expect(result.adjustmentsApplied, 1);
    });

    test('une ligne conforme ne génère aucun mouvement', () async {
      Inventory inventory = await createInventory(
        scope: InventoryScope.tous,
        createdBy: 'Admin',
      );
      final InventoryLine line = inventory.lines
          .firstWhere((InventoryLine l) => l.productName == 'Tomate');

      inventory = await inventories.saveCount(
        inventoryId: inventory.id,
        productId: line.productId,
        countedStock: line.theoreticalStock,
      );
      inventory = await inventories.updateStatus(
        inventory.id,
        InventoryStatus.termine,
      );

      final InventoryValidationResult result = await validateInventory(
        inventory,
        validatedBy: 'Admin Demo',
      );

      expect(result.adjustmentsApplied, 0);
      // Le produit a déjà un historique issu des fixtures : ce qu'on vérifie,
      // c'est qu'aucun mouvement portant la référence de cet inventaire n'a
      // été ajouté.
      final List<StockMovement> movements =
          await products.fetchMovements(line.productId);
      expect(
        movements.where((StockMovement m) => m.reference == inventory.reference),
        isEmpty,
      );
    });

    test('valider un inventaire non clos est refusé', () async {
      final Inventory inventory = await createInventory(
        scope: InventoryScope.tous,
        createdBy: 'Admin',
      );

      expect(
        () => validateInventory(inventory, validatedBy: 'Admin Demo'),
        throwsStateError,
      );
    });
  });

  group('InMemoryInventoryRepository', () {
    late InMemoryInventoryRepository repository;

    setUp(() {
      repository = InMemoryInventoryRepository(latency: Duration.zero);
    });

    test('le premier comptage fait sortir du brouillon', () async {
      final List<Inventory> all = await repository.fetchInventories();
      final Inventory draft = all.firstWhere(
        (Inventory i) => i.status == InventoryStatus.brouillon,
      );

      final Inventory updated = await repository.saveCount(
        inventoryId: draft.id,
        productId: draft.lines.first.productId,
        countedStock: 100,
      );

      expect(updated.status, InventoryStatus.enCours);
      expect(updated.countedCount, 1);
    });

    test('vider une saisie annule le comptage de la ligne', () async {
      final List<Inventory> all = await repository.fetchInventories();
      final Inventory draft = all.firstWhere(
        (Inventory i) => i.status == InventoryStatus.brouillon,
      );
      final String productId = draft.lines.first.productId;

      await repository.saveCount(
        inventoryId: draft.id,
        productId: productId,
        countedStock: 100,
      );
      final Inventory cleared = await repository.saveCount(
        inventoryId: draft.id,
        productId: productId,
        countedStock: null,
      );

      final InventoryLine line = cleared.lines
          .firstWhere((InventoryLine l) => l.productId == productId);
      expect(line.isCounted, isFalse);
      expect(cleared.countedCount, 0);
    });

    test('un comptage clos ne peut plus être modifié', () async {
      final List<Inventory> all = await repository.fetchInventories();
      final Inventory closed = all.firstWhere(
        (Inventory i) => i.status == InventoryStatus.termine,
      );

      expect(
        () => repository.saveCount(
          inventoryId: closed.id,
          productId: closed.lines.first.productId,
          countedStock: 1,
        ),
        throwsStateError,
      );
    });

    test('les fixtures reproduisent les écarts de la maquette', () async {
      final List<Inventory> all = await repository.fetchInventories();

      final Inventory closed =
          all.firstWhere((Inventory i) => i.reference == 'INV-2024-006');
      expect(closed.totalVarianceValue, -1196);

      final Inventory validated =
          all.firstWhere((Inventory i) => i.reference == 'INV-2024-005');
      expect(validated.totalVarianceValue, 52);
    });
  });
}
