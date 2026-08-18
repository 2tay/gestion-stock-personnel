import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/constants/app_enums.dart';
import 'package:gestion_stock/features/purchasing/data/repositories/in_memory_purchasing_repositories.dart';
import 'package:gestion_stock/features/purchasing/domain/entities/purchase_order.dart';
import 'package:gestion_stock/features/purchasing/domain/repositories/purchasing_repositories.dart';
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

    test('le prix d’achat du produit suit celui de la commande', () async {
      final PurchaseOrder cmd = await order('CMD-005');
      // Carotte est à 4,8 dans le stock, la commande la paie 3,00.
      expect((await products.fetchProduct('p-004'))!.unitPrice, 4.8);

      final OrderReceptionResult result = await receiveOrder(
        cmd,
        receivedQuantities: <String, double>{'p-004': 50},
        receivedBy: 'Admin Demo',
      );

      expect(result.repricedProductIds, <String>['p-004']);
      expect((await products.fetchProduct('p-004'))!.unitPrice, 3);
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
