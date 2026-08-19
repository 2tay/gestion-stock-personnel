import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/constants/app_enums.dart';
import 'package:gestion_stock/features/purchasing/data/repositories/in_memory_purchasing_repositories.dart';
import 'package:gestion_stock/features/purchasing/domain/entities/purchase_order.dart';
import 'package:gestion_stock/features/purchasing/domain/repositories/purchasing_repositories.dart';
import 'package:gestion_stock/features/purchasing/domain/usecases/apply_supplier_prices.dart';
import 'package:gestion_stock/features/purchasing/domain/usecases/receive_order.dart';
import 'package:gestion_stock/features/stock/data/repositories/in_memory_product_repository.dart';
import 'package:gestion_stock/features/stock/domain/entities/product.dart';
import 'package:gestion_stock/features/stock/domain/entities/stock_movement.dart';

OrderLine buildLine({
  String productId = 'p-001',
  String productName = 'Tomate',
  double ordered = 50,
  double received = 0,
  double unitPrice = 6,
}) {
  return OrderLine(
    productId: productId,
    productName: productName,
    unit: 'kg',
    quantityOrdered: ordered,
    quantityReceived: received,
    unitPrice: unitPrice,
  );
}

PurchaseOrder buildOrder({
  OrderLifecycle lifecycle = OrderLifecycle.ouverte,
  List<OrderLine>? lines,
}) {
  return PurchaseOrder(
    id: 'ord-test',
    reference: 'CMD-999',
    supplierId: 'sup-1',
    supplierName: 'AgriPlus',
    createdAt: DateTime(2024, 5, 30),
    lifecycle: lifecycle,
    createdBy: 'Admin',
    lines: lines ?? <OrderLine>[buildLine()],
  );
}

void main() {
  group('OrderLine', () {
    test('distingue la valeur commandée de la valeur reçue', () {
      final OrderLine line =
          buildLine(ordered: 50, received: 40, unitPrice: 6);
      expect(line.orderedTotal, 300);
      expect(line.receivedTotal, 240);
      expect(line.remaining, 10);
      expect(line.isFullyReceived, isFalse);
    });

    test('reconnaît une sur-livraison', () {
      final OrderLine line = buildLine(ordered: 50, received: 55);
      expect(line.isFullyReceived, isTrue);
      expect(line.isOverDelivered, isTrue);
      expect(line.remaining, -5);
      expect(line.progress, 1);
    });
  });

  group('PurchaseOrder.status', () {
    test('se déduit des lignes quand la commande est ouverte', () {
      expect(
        buildOrder(lines: <OrderLine>[buildLine(received: 0)]).status,
        OrderStatus.enCours,
      );
      expect(
        buildOrder(lines: <OrderLine>[buildLine(ordered: 50, received: 20)])
            .status,
        OrderStatus.partielle,
      );
      expect(
        buildOrder(lines: <OrderLine>[buildLine(ordered: 50, received: 50)])
            .status,
        OrderStatus.recue,
      );
    });

    test('une ligne servie et une autre non donne « partielle »', () {
      final PurchaseOrder order = buildOrder(
        lines: <OrderLine>[
          buildLine(productId: 'a', ordered: 10, received: 10),
          buildLine(productId: 'b', ordered: 10, received: 0),
        ],
      );
      expect(order.status, OrderStatus.partielle);
    });

    test('les décisions de l’utilisateur priment sur les lignes', () {
      expect(
        buildOrder(lifecycle: OrderLifecycle.brouillon).status,
        OrderStatus.brouillon,
      );
      expect(
        buildOrder(lifecycle: OrderLifecycle.annulee).status,
        OrderStatus.annulee,
      );
      expect(
        buildOrder(
          lifecycle: OrderLifecycle.soldee,
          lines: <OrderLine>[buildLine(ordered: 50, received: 20)],
        ).status,
        OrderStatus.soldee,
      );
    });

    test('les totaux distinguent engagé et livré', () {
      final PurchaseOrder order = buildOrder(
        lines: <OrderLine>[
          buildLine(productId: 'a', ordered: 50, received: 40, unitPrice: 6),
          buildLine(productId: 'b', ordered: 30, received: 30, unitPrice: 4),
          buildLine(productId: 'c', ordered: 50, received: 30, unitPrice: 3),
        ],
      );
      // Les chiffres de la maquette pour CMD-005.
      expect(order.orderedTotal, 570);
      expect(order.receivedTotal, 450);
      expect(order.orderedQuantity, 130);
      expect(order.receivedQuantity, 100);
    });
  });

  group('Règles d’annulation et de solde', () {
    test('on annule tant que rien n’est arrivé', () {
      expect(buildOrder().canCancel, isTrue);
      expect(
        buildOrder(lines: <OrderLine>[buildLine(received: 10)]).canCancel,
        isFalse,
      );
    });

    test('on solde une commande partiellement livrée', () {
      expect(buildOrder().canClose, isFalse);
      expect(
        buildOrder(lines: <OrderLine>[buildLine(ordered: 50, received: 20)])
            .canClose,
        isTrue,
      );
      expect(
        buildOrder(lines: <OrderLine>[buildLine(ordered: 50, received: 50)])
            .canClose,
        isFalse,
      );
    });

    test('les lignes se figent dès la première réception', () {
      expect(buildOrder().isEditable, isTrue);
      expect(
        buildOrder(lines: <OrderLine>[buildLine(received: 1)]).isEditable,
        isFalse,
      );
    });
  });

  group('ReceiveOrder', () {
    late InMemoryProductRepository products;
    late PurchaseOrderRepository orders;
    late ReceiveOrder receiveOrder;

    setUp(() {
      products = InMemoryProductRepository(latency: Duration.zero);
      orders = InMemoryPurchaseOrderRepository(latency: Duration.zero);
      receiveOrder = ReceiveOrder(orders: orders, products: products);
    });

    Future<PurchaseOrder> order(String reference) async {
      final List<PurchaseOrder> all = await orders.fetchOrders();
      return all.firstWhere((PurchaseOrder o) => o.reference == reference);
    }

    test('une première réception entre en stock', () async {
      final PurchaseOrder cmd = await order('CMD-005');
      final Product before = (await products.fetchProduct('p-002'))!;

      // Oignon est déjà reçu à 30 ; on ne change rien pour lui, et on passe
      // Carotte de 30 à 50.
      final OrderReceptionResult result = await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );

      expect(result.receivedProductIds, <String>['p-004']);
      final Product carotte = (await products.fetchProduct('p-004'))!;
      // 55 au départ, +20 reçus.
      expect(carotte.currentStock, 75);
      // Oignon n'a pas été touché.
      expect((await products.fetchProduct('p-002'))!.currentStock,
          before.currentStock);
    });

    test('le mouvement porte l’écart, pas le cumul', () async {
      final PurchaseOrder cmd = await order('CMD-005');

      // La ligne Tomate est déjà à 40 reçus sur 50. On passe à 50.
      await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-001': 50},
        receivedBy: 'Admin Demo',
      );

      final List<StockMovement> movements =
          await products.fetchMovements('p-001');
      final StockMovement entry = movements.first;

      expect(entry.type, MovementType.entree);
      // 10 de plus, pas 50.
      expect(entry.quantity, 10);
      expect(entry.reference, 'CMD-005');
      expect(entry.user, 'Admin Demo');
    });

    test('deux réceptions successives n’additionnent pas le cumul', () async {
      PurchaseOrder cmd = await order('CMD-005');
      final Product start = (await products.fetchProduct('p-004'))!;

      final OrderReceptionResult first = await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 40},
        receivedBy: 'Admin Demo',
      );
      cmd = first.order;

      await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );

      // 30 déjà reçus au départ, puis 40, puis 50 : le stock n'augmente que
      // de 20 au total.
      final Product carotte = (await products.fetchProduct('p-004'))!;
      expect(carotte.currentStock, start.currentStock + 20);
    });

    test('une correction à la baisse est un ajustement', () async {
      final PurchaseOrder cmd = await order('CMD-005');

      final OrderReceptionResult result = await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-001': 35},
        receivedBy: 'Admin Demo',
      );

      expect(result.correctedProductIds, <String>['p-001']);
      expect(result.receivedProductIds, isEmpty);

      final StockMovement movement =
          (await products.fetchMovements('p-001')).first;
      expect(movement.type, MovementType.ajustement);
      expect(movement.quantity, -5);
      expect(movement.note, 'Correction de réception');
    });

    test('le dernier prix payé est consigné sur le produit', () async {
      final PurchaseOrder cmd = await order('CMD-005');
      // Carotte a été payée 4,80 à la dernière livraison ; la commande en
      // cours la paie 3,00.
      expect((await products.fetchProduct('p-004'))!.lastPurchasePrice, 4.8);

      final OrderReceptionResult result = await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );

      final Product carotte = (await products.fetchProduct('p-004'))!;
      expect(result.receivedProductIds, <String>['p-004']);
      expect(carotte.lastPurchasePrice, 3);
      expect(carotte.lastSupplierId, 'sup-1');
      expect(carotte.lastPurchaseDate, isNotNull);
    });

    test('le coût moyen est recalculé, pas écrasé', () async {
      final PurchaseOrder cmd = await order('CMD-005');
      final Product avant = (await products.fetchProduct('p-004'))!;
      // Carotte : 55 kg au coût moyen de 4,80 ; la commande en livre 20 à 3.
      expect(avant.currentStock, 55);
      expect(avant.averageCost, 4.8);

      await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );

      final Product apres = (await products.fetchProduct('p-004'))!;
      const double attendu = (55 * 4.8 + 20 * 3) / 75;
      expect(apres.currentStock, 75);
      expect(apres.averageCost, closeTo(attendu, 0.000001));
      // Surtout pas 3,00 : le stock détenu avant la livraison a bien coûté
      // 4,80, et il est toujours là.
      expect(apres.averageCost, greaterThan(3));
      expect(apres.averageCost, lessThan(4.8));
      // La valeur du stock est exactement ce qui a été dépensé.
      expect(apres.stockValue, closeTo(55 * 4.8 + 20 * 3, 0.000001));
    });

    test('corriger une réception restitue le coût moyen d’avant', () async {
      final PurchaseOrder cmd = await order('CMD-005');
      final double coutAvant =
          (await products.fetchProduct('p-004'))!.averageCost;

      // On saisit 50, puis on se ravise et on revient à 30, le cumul initial.
      await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );
      final PurchaseOrder apresPremiere = await order('CMD-005');
      await receiveOrder(
        apresPremiere,
        receivedQuantities: <String, double>{'p-004': 30},
        receivedBy: 'Admin Demo',
      );

      final Product apres = (await products.fetchProduct('p-004'))!;
      expect(apres.currentStock, 55);
      expect(apres.averageCost, closeTo(coutAvant, 0.000001));
      // La correction n'est pas un achat : le dernier prix payé reste celui
      // de la livraison, qui a bien eu lieu.
      expect(apres.lastPurchasePrice, 3);
    });

    test('le mouvement porte le prix payé et le fournisseur', () async {
      final PurchaseOrder cmd = await order('CMD-005');

      // Carotte : 30 déjà reçus sur 50, payés 3,00 par AgriPlus.
      await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );

      final StockMovement movement =
          (await products.fetchMovements('p-004')).first;
      expect(movement.quantity, 20);
      expect(movement.unitCost, 3);
      expect(movement.supplierId, 'sup-1');
      // Le coût de cette entrée, indépendant de tout tarif futur.
      expect(movement.totalCost, 60);
    });

    test('une correction reprend le prix de la commande', () async {
      final PurchaseOrder cmd = await order('CMD-005');

      // Tomate passe de 40 à 35 reçus : on annule 5 unités payées 6,00.
      await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-001': 35},
        receivedBy: 'Admin Demo',
      );

      final StockMovement movement =
          (await products.fetchMovements('p-001')).first;
      expect(movement.unitCost, 6);
      expect(movement.totalCost, -30);
    });

    test('une quantité inchangée n’écrit rien', () async {
      final PurchaseOrder cmd = await order('CMD-005');
      final int before = (await products.fetchMovements('p-002')).length;

      final OrderReceptionResult result = await receiveOrder(
        cmd,
        // Oignon est déjà à 30 : aucun changement.
        receivedQuantities: <String, double>{'p-002': 30},
        receivedBy: 'Admin Demo',
      );

      expect(result.receivedProductIds, isEmpty);
      expect((await products.fetchMovements('p-002')).length, before);
    });

    test('recevoir sur une commande annulée est refusé', () async {
      final PurchaseOrder cmd = await order('CMD-005');
      final PurchaseOrder cancelled = await orders.updateLifecycle(
        orderId: cmd.id,
        lifecycle: OrderLifecycle.annulee,
      );

      expect(
        () => receiveOrder(
          cancelled,
          receivedQuantities: <String, double>{'p-001': 50},
          receivedBy: 'Admin Demo',
        ),
        throwsStateError,
      );
    });

    test('la commande enregistre le nouveau cumul reçu', () async {
      final PurchaseOrder cmd = await order('CMD-005');

      final OrderReceptionResult result = await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-001': 50, 'p-004': 50},
        receivedBy: 'Admin Demo',
      );

      expect(result.order.isFullyReceived, isTrue);
      expect(result.order.status, OrderStatus.recue);
      expect(result.order.receivedTotal, result.order.orderedTotal);
    });
  });

  group('Tarifs fournisseurs constatés à la réception', () {
    late InMemoryProductRepository products;
    late PurchaseOrderRepository orders;
    late ReceiveOrder receiveOrder;
    late ApplySupplierPrices applySupplierPrices;

    setUp(() {
      products = InMemoryProductRepository(latency: Duration.zero);
      orders = InMemoryPurchaseOrderRepository(latency: Duration.zero);
      receiveOrder = ReceiveOrder(orders: orders, products: products);
      applySupplierPrices = ApplySupplierPrices(products: products);
    });

    Future<PurchaseOrder> order(String reference) async {
      final List<PurchaseOrder> all = await orders.fetchOrders();
      return all.firstWhere((PurchaseOrder o) => o.reference == reference);
    }

    test('un prix différent du tarif est constaté, pas appliqué', () async {
      final PurchaseOrder cmd = await order('CMD-005');
      // Carotte : tarif AgriPlus à 4,80, la commande la paie 3,00.
      final ProductSupplier avant =
          (await products.fetchProduct('p-004'))!.supplierById('sup-1')!;
      expect(avant.unitPrice, 4.8);

      final OrderReceptionResult result = await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );

      expect(result.hasPriceDiscrepancies, isTrue);
      final SupplierPriceDiscrepancy ecart = result.priceDiscrepancies
          .firstWhere((SupplierPriceDiscrepancy d) => d.productId == 'p-004');
      expect(ecart.knownPrice, 4.8);
      expect(ecart.paidPrice, 3);
      expect(ecart.isIncrease, isFalse);
      expect(ecart.supplierId, 'sup-1');

      // Constaté seulement : le catalogue n'a pas bougé.
      final ProductSupplier apres =
          (await products.fetchProduct('p-004'))!.supplierById('sup-1')!;
      expect(apres.unitPrice, 4.8);
      expect(apres.prices.length, avant.prices.length);
    });

    test('une fois le tarif accepté, l’écart ne se répète plus', () async {
      // Carotte : tarif 4,80, commande à 3,00. On reçoit une partie, on
      // accepte le nouveau tarif, puis on reçoit le reste.
      final OrderReceptionResult premiere = await receiveOrder(
        await order('CMD-005'),
        receivedQuantities: <String, double>{'p-004': 40},
        receivedBy: 'Admin Demo',
      );
      expect(premiere.hasPriceDiscrepancies, isTrue);

      await applySupplierPrices(premiere.priceDiscrepancies);

      final OrderReceptionResult seconde = await receiveOrder(
        await order('CMD-005'),
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );

      // Le tarif enregistré vaut désormais le prix payé : plus rien à
      // signaler, et donc plus de question inutile à l'utilisateur.
      expect(
        seconde.priceDiscrepancies
            .where((SupplierPriceDiscrepancy d) => d.productId == 'p-004'),
        isEmpty,
      );
    });

    test('appliquer un écart ajoute un tarif sans effacer', () async {
      final PurchaseOrder cmd = await order('CMD-005');
      final ProductSupplier avant =
          (await products.fetchProduct('p-004'))!.supplierById('sup-1')!;

      final OrderReceptionResult result = await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );
      final List<String> updated =
          await applySupplierPrices(result.priceDiscrepancies);

      expect(updated, contains('p-004'));
      final ProductSupplier apres =
          (await products.fetchProduct('p-004'))!.supplierById('sup-1')!;
      expect(apres.unitPrice, 3);
      expect(apres.previousPrice?.unitPrice, avant.unitPrice);
      expect(apres.prices.length, avant.prices.length + 1);
      // On saura plus tard que ce tarif a été constaté, pas négocié.
      expect(apres.currentPrice.source, PriceSource.reception);
    });

    test('n’appliquer aucun écart ne change rien', () async {
      final PurchaseOrder cmd = await order('CMD-005');
      final ProductSupplier avant =
          (await products.fetchProduct('p-004'))!.supplierById('sup-1')!;

      await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );
      // L'utilisateur refuse : c'était une promotion ponctuelle.
      await applySupplierPrices(const <SupplierPriceDiscrepancy>[]);

      final ProductSupplier apres =
          (await products.fetchProduct('p-004'))!.supplierById('sup-1')!;
      expect(apres.unitPrice, avant.unitPrice);
      expect(apres.prices.length, avant.prices.length);
    });

    test('une correction à la baisse ne constate aucun tarif', () async {
      final PurchaseOrder cmd = await order('CMD-005');

      // Tomate passe de 40 à 35 reçus : ce n'est pas une livraison.
      final OrderReceptionResult result = await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-001': 35},
        receivedBy: 'Admin Demo',
      );

      expect(result.hasPriceDiscrepancies, isFalse);
    });
  });

  group('InMemoryPurchaseOrderRepository', () {
    late InMemoryPurchaseOrderRepository repository;

    setUp(() {
      repository = InMemoryPurchaseOrderRepository(latency: Duration.zero);
    });

    test('les fixtures reproduisent les montants de la maquette', () async {
      final List<PurchaseOrder> all = await repository.fetchOrders();

      final Map<String, double> totals = <String, double>{
        for (final PurchaseOrder o in all) o.reference: o.orderedTotal,
      };

      expect(totals['CMD-005'], 570);
      expect(totals['CMD-004'], 830);
      expect(totals['CMD-003'], 1250);
      expect(totals['CMD-002'], 430);
      expect(totals['CMD-001'], 980);
    });

    test('les statuts des fixtures correspondent à la maquette', () async {
      final List<PurchaseOrder> all = await repository.fetchOrders();
      final Map<String, OrderStatus> statuses = <String, OrderStatus>{
        for (final PurchaseOrder o in all) o.reference: o.status,
      };

      expect(statuses['CMD-005'], OrderStatus.partielle);
      expect(statuses['CMD-004'], OrderStatus.partielle);
      expect(statuses['CMD-003'], OrderStatus.recue);
      expect(statuses['CMD-002'], OrderStatus.recue);
      expect(statuses['CMD-001'], OrderStatus.recue);
    });

    test('modifier les lignes d’une commande servie est refusé', () async {
      final List<PurchaseOrder> all = await repository.fetchOrders();
      final PurchaseOrder served =
          all.firstWhere((PurchaseOrder o) => o.reference == 'CMD-005');

      expect(
        () => repository.saveLines(orderId: served.id, lines: <OrderLine>[]),
        throwsStateError,
      );
    });
  });
}
