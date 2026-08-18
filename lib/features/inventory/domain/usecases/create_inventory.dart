import '../../../stock/domain/entities/product.dart';
import '../../../stock/domain/repositories/product_repository.dart';
import '../entities/inventory.dart';
import '../entities/inventory_line.dart';
import '../repositories/inventory_repository.dart';

/// Ouvre un inventaire en photographiant le stock des produits concernés.
///
/// C'est ici que se joue la règle la plus importante du module : le stock
/// théorique est **figé** à l'ouverture. Il ne sera jamais relu ensuite, même
/// si le stock réel bouge pendant le comptage.
///
/// Ce cas d'usage a besoin des deux modules : il lit les produits (Stock) et
/// écrit un inventaire (Inventaire). C'est la raison pour laquelle il vit
/// dans `usecases/` et non dans un dépôt.
class CreateInventory {
  const CreateInventory({
    required InventoryRepository inventories,
    required ProductRepository products,
  })  : _inventories = inventories,
        _products = products;

  final InventoryRepository _inventories;
  final ProductRepository _products;

  /// Crée l'inventaire et renvoie l'objet prêt à être compté.
  ///
  /// [categoryId] n'est utilisé que si [scope] vaut
  /// [InventoryScope.categorie].
  Future<Inventory> call({
    required InventoryScope scope,
    required String createdBy,
    String? categoryId,
    String? categoryName,
  }) async {
    final List<Product> allProducts = await _products.fetchProducts();

    final List<Product> inScope = scope == InventoryScope.categorie
        ? allProducts
            .where((Product p) => p.categoryId == categoryId)
            .toList()
        : allProducts;

    final List<InventoryLine> lines = inScope
        .map(
          (Product p) => InventoryLine(
            productId: p.id,
            productName: p.name,
            emoji: p.emoji,
            categoryName: p.categoryName,
            unit: p.unit,
            barcode: p.barcode,
            // La photo : ces deux valeurs ne bougeront plus.
            theoreticalStock: p.currentStock,
            unitPrice: p.unitPrice,
          ),
        )
        .toList()
      ..sort(
        (InventoryLine a, InventoryLine b) =>
            a.productName.compareTo(b.productName),
      );

    return _inventories.createInventory(
      scope: scope,
      lines: lines,
      createdBy: createdBy,
      categoryId: scope == InventoryScope.categorie ? categoryId : null,
      categoryName: scope == InventoryScope.categorie ? categoryName : null,
    );
  }
}
