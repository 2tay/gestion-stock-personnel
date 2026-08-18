import '../../../../core/constants/app_enums.dart';

/// Un fournisseur possible pour un produit, avec son prix.
///
/// Reprise allégée de `ProductSupplier` (module Stock) : la liste de courses
/// n'a besoin que de quoi proposer un choix et un prix.
class SupplierOption {
  const SupplierOption({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final double unitPrice;
  final bool isPrimary;
}

/// Une ligne de la liste de courses : un produit à réapprovisionner.
///
/// Ce n'est pas un produit, c'est une **proposition de commande** : la
/// quantité et le fournisseur y sont modifiables avant génération, sans que
/// cela touche au catalogue.
class ShoppingItem {
  const ShoppingItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    required this.maxStock,
    required this.status,
    required this.quantity,
    required this.unitPrice,
    required this.supplierOptions,
    this.emoji = '📦',
    this.pendingQuantity = 0,
    this.supplierId,
    this.supplierName,
    this.isSelected = true,
  });

  final String productId;
  final String productName;
  final String emoji;
  final String unit;

  final double currentStock;
  final double minStock;
  final double maxStock;
  final StockStatus status;

  /// Quantité déjà commandée et pas encore livrée, toutes commandes ouvertes
  /// confondues. Elle est déduite du besoin : inutile de recommander ce qui
  /// est déjà en route.
  final double pendingQuantity;

  /// Quantité proposée, modifiable avant génération.
  final double quantity;

  /// Prix unitaire du fournisseur retenu.
  final double unitPrice;

  /// Fournisseur retenu. `null` si le produit n'en a aucun : la ligne est
  /// alors affichée mais ne peut pas être commandée.
  final String? supplierId;
  final String? supplierName;

  final List<SupplierOption> supplierOptions;

  /// Décochée, la ligne n'entre pas dans la commande générée.
  final bool isSelected;

  double get total => quantity * unitPrice;

  bool get canOrder => supplierId != null && quantity > 0;

  /// Le produit a-t-il d'autres fournisseurs que celui retenu ?
  bool get hasAlternatives => supplierOptions.length > 1;

  ShoppingItem copyWith({
    double? quantity,
    double? unitPrice,
    String? supplierId,
    String? supplierName,
    bool? isSelected,
  }) {
    return ShoppingItem(
      productId: productId,
      productName: productName,
      emoji: emoji,
      unit: unit,
      currentStock: currentStock,
      minStock: minStock,
      maxStock: maxStock,
      status: status,
      pendingQuantity: pendingQuantity,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierOptions: supplierOptions,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Résultat du calcul de la liste de courses.
class ShoppingList {
  const ShoppingList({
    required this.items,
    required this.coveredByPendingOrders,
  });

  static const ShoppingList empty = ShoppingList(
    items: <ShoppingItem>[],
    coveredByPendingOrders: 0,
  );

  final List<ShoppingItem> items;

  /// Produits sous leur seuil mais dont le manque est déjà couvert par une
  /// commande en cours. Ils sont retirés de la liste — les compter permet de
  /// l'expliquer à l'utilisateur plutôt que de les faire disparaître sans
  /// raison apparente.
  final int coveredByPendingOrders;

  bool get isEmpty => items.isEmpty;

  List<ShoppingItem> get selectedItems =>
      items.where((ShoppingItem i) => i.isSelected && i.canOrder).toList();

  double get selectedTotal => selectedItems.fold<double>(
        0,
        (double sum, ShoppingItem i) => sum + i.total,
      );

  int get outOfStockCount =>
      items.where((ShoppingItem i) => i.status == StockStatus.rupture).length;

  /// Lignes sans fournisseur : impossible d'en faire une commande.
  int get withoutSupplierCount =>
      items.where((ShoppingItem i) => i.supplierId == null).length;

  ShoppingList replaceItem(ShoppingItem updated) {
    return ShoppingList(
      items: items
          .map(
            (ShoppingItem i) =>
                i.productId == updated.productId ? updated : i,
          )
          .toList(),
      coveredByPendingOrders: coveredByPendingOrders,
    );
  }

  ShoppingList withSelection(bool selected) {
    return ShoppingList(
      items: items
          .map((ShoppingItem i) => i.copyWith(isSelected: selected))
          .toList(),
      coveredByPendingOrders: coveredByPendingOrders,
    );
  }
}
