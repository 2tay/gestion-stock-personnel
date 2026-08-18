import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/constants/app_enums.dart';
import 'package:gestion_stock/core/theme/app_theme.dart';
import 'package:gestion_stock/core/utils/formatters.dart';
import 'package:gestion_stock/features/purchasing/data/repositories/in_memory_purchasing_repositories.dart';
import 'package:gestion_stock/features/purchasing/domain/entities/purchase_order.dart';
import 'package:gestion_stock/features/purchasing/domain/entities/shopping_item.dart';
import 'package:gestion_stock/features/purchasing/domain/usecases/build_shopping_list.dart';
import 'package:gestion_stock/features/purchasing/presentation/controllers/purchasing_providers.dart';
import 'package:gestion_stock/features/purchasing/presentation/pages/purchasing_page.dart';
import 'package:gestion_stock/features/stock/data/repositories/in_memory_product_repository.dart';
import 'package:gestion_stock/features/stock/domain/entities/product.dart';
import 'package:gestion_stock/features/stock/domain/entities/stock_movement.dart';
import 'package:gestion_stock/features/stock/presentation/controllers/stock_providers.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  group('BuildShoppingList', () {
    late InMemoryProductRepository products;
    late InMemoryPurchaseOrderRepository orders;
    late InMemorySupplierRepository suppliers;
    late BuildShoppingList buildShoppingList;

    setUp(() {
      products = InMemoryProductRepository(latency: Duration.zero);
      orders = InMemoryPurchaseOrderRepository(latency: Duration.zero);
      suppliers = InMemorySupplierRepository(latency: Duration.zero);
      buildShoppingList = BuildShoppingList(
        products: products,
        orders: orders,
        suppliers: suppliers,
      );
    });

    test('ne retient que les produits sous leur seuil', () async {
      final ShoppingList list = await buildShoppingList();
      final List<Product> all = await products.fetchProducts();

      final Set<String> expected = all
          .where((Product p) => p.status != StockStatus.ok)
          .map((Product p) => p.id)
          .toSet();
      final Set<String> found =
          list.items.map((ShoppingItem i) => i.productId).toSet();

      // Tous les produits retenus sont bien sous seuil…
      expect(found.difference(expected), isEmpty);
      // …et Tomate, largement au-dessus, n'y est pas.
      expect(found.contains('p-001'), isFalse);
    });

    test('les ruptures sont classées en premier', () async {
      final ShoppingList list = await buildShoppingList();
      expect(list.items.first.status, StockStatus.rupture);
      expect(list.outOfStockCount, greaterThan(0));
    });

    test('la quantité proposée ramène au stock maximum', () async {
      final ShoppingList list = await buildShoppingList();
      // Beurre 500g : stock 0, maximum 30, rien en commande.
      final ShoppingItem beurre = list.items
          .firstWhere((ShoppingItem i) => i.productId == 'p-010');
      expect(beurre.quantity, 30);
      expect(beurre.pendingQuantity, 0);
    });

    test('ce qui est déjà commandé est déduit du besoin', () async {
      // Riz 10kg : stock 38, seuil 40, maximum 100 → besoin brut de 62.
      // CMD-004 en attend déjà 3.
      final ShoppingList list = await buildShoppingList();
      final ShoppingItem riz =
          list.items.firstWhere((ShoppingItem i) => i.productId == 'p-007');

      expect(riz.pendingQuantity, 3);
      expect(riz.quantity, 62 - 3);
    });

    test('un produit entièrement couvert sort de la liste', () async {
      // On commande de quoi couvrir tout le manque de Beurre 500g.
      final List<Product> all = await products.fetchProducts();
      final Product beurre =
          all.firstWhere((Product p) => p.id == 'p-010');

      await orders.createOrder(
        supplier: (await suppliers.fetchSuppliers()).first,
        createdBy: 'Admin',
        lines: <OrderLine>[
          OrderLine(
            productId: beurre.id,
            productName: beurre.name,
            unit: beurre.unit,
            quantityOrdered: beurre.quantityToOrder,
            unitPrice: beurre.unitPrice,
          ),
        ],
      );

      final ShoppingList list = await buildShoppingList();
      expect(
        list.items.any((ShoppingItem i) => i.productId == 'p-010'),
        isFalse,
      );
      expect(list.coveredByPendingOrders, greaterThan(0));
    });

    test('une commande annulée ne couvre plus rien', () async {
      final List<Product> all = await products.fetchProducts();
      final Product beurre = all.firstWhere((Product p) => p.id == 'p-010');

      final PurchaseOrder created = await orders.createOrder(
        supplier: (await suppliers.fetchSuppliers()).first,
        createdBy: 'Admin',
        lines: <OrderLine>[
          OrderLine(
            productId: beurre.id,
            productName: beurre.name,
            unit: beurre.unit,
            quantityOrdered: beurre.quantityToOrder,
            unitPrice: beurre.unitPrice,
          ),
        ],
      );
      await orders.updateLifecycle(
        orderId: created.id,
        lifecycle: OrderLifecycle.annulee,
      );

      final ShoppingList list = await buildShoppingList();
      expect(
        list.items.any((ShoppingItem i) => i.productId == 'p-010'),
        isTrue,
      );
    });

    test('le fournisseur principal est retenu, les autres restent proposés',
        () async {
      final ShoppingList list = await buildShoppingList();
      // Carotte a AgriPlus en principal et DistriFood en alternative.
      final ShoppingItem carotte =
          list.items.firstWhere((ShoppingItem i) => i.productId == 'p-004');

      expect(carotte.supplierName, 'AgriPlus');
      expect(carotte.hasAlternatives, isTrue);
      expect(carotte.supplierOptions.length, 2);
    });

    test('un produit sans fournisseur reste listé mais non commandable',
        () async {
      // Soda 33cl n'a aucun fournisseur associé.
      final ShoppingList list = await buildShoppingList();
      final ShoppingItem soda =
          list.items.firstWhere((ShoppingItem i) => i.productId == 'p-013');

      expect(soda.supplierId, isNull);
      expect(soda.canOrder, isFalse);
      expect(list.withoutSupplierCount, greaterThan(0));
    });

    test('recevoir la marchandise fait sortir le produit de la liste',
        () async {
      final ShoppingList before = await buildShoppingList();
      expect(
        before.items.any((ShoppingItem i) => i.productId == 'p-010'),
        isTrue,
      );

      // Le beurre arrive : 30 unités entrent en stock.
      await products.registerMovement(
        StockMovement(
          id: '',
          productId: 'p-010',
          date: DateTime(2024, 6),
          type: MovementType.entree,
          quantity: 30,
          user: 'Admin',
        ),
      );

      final ShoppingList after = await buildShoppingList();
      expect(
        after.items.any((ShoppingItem i) => i.productId == 'p-010'),
        isFalse,
      );
    });
  });

  group('ShoppingListController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: <Override>[
          productRepositoryProvider.overrideWithValue(
            InMemoryProductRepository(latency: Duration.zero),
          ),
          purchaseOrderRepositoryProvider.overrideWithValue(
            InMemoryPurchaseOrderRepository(latency: Duration.zero),
          ),
          supplierRepositoryProvider.overrideWithValue(
            InMemorySupplierRepository(latency: Duration.zero),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    Future<ShoppingList> loaded() async {
      final ShoppingListController controller =
          container.read(shoppingListControllerProvider.notifier);
      await controller.load();
      return container.read(shoppingListControllerProvider).value!;
    }

    test('changer de fournisseur reprend son prix', () async {
      await loaded();
      final ShoppingListController controller =
          container.read(shoppingListControllerProvider.notifier);

      ShoppingItem carotte = container
          .read(shoppingListControllerProvider)
          .value!
          .items
          .firstWhere((ShoppingItem i) => i.productId == 'p-004');
      expect(carotte.unitPrice, 4.8);

      controller.setSupplier('p-004', 'sup-3');

      carotte = container
          .read(shoppingListControllerProvider)
          .value!
          .items
          .firstWhere((ShoppingItem i) => i.productId == 'p-004');
      expect(carotte.supplierName, 'DistriFood');
      expect(carotte.unitPrice, 5.1);
    });

    test('générer crée une commande par fournisseur', () async {
      await loaded();
      final ShoppingListController controller =
          container.read(shoppingListControllerProvider.notifier);

      final List<PurchaseOrder> created =
          await controller.generateOrders(createdBy: 'Admin Demo');

      // Une commande par fournisseur distinct des lignes commandables.
      final Set<String> suppliers =
          created.map((PurchaseOrder o) => o.supplierId).toSet();
      expect(created.length, suppliers.length);
      expect(created, isNotEmpty);

      // Les commandes créées sont ouvertes et rien n'est encore reçu.
      for (final PurchaseOrder order in created) {
        expect(order.lifecycle, OrderLifecycle.ouverte);
        expect(order.receivedQuantity, 0);
      }
    });

    test('les produits commandés sortent de la liste après génération',
        () async {
      await loaded();
      final ShoppingListController controller =
          container.read(shoppingListControllerProvider.notifier);

      await controller.generateOrders(createdBy: 'Admin Demo');
      final ShoppingList after =
          container.read(shoppingListControllerProvider).value!;

      // Il ne reste que les produits sans fournisseur.
      expect(
        after.items.every((ShoppingItem i) => i.supplierId == null),
        isTrue,
      );
      expect(after.coveredByPendingOrders, greaterThan(0));
    });

    test('une ligne décochée n’est pas commandée', () async {
      await loaded();
      final ShoppingListController controller =
          container.read(shoppingListControllerProvider.notifier)
            ..selectAll(false)
            ..setSelected('p-010', true);

      final List<PurchaseOrder> created =
          await controller.generateOrders(createdBy: 'Admin Demo');

      expect(created.length, 1);
      expect(created.single.lines.length, 1);
      expect(created.single.lines.single.productId, 'p-010');
    });

    test('générer pour un seul fournisseur ne touche pas les autres',
        () async {
      final ShoppingList list = await loaded();
      final ShoppingListController controller =
          container.read(shoppingListControllerProvider.notifier);

      final String supplierId = list.items
          .firstWhere((ShoppingItem i) => i.supplierId != null)
          .supplierId!;

      final List<PurchaseOrder> created = await controller.generateOrders(
        createdBy: 'Admin Demo',
        onlySupplierId: supplierId,
      );

      expect(created.length, 1);
      expect(created.single.supplierId, supplierId);
    });
  });

  group('ShoppingListSection', () {
    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            productRepositoryProvider.overrideWithValue(
              InMemoryProductRepository(latency: Duration.zero),
            ),
            purchaseOrderRepositoryProvider.overrideWithValue(
              InMemoryPurchaseOrderRepository(latency: Duration.zero),
            ),
            supplierRepositoryProvider.overrideWithValue(
              InMemorySupplierRepository(latency: Duration.zero),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const PurchasingPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('la section groupe les produits par fournisseur',
        (WidgetTester tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('À commander'));
      await tester.pumpAndSettle();

      expect(find.text('Produits à commander'), findsOneWidget);
      expect(find.text('AgriPlus'), findsOneWidget);
      expect(find.text('Sans fournisseur'), findsOneWidget);
      expect(find.text('Beurre 500g'), findsOneWidget);
    });

    testWidgets('générer les commandes bascule sur la liste des commandes',
        (WidgetTester tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('À commander'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Générer les commandes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Une commande sera créée'), findsOneWidget);
      await tester.tap(find.text('Générer').last);
      await tester.pumpAndSettle();

      // On se retrouve sur les commandes, avec les nouvelles références.
      expect(find.text('CMD-006'), findsOneWidget);
    });
  });
}
