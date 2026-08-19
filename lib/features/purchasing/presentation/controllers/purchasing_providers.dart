import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../stock/presentation/controllers/stock_providers.dart';
import '../../data/repositories/in_memory_purchasing_repositories.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/purchasing_repositories.dart';
import '../../domain/usecases/apply_supplier_prices.dart';
import '../../domain/usecases/build_shopping_list.dart';
import '../../domain/usecases/receive_order.dart';

/// Sources de données du module. Seuls points de branchement du backend.
final Provider<SupplierRepository> supplierRepositoryProvider =
    Provider<SupplierRepository>((Ref ref) => InMemorySupplierRepository());

final Provider<PurchaseOrderRepository> purchaseOrderRepositoryProvider =
    Provider<PurchaseOrderRepository>(
  (Ref ref) => InMemoryPurchaseOrderRepository(),
);

/// Les cas d'usage qui font dialoguer Achats et Stock.
final Provider<ReceiveOrder> receiveOrderProvider = Provider<ReceiveOrder>(
  (Ref ref) => ReceiveOrder(
    orders: ref.watch(purchaseOrderRepositoryProvider),
    products: ref.watch(productRepositoryProvider),
  ),
);

final Provider<ApplySupplierPrices> applySupplierPricesProvider =
    Provider<ApplySupplierPrices>(
  (Ref ref) => ApplySupplierPrices(
    products: ref.watch(productRepositoryProvider),
  ),
);

final Provider<BuildShoppingList> buildShoppingListProvider =
    Provider<BuildShoppingList>(
  (Ref ref) => BuildShoppingList(
    products: ref.watch(productRepositoryProvider),
    orders: ref.watch(purchaseOrderRepositoryProvider),
    suppliers: ref.watch(supplierRepositoryProvider),
  ),
);

// ---------------------------------------------------------------------------
// Fournisseurs
// ---------------------------------------------------------------------------

class SupplierController extends StateNotifier<AsyncValue<List<Supplier>>> {
  SupplierController(Ref ref)
      : _repository = ref.read(supplierRepositoryProvider),
        super(const AsyncValue<List<Supplier>>.loading()) {
    load();
  }

  final SupplierRepository _repository;

  Future<void> load() async {
    state = const AsyncValue<List<Supplier>>.loading();
    state = await AsyncValue.guard(() => _repository.fetchSuppliers());
  }

  Future<void> save(Supplier supplier) async {
    await _repository.saveSupplier(supplier);
    await load();
  }

  Future<void> delete(String supplierId) async {
    await _repository.deleteSupplier(supplierId);
    await load();
  }

  /// Identifiant à attribuer à un fournisseur créé depuis l'interface.
  String nextSupplierId() {
    final SupplierRepository repository = _repository;
    return repository is InMemorySupplierRepository
        ? repository.newSupplierId()
        : DateTime.now().microsecondsSinceEpoch.toString();
  }
}

final StateNotifierProvider<SupplierController, AsyncValue<List<Supplier>>>
    supplierControllerProvider =
    StateNotifierProvider<SupplierController, AsyncValue<List<Supplier>>>(
  SupplierController.new,
);

/// Fournisseurs proposables pour une nouvelle commande.
final Provider<List<Supplier>> activeSuppliersProvider =
    Provider<List<Supplier>>((Ref ref) {
  final List<Supplier> all =
      ref.watch(supplierControllerProvider).valueOrNull ?? const <Supplier>[];
  return all.where((Supplier s) => s.isActive).toList()
    ..sort((Supplier a, Supplier b) => a.name.compareTo(b.name));
});

/// Nombre de commandes par fournisseur, pour le tableau des fournisseurs.
final Provider<Map<String, int>> orderCountBySupplierProvider =
    Provider<Map<String, int>>((Ref ref) {
  final List<PurchaseOrder> orders =
      ref.watch(orderControllerProvider).valueOrNull ??
          const <PurchaseOrder>[];
  final Map<String, int> counts = <String, int>{};
  for (final PurchaseOrder order in orders) {
    counts[order.supplierId] = (counts[order.supplierId] ?? 0) + 1;
  }
  return counts;
});

// ---------------------------------------------------------------------------
// Commandes
// ---------------------------------------------------------------------------

class OrderController extends StateNotifier<AsyncValue<List<PurchaseOrder>>> {
  OrderController(this._ref)
      : _repository = _ref.read(purchaseOrderRepositoryProvider),
        super(const AsyncValue<List<PurchaseOrder>>.loading()) {
    load();
  }

  final Ref _ref;
  final PurchaseOrderRepository _repository;

  Future<void> load() async {
    state = const AsyncValue<List<PurchaseOrder>>.loading();
    state = await AsyncValue.guard(() => _repository.fetchOrders());
  }

  Future<PurchaseOrder> create({
    required Supplier supplier,
    required List<OrderLine> lines,
    required String createdBy,
    String? notes,
  }) async {
    final PurchaseOrder created = await _repository.createOrder(
      supplier: supplier,
      lines: lines,
      createdBy: createdBy,
      notes: notes,
    );
    await load();
    _ref.read(selectedOrderIdProvider.notifier).state = created.id;
    return created;
  }

  Future<void> saveLines(String orderId, List<OrderLine> lines) async {
    final PurchaseOrder updated =
        await _repository.saveLines(orderId: orderId, lines: lines);
    _replace(updated);
  }

  /// Enregistre une réception : le stock est mis à jour, la commande aussi.
  Future<OrderReceptionResult> receive(
    PurchaseOrder order, {
    required Map<String, double> receivedQuantities,
    required String receivedBy,
  }) async {
    final OrderReceptionResult result = await _ref.read(receiveOrderProvider)(
      order,
      receivedQuantities: receivedQuantities,
      receivedBy: receivedBy,
    );
    _replace(result.order);

    // Le stock des produits reçus a changé, et leur historique de mouvements
    // vient de gagner une ligne : c'est au module Stock de rafraîchir ce
    // qu'il faut, on lui dit seulement quels produits. Même contrat que la
    // validation d'un inventaire.
    await _ref
        .read(stockControllerProvider.notifier)
        .refreshProducts(result.touchedProductIds);
    return result;
  }

  /// Applique les tarifs constatés à la réception, une fois l'utilisateur
  /// d'accord.
  ///
  /// Volontairement séparé de [receive] : recevoir de la marchandise est un
  /// fait, apprendre un tarif est une décision.
  Future<void> applySupplierPrices(
    Iterable<SupplierPriceDiscrepancy> discrepancies,
  ) async {
    if (discrepancies.isEmpty) return;
    final List<String> updated =
        await _ref.read(applySupplierPricesProvider)(discrepancies);
    await _ref
        .read(stockControllerProvider.notifier)
        .refreshProducts(updated);
  }

  /// Annule une commande dont rien n'est encore arrivé.
  Future<void> cancel(String orderId) async {
    final PurchaseOrder updated = await _repository.updateLifecycle(
      orderId: orderId,
      lifecycle: OrderLifecycle.annulee,
    );
    _replace(updated);
  }

  /// Solde une commande partiellement livrée : le reliquat est abandonné.
  Future<void> close(String orderId) async {
    final PurchaseOrder updated = await _repository.updateLifecycle(
      orderId: orderId,
      lifecycle: OrderLifecycle.soldee,
    );
    _replace(updated);
  }

  Future<void> delete(String orderId) async {
    await _repository.deleteOrder(orderId);
    if (_ref.read(selectedOrderIdProvider) == orderId) {
      _ref.read(selectedOrderIdProvider.notifier).state = null;
    }
    await load();
  }

  void _replace(PurchaseOrder updated) {
    final List<PurchaseOrder>? current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<List<PurchaseOrder>>.data(
      current
          .map((PurchaseOrder o) => o.id == updated.id ? updated : o)
          .toList(),
    );
  }
}

final StateNotifierProvider<OrderController, AsyncValue<List<PurchaseOrder>>>
    orderControllerProvider =
    StateNotifierProvider<OrderController, AsyncValue<List<PurchaseOrder>>>(
  OrderController.new,
);

// ---------------------------------------------------------------------------
// Recherche et filtres
// ---------------------------------------------------------------------------

/// Onglets de la liste des commandes, repris de la maquette.
enum OrderFilter {
  toutes,
  enCours,
  partielles,
  recues;

  String get label => switch (this) {
        OrderFilter.toutes => 'Toutes',
        OrderFilter.enCours => 'En cours',
        OrderFilter.partielles => 'Partielles',
        OrderFilter.recues => 'Reçues',
      };

  bool matches(OrderStatus status) => switch (this) {
        OrderFilter.toutes => true,
        OrderFilter.enCours =>
          status == OrderStatus.enCours || status == OrderStatus.brouillon,
        OrderFilter.partielles => status == OrderStatus.partielle,
        OrderFilter.recues =>
          status == OrderStatus.recue || status == OrderStatus.soldee,
      };
}

class OrderQuery {
  const OrderQuery({this.search = '', this.filter = OrderFilter.toutes});

  final String search;
  final OrderFilter filter;

  OrderQuery copyWith({String? search, OrderFilter? filter}) => OrderQuery(
        search: search ?? this.search,
        filter: filter ?? this.filter,
      );

  List<PurchaseOrder> apply(List<PurchaseOrder> orders) {
    final String needle = search.trim().toLowerCase();

    return orders.where((PurchaseOrder o) {
      if (!filter.matches(o.status)) return false;
      if (needle.isEmpty) return true;
      return o.reference.toLowerCase().contains(needle) ||
          o.supplierName.toLowerCase().contains(needle) ||
          o.lines.any(
            (OrderLine l) => l.productName.toLowerCase().contains(needle),
          );
    }).toList()
      ..sort(
        (PurchaseOrder a, PurchaseOrder b) =>
            b.createdAt.compareTo(a.createdAt),
      );
  }
}

class OrderQueryController extends StateNotifier<OrderQuery> {
  OrderQueryController() : super(const OrderQuery());

  void setSearch(String value) => state = state.copyWith(search: value);
  void setFilter(OrderFilter filter) => state = state.copyWith(filter: filter);
}

final StateNotifierProvider<OrderQueryController, OrderQuery>
    orderQueryProvider =
    StateNotifierProvider<OrderQueryController, OrderQuery>(
  (Ref ref) => OrderQueryController(),
);

final Provider<AsyncValue<List<PurchaseOrder>>> visibleOrdersProvider =
    Provider<AsyncValue<List<PurchaseOrder>>>((Ref ref) {
  final OrderQuery query = ref.watch(orderQueryProvider);
  return ref
      .watch(orderControllerProvider)
      .whenData((List<PurchaseOrder> list) => query.apply(list));
});

final Provider<Map<OrderFilter, int>> orderCountersProvider =
    Provider<Map<OrderFilter, int>>((Ref ref) {
  final List<PurchaseOrder> all =
      ref.watch(orderControllerProvider).valueOrNull ??
          const <PurchaseOrder>[];
  return <OrderFilter, int>{
    for (final OrderFilter f in OrderFilter.values)
      f: all.where((PurchaseOrder o) => f.matches(o.status)).length,
  };
});

// ---------------------------------------------------------------------------
// Liste de courses
// ---------------------------------------------------------------------------

/// Un groupe de la liste de courses : les produits d'un même fournisseur.
class ShoppingGroup {
  const ShoppingGroup({
    required this.supplierId,
    required this.supplierName,
    required this.items,
  });

  /// `null` = produits sans fournisseur, qui ne peuvent pas être commandés.
  final String? supplierId;
  final String supplierName;
  final List<ShoppingItem> items;

  bool get canOrder => supplierId != null;

  List<ShoppingItem> get selectedItems =>
      items.where((ShoppingItem i) => i.isSelected).toList();

  double get total => selectedItems.fold<double>(
        0,
        (double sum, ShoppingItem i) => sum + i.total,
      );
}

/// Détient la liste de courses et les arbitrages faits avant génération.
///
/// Tout se passe en mémoire : changer une quantité ou un fournisseur ne
/// touche ni au catalogue ni aux commandes. Rien n'est écrit avant
/// [generateOrders].
class ShoppingListController extends StateNotifier<AsyncValue<ShoppingList>> {
  ShoppingListController(this._ref)
      : super(const AsyncValue<ShoppingList>.loading()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue<ShoppingList>.loading();
    state = await AsyncValue.guard(
      () => _ref.read(buildShoppingListProvider)(),
    );
  }

  void _update(ShoppingItem updated) {
    final ShoppingList? current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<ShoppingList>.data(current.replaceItem(updated));
  }

  ShoppingItem? _itemOf(String productId) {
    final ShoppingList? current = state.valueOrNull;
    if (current == null) return null;
    for (final ShoppingItem item in current.items) {
      if (item.productId == productId) return item;
    }
    return null;
  }

  void setQuantity(String productId, double quantity) {
    final ShoppingItem? item = _itemOf(productId);
    if (item == null) return;
    _update(item.copyWith(quantity: quantity < 0 ? 0 : quantity));
  }

  void setSelected(String productId, bool selected) {
    final ShoppingItem? item = _itemOf(productId);
    if (item == null) return;
    _update(item.copyWith(isSelected: selected));
  }

  void selectAll(bool selected) {
    final ShoppingList? current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<ShoppingList>.data(current.withSelection(selected));
  }

  /// Bascule une ligne vers un autre fournisseur, et reprend son prix.
  void setSupplier(String productId, String supplierId) {
    final ShoppingItem? item = _itemOf(productId);
    if (item == null) return;

    for (final SupplierOption option in item.supplierOptions) {
      if (option.id != supplierId) continue;
      _update(
        item.copyWith(
          supplierId: option.id,
          supplierName: option.name,
          unitPrice: option.unitPrice,
        ),
      );
      return;
    }
  }

  /// Crée une commande par fournisseur, à partir des lignes cochées.
  ///
  /// Renvoie les commandes créées. La liste de courses est ensuite
  /// recalculée : les produits couverts par ces nouvelles commandes en
  /// sortent d'eux-mêmes, puisque la quantité en attente est déduite du
  /// besoin.
  Future<List<PurchaseOrder>> generateOrders({
    required String createdBy,
    String? onlySupplierId,
  }) async {
    final ShoppingList? current = state.valueOrNull;
    if (current == null) return const <PurchaseOrder>[];

    final List<Supplier> suppliers =
        await _ref.read(supplierRepositoryProvider).fetchSuppliers();

    final Map<String, List<ShoppingItem>> bySupplier =
        <String, List<ShoppingItem>>{};
    for (final ShoppingItem item in current.selectedItems) {
      if (onlySupplierId != null && item.supplierId != onlySupplierId) {
        continue;
      }
      bySupplier.putIfAbsent(item.supplierId!, () => <ShoppingItem>[])
          .add(item);
    }

    final List<PurchaseOrder> created = <PurchaseOrder>[];
    final PurchaseOrderRepository repository =
        _ref.read(purchaseOrderRepositoryProvider);

    for (final MapEntry<String, List<ShoppingItem>> entry
        in bySupplier.entries) {
      final Supplier supplier = suppliers.firstWhere(
        (Supplier s) => s.id == entry.key,
      );

      created.add(
        await repository.createOrder(
          supplier: supplier,
          createdBy: createdBy,
          lines: entry.value
              .map(
                (ShoppingItem i) => OrderLine(
                  productId: i.productId,
                  productName: i.productName,
                  emoji: i.emoji,
                  unit: i.unit,
                  quantityOrdered: i.quantity,
                  unitPrice: i.unitPrice,
                ),
              )
              .toList(),
        ),
      );
    }

    if (created.isNotEmpty) {
      await _ref.read(orderControllerProvider.notifier).load();
      await load();
    }
    return created;
  }
}

final StateNotifierProvider<ShoppingListController, AsyncValue<ShoppingList>>
    shoppingListControllerProvider = StateNotifierProvider<
        ShoppingListController, AsyncValue<ShoppingList>>(
  ShoppingListController.new,
);

/// Liste de courses regroupée par fournisseur, prête à afficher.
final Provider<List<ShoppingGroup>> shoppingGroupsProvider =
    Provider<List<ShoppingGroup>>((Ref ref) {
  final ShoppingList? list = ref.watch(shoppingListControllerProvider).valueOrNull;
  if (list == null) return const <ShoppingGroup>[];

  final Map<String?, List<ShoppingItem>> grouped =
      <String?, List<ShoppingItem>>{};
  for (final ShoppingItem item in list.items) {
    grouped.putIfAbsent(item.supplierId, () => <ShoppingItem>[]).add(item);
  }

  final List<ShoppingGroup> groups = grouped.entries
      .map(
        (MapEntry<String?, List<ShoppingItem>> e) => ShoppingGroup(
          supplierId: e.key,
          supplierName: e.key == null
              ? 'Sans fournisseur'
              : (e.value.first.supplierName ?? 'Fournisseur'),
          items: e.value,
        ),
      )
      .toList()
    ..sort((ShoppingGroup a, ShoppingGroup b) {
      // Le groupe sans fournisseur en dernier : rien n'y est actionnable.
      if (a.supplierId == null) return 1;
      if (b.supplierId == null) return -1;
      return a.supplierName.compareTo(b.supplierName);
    });

  return groups;
});

// ---------------------------------------------------------------------------
// Sélection et navigation interne
// ---------------------------------------------------------------------------

/// Sections du module Achats.
enum PurchasingSection {
  aCommander,
  commandes,
  fournisseurs;

  String get label => switch (this) {
        PurchasingSection.aCommander => 'À commander',
        PurchasingSection.commandes => 'Commandes',
        PurchasingSection.fournisseurs => 'Fournisseurs',
      };
}

final StateProvider<PurchasingSection> purchasingSectionProvider =
    StateProvider<PurchasingSection>((Ref ref) => PurchasingSection.commandes);

/// Commande ouverte dans le panneau de détail. `null` = aucune.
final StateProvider<String?> selectedOrderIdProvider =
    StateProvider<String?>((Ref ref) => null);

final Provider<PurchaseOrder?> selectedOrderProvider =
    Provider<PurchaseOrder?>((Ref ref) {
  final String? id = ref.watch(selectedOrderIdProvider);
  if (id == null) return null;
  final List<PurchaseOrder> all =
      ref.watch(orderControllerProvider).valueOrNull ??
          const <PurchaseOrder>[];
  for (final PurchaseOrder order in all) {
    if (order.id == id) return order;
  }
  return null;
});
