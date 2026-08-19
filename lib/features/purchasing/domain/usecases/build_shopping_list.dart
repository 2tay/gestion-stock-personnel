import '../../../../core/constants/app_enums.dart';
import '../../../stock/domain/entities/product.dart';
import '../../../stock/domain/repositories/product_repository.dart';
import '../entities/purchase_order.dart';
import '../entities/shopping_item.dart';
import '../entities/supplier.dart';
import '../repositories/purchasing_repositories.dart';

/// Construit la liste des produits à commander.
///
/// Troisième cas d'usage inter-modules du projet, et le premier à croiser
/// trois sources : les produits (Stock), les commandes en cours (Achats) et
/// les fournisseurs (Achats).
///
/// Trois règles :
///
/// 1. **On part du seuil, pas du vide.** Un produit est à commander dès qu'il
///    passe sous son stock minimum, et la quantité proposée est celle qui le
///    ramène à son stock maximum — `Product.quantityToOrder`, calculé par le
///    module Stock depuis la phase 4.
/// 2. **Ce qui est déjà en route ne se recommande pas.** Les quantités
///    commandées et pas encore livrées sont déduites du besoin. Sans cela, on
///    recommanderait chaque jour les mêmes produits tant que la livraison
///    n'est pas arrivée.
/// 3. **Le fournisseur principal est une proposition, pas une contrainte.**
///    Il est retenu par défaut, mais toutes les alternatives connues du
///    produit sont fournies pour que l'utilisateur puisse basculer une ligne.
class BuildShoppingList {
  const BuildShoppingList({
    required ProductRepository products,
    required PurchaseOrderRepository orders,
    required SupplierRepository suppliers,
  })  : _products = products,
        _orders = orders,
        _suppliers = suppliers;

  final ProductRepository _products;
  final PurchaseOrderRepository _orders;
  final SupplierRepository _suppliers;

  Future<ShoppingList> call() async {
    final List<Product> products = await _products.fetchProducts();
    final List<PurchaseOrder> orders = await _orders.fetchOrders();
    final List<Supplier> suppliers = await _suppliers.fetchSuppliers();

    final Map<String, double> pending = _pendingQuantities(orders);
    final Map<String, Supplier> byId = <String, Supplier>{
      for (final Supplier s in suppliers) s.id: s,
    };

    final List<ShoppingItem> items = <ShoppingItem>[];
    int covered = 0;

    for (final Product product in products) {
      if (product.status == StockStatus.ok) continue;

      final double onOrder = pending[product.id] ?? 0;
      final double need = product.quantityToOrder - onOrder;

      // Le manque est déjà couvert par une commande en cours.
      if (need <= 0) {
        covered++;
        continue;
      }

      final List<SupplierOption> options = product.suppliers
          .map(
            (ProductSupplier s) => SupplierOption(
              id: s.id,
              // Le nom du fournisseur fait foi s'il est connu : la copie
              // portée par le produit peut avoir vieilli.
              name: byId[s.id]?.name ?? s.name,
              unitPrice: s.unitPrice,
              isPrimary: s.isPrimary,
            ),
          )
          .toList();

      final ProductSupplier? primary = product.primarySupplier;

      items.add(
        ShoppingItem(
          productId: product.id,
          productName: product.name,
          emoji: product.emoji,
          unit: product.unit,
          currentStock: product.currentStock,
          minStock: product.minStock,
          maxStock: product.maxStock,
          status: product.status,
          pendingQuantity: onOrder,
          quantity: need,
          // À défaut de tarif fournisseur, le coût moyen est la moins
          // mauvaise estimation disponible.
          unitPrice: primary?.unitPrice ?? product.averageCost,
          supplierId: primary?.id,
          supplierName:
              primary == null ? null : (byId[primary.id]?.name ?? primary.name),
          supplierOptions: options,
        ),
      );
    }

    // Les ruptures d'abord : ce sont elles qui bloquent le service.
    items.sort((ShoppingItem a, ShoppingItem b) {
      if (a.status != b.status) {
        return a.status == StockStatus.rupture ? -1 : 1;
      }
      return a.productName.compareTo(b.productName);
    });

    return ShoppingList(items: items, coveredByPendingOrders: covered);
  }

  /// Quantités commandées et pas encore livrées, par produit.
  ///
  /// Seules les commandes ouvertes comptent : une commande annulée ou soldée
  /// n'apportera plus rien.
  Map<String, double> _pendingQuantities(List<PurchaseOrder> orders) {
    final Map<String, double> pending = <String, double>{};
    for (final PurchaseOrder order in orders) {
      if (!order.isReceivable) continue;
      for (final OrderLine line in order.lines) {
        if (line.remaining <= 0) continue;
        pending[line.productId] =
            (pending[line.productId] ?? 0) + line.remaining;
      }
    }
    return pending;
  }
}
