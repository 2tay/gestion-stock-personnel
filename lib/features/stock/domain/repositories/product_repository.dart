import '../../../../core/constants/app_enums.dart';
import '../entities/measurement_unit.dart';
import '../entities/product.dart';
import '../entities/product_category.dart';
import '../entities/stock_movement.dart';

/// Contrat d'accès aux données du module Stock.
///
/// La couche présentation ne connaît que cette interface. En phase frontend,
/// elle est satisfaite par une implémentation en mémoire ; le passage à
/// l'API puis à la base locale ne changera que `data/repositories/`.
abstract interface class ProductRepository {
  Future<List<Product>> fetchProducts();

  Future<Product?> fetchProduct(String id);

  /// Recherche par code-barres, utilisée par le scanner.
  Future<Product?> findByBarcode(String barcode);

  /// Crée le produit s'il est inconnu, le met à jour sinon.
  Future<Product> saveProduct(Product product);

  Future<void> deleteProduct(String id);

  Future<List<ProductCategory>> fetchCategories();

  Future<List<MeasurementUnit>> fetchUnits();

  /// Historique des mouvements d'un produit, du plus récent au plus ancien.
  Future<List<StockMovement>> fetchMovements(String productId);

  /// Enregistre une entrée, une sortie ou un ajustement et met à jour le
  /// stock du produit concerné.
  Future<Product> registerMovement(StockMovement movement);

  /// Ajoute un tarif à l'historique d'un fournisseur pour ce produit.
  ///
  /// **Ajoute** : le tarif précédent est conservé, jamais remplacé. Un prix
  /// identique au tarif en vigueur ne crée aucune ligne.
  Future<Product> recordSupplierPrice({
    required String productId,
    required String supplierId,
    required double unitPrice,
    DateTime? validFrom,
    PriceSource source,
    String? note,
  });
}
