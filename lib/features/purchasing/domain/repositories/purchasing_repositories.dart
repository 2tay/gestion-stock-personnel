import '../entities/purchase_order.dart';
import '../entities/supplier.dart';

/// Contrat d'accès aux fournisseurs.
abstract interface class SupplierRepository {
  Future<List<Supplier>> fetchSuppliers();

  Future<Supplier?> fetchSupplier(String id);

  /// Crée le fournisseur s'il est inconnu, le met à jour sinon.
  Future<Supplier> saveSupplier(Supplier supplier);

  Future<void> deleteSupplier(String id);
}

/// Contrat d'accès aux commandes fournisseurs.
///
/// Ce dépôt ne touche jamais au stock. La réception, qui écrit des mouvements
/// dans le module Stock, passe par `ReceiveOrder` — même principe que la
/// validation d'inventaire.
abstract interface class PurchaseOrderRepository {
  Future<List<PurchaseOrder>> fetchOrders();

  Future<PurchaseOrder?> fetchOrder(String id);

  Future<PurchaseOrder> createOrder({
    required Supplier supplier,
    required List<OrderLine> lines,
    required String createdBy,
    DateTime? expectedAt,
    String? notes,
  });

  /// Remplace les lignes d'une commande encore modifiable.
  Future<PurchaseOrder> saveLines({
    required String orderId,
    required List<OrderLine> lines,
  });

  /// Enregistre les quantités **cumulées** reçues, par produit.
  ///
  /// Appelé par `ReceiveOrder` après que les mouvements de stock ont été
  /// écrits, jamais directement par l'interface.
  Future<PurchaseOrder> saveReceivedQuantities({
    required String orderId,
    required Map<String, double> quantitiesByProductId,
  });

  Future<PurchaseOrder> updateLifecycle({
    required String orderId,
    required OrderLifecycle lifecycle,
  });

  Future<void> deleteOrder(String id);
}
