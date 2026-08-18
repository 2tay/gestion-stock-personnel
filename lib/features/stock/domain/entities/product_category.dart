/// Catégorie de produits : Légumes, Épicerie, Produits frais, Boissons…
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.emoji = '📦',
  });

  final String id;
  final String name;

  /// Pictogramme affiché dans la vue par catégorie. Un emoji plutôt qu'une
  /// image : rien à télécharger, l'application reste utilisable hors ligne.
  final String emoji;

  @override
  bool operator ==(Object other) => other is ProductCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
