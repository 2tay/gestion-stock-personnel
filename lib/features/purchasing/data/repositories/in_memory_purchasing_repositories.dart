import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/purchasing_repositories.dart';
import '../fixtures/purchasing_fixtures.dart';

/// Implémentation en mémoire de [SupplierRepository].
class InMemorySupplierRepository implements SupplierRepository {
  InMemorySupplierRepository({
    this.latency = const Duration(milliseconds: 250),
  });

  final Duration latency;

  final List<Supplier> _suppliers = PurchasingFixtures.suppliers();
  int _sequence = 100;

  Future<void> _wait() => Future<void>.delayed(latency);

  int _indexOf(String id) {
    for (int i = 0; i < _suppliers.length; i++) {
      if (_suppliers[i].id == id) return i;
    }
    return -1;
  }

  @override
  Future<List<Supplier>> fetchSuppliers() async {
    await _wait();
    return List<Supplier>.unmodifiable(_suppliers);
  }

  @override
  Future<Supplier?> fetchSupplier(String id) async {
    await _wait();
    final int index = _indexOf(id);
    return index == -1 ? null : _suppliers[index];
  }

  @override
  Future<Supplier> saveSupplier(Supplier supplier) async {
    await _wait();
    final int index = _indexOf(supplier.id);
    if (index == -1) {
      _suppliers.add(supplier);
    } else {
      _suppliers[index] = supplier;
    }
    return supplier;
  }

  @override
  Future<void> deleteSupplier(String id) async {
    await _wait();
    _suppliers.removeWhere((Supplier s) => s.id == id);
  }

  /// Identifiant à attribuer à un fournisseur créé depuis l'interface.
  String newSupplierId() => 'sup-${++_sequence}';
}

/// Implémentation en mémoire de [PurchaseOrderRepository].
class InMemoryPurchaseOrderRepository implements PurchaseOrderRepository {
  InMemoryPurchaseOrderRepository({
    this.latency = const Duration(milliseconds: 300),
  });

  final Duration latency;

  final List<PurchaseOrder> _orders = PurchasingFixtures.orders();
  int _sequence = PurchasingFixtures.nextSequence;

  Future<void> _wait() => Future<void>.delayed(latency);

  int _indexOf(String id) {
    for (int i = 0; i < _orders.length; i++) {
      if (_orders[i].id == id) return i;
    }
    return -1;
  }

  PurchaseOrder _require(String id) {
    final int index = _indexOf(id);
    if (index == -1) throw StateError('Commande introuvable : $id');
    return _orders[index];
  }

  @override
  Future<List<PurchaseOrder>> fetchOrders() async {
    await _wait();
    return List<PurchaseOrder>.unmodifiable(_orders);
  }

  @override
  Future<PurchaseOrder?> fetchOrder(String id) async {
    await _wait();
    final int index = _indexOf(id);
    return index == -1 ? null : _orders[index];
  }

  @override
  Future<PurchaseOrder> createOrder({
    required Supplier supplier,
    required List<OrderLine> lines,
    required String createdBy,
    DateTime? expectedAt,
    String? notes,
  }) async {
    await _wait();

    final int number = _sequence++;
    final DateTime now = DateTime.now();
    final PurchaseOrder order = PurchaseOrder(
      id: 'ord-${number.toString().padLeft(3, '0')}',
      reference: 'CMD-${number.toString().padLeft(3, '0')}',
      supplierId: supplier.id,
      supplierName: supplier.name,
      createdAt: now,
      expectedAt:
          expectedAt ?? now.add(Duration(days: supplier.deliveryDays)),
      lifecycle: OrderLifecycle.ouverte,
      lines: lines,
      createdBy: createdBy,
      notes: notes,
    );

    _orders.insert(0, order);
    return order;
  }

  @override
  Future<PurchaseOrder> saveLines({
    required String orderId,
    required List<OrderLine> lines,
  }) async {
    await _wait();
    final PurchaseOrder order = _require(orderId);
    if (!order.isEditable) {
      throw StateError(
        'La commande ${order.reference} a déjà reçu de la marchandise : '
        'ses lignes ne peuvent plus être modifiées.',
      );
    }
    final PurchaseOrder updated = order.copyWith(lines: lines);
    _orders[_indexOf(orderId)] = updated;
    return updated;
  }

  @override
  Future<PurchaseOrder> saveReceivedQuantities({
    required String orderId,
    required Map<String, double> quantitiesByProductId,
  }) async {
    // Pas de latence : la réception est déjà passée par le module Stock,
    // cette écriture ne doit pas rallonger l'attente de l'utilisateur.
    final PurchaseOrder order = _require(orderId);

    final List<OrderLine> lines = order.lines.map((OrderLine line) {
      final double? quantity = quantitiesByProductId[line.productId];
      return quantity == null
          ? line
          : line.copyWith(quantityReceived: quantity);
    }).toList();

    final PurchaseOrder updated = order.copyWith(lines: lines);
    _orders[_indexOf(orderId)] = updated;
    return updated;
  }

  @override
  Future<PurchaseOrder> updateLifecycle({
    required String orderId,
    required OrderLifecycle lifecycle,
  }) async {
    await _wait();
    final PurchaseOrder order = _require(orderId);
    final bool closing = lifecycle == OrderLifecycle.annulee ||
        lifecycle == OrderLifecycle.soldee;
    final PurchaseOrder updated = order.copyWith(
      lifecycle: lifecycle,
      closedAt: closing ? DateTime.now() : null,
    );
    _orders[_indexOf(orderId)] = updated;
    return updated;
  }

  @override
  Future<void> deleteOrder(String id) async {
    await _wait();
    _orders.removeWhere((PurchaseOrder o) => o.id == id);
  }
}
