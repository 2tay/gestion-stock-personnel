import '../../../../core/constants/app_enums.dart';

/// Fournisseur associé à un produit, avec son prix et sa référence.
///
/// Volontairement local au module Stock : la fiche fournisseur complète
/// appartiendra au module Achats (phase 6). Ce qui compte ici, c'est ce que
/// l'onglet « Fournisseurs » de la fiche produit doit afficher.
class ProductSupplier {
  const ProductSupplier({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.reference,
    this.isPrimary = false,
    this.deliveryDays = 1,
  });

  final String id;
  final String name;

  /// Prix d'achat unitaire, dans l'unité du produit.
  final double unitPrice;

  /// Référence du produit chez ce fournisseur.
  final String? reference;

  /// Fournisseur principal : celui proposé par défaut à la commande.
  final bool isPrimary;

  /// Délai de livraison indicatif, en jours.
  final int deliveryDays;
}

/// Produit géré en stock.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    required this.maxStock,
    required this.unitPrice,
    this.emoji = '📦',
    this.barcode,
    this.suppliers = const <ProductSupplier>[],
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String categoryId;

  /// Nom de catégorie dénormalisé : évite une jointure pour afficher le
  /// tableau, qui est la vue la plus fréquente.
  final String categoryName;

  /// Code de l'unité (`kg`, `un.`…).
  final String unit;

  final double currentStock;

  /// Seuil d'alerte : en dessous, le produit est signalé comme faible.
  final double minStock;

  /// Stock cible, utilisé pour calculer la quantité à commander.
  final double maxStock;

  /// Dernier prix d'achat unitaire, base du calcul de la valeur du stock.
  final double unitPrice;

  final String emoji;
  final String? barcode;
  final List<ProductSupplier> suppliers;
  final String? notes;
  final DateTime? updatedAt;

  /// Statut affiché par le badge de la liste.
  StockStatus get status {
    if (currentStock <= 0) return StockStatus.rupture;
    if (currentStock <= minStock) return StockStatus.faible;
    return StockStatus.ok;
  }

  /// Valeur du stock détenu pour ce produit.
  double get stockValue => currentStock * unitPrice;

  /// Quantité à commander pour revenir au stock maximum.
  double get quantityToOrder {
    final double missing = maxStock - currentStock;
    return missing > 0 ? missing : 0;
  }

  /// Position du stock entre 0 et 1 par rapport au maximum, pour la jauge.
  double get fillRatio {
    if (maxStock <= 0) return 0;
    final double ratio = currentStock / maxStock;
    return ratio.clamp(0, 1).toDouble();
  }

  ProductSupplier? get primarySupplier {
    for (final ProductSupplier s in suppliers) {
      if (s.isPrimary) return s;
    }
    return suppliers.isEmpty ? null : suppliers.first;
  }

  Product copyWith({
    String? name,
    String? categoryId,
    String? categoryName,
    String? unit,
    double? currentStock,
    double? minStock,
    double? maxStock,
    double? unitPrice,
    String? emoji,
    String? barcode,
    List<ProductSupplier>? suppliers,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      unitPrice: unitPrice ?? this.unitPrice,
      emoji: emoji ?? this.emoji,
      barcode: barcode ?? this.barcode,
      suppliers: suppliers ?? this.suppliers,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
