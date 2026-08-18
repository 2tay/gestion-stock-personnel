/// Une ligne de comptage : un produit dans un inventaire donné.
///
/// La ligne **fige** le stock théorique et le prix unitaire au moment où
/// l'inventaire est créé. Un comptage dure vingt minutes pendant lesquelles le
/// service continue de tourner ; si la colonne « théorique » se recalculait en
/// direct, les écarts constatés seraient faux.
class InventoryLine {
  const InventoryLine({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.theoreticalStock,
    required this.unitPrice,
    this.emoji = '📦',
    this.categoryName = '',
    this.barcode,
    this.countedStock,
    this.countedAt,
  });

  final String productId;
  final String productName;
  final String emoji;
  final String categoryName;
  final String unit;
  final String? barcode;

  /// Stock enregistré au moment de l'ouverture de l'inventaire. Immuable.
  final double theoreticalStock;

  /// Prix unitaire figé, pour valoriser l'écart même si le prix change après.
  final double unitPrice;

  /// Quantité réellement comptée.
  ///
  /// `null` signifie **non compté**, ce qui n'est pas la même chose que
  /// compté à zéro : une ligne non comptée ne produira aucun ajustement à la
  /// validation, alors qu'une ligne comptée à zéro videra le stock du produit.
  final double? countedStock;

  final DateTime? countedAt;

  bool get isCounted => countedStock != null;

  /// Écart entre le réel et le théorique. `null` tant que non compté.
  double? get variance =>
      countedStock == null ? null : countedStock! - theoreticalStock;

  /// Valorisation de l'écart, en MAD.
  double get varianceValue => (variance ?? 0) * unitPrice;

  /// Ligne comptée dont la quantité diffère du théorique : c'est elle qui
  /// génèrera un mouvement d'ajustement à la validation.
  bool get hasVariance => isCounted && variance != 0;

  InventoryLine copyWith({
    double? countedStock,
    DateTime? countedAt,
    bool clearCount = false,
  }) {
    return InventoryLine(
      productId: productId,
      productName: productName,
      emoji: emoji,
      categoryName: categoryName,
      unit: unit,
      barcode: barcode,
      theoreticalStock: theoreticalStock,
      unitPrice: unitPrice,
      countedStock: clearCount ? null : (countedStock ?? this.countedStock),
      countedAt: clearCount ? null : (countedAt ?? this.countedAt),
    );
  }

  // Pas de redéfinition de `==` : deux instances distinctes sont deux états
  // distincts.
  //
  // Une égalité fondée sur l'`id` seul paraissait tentante (« c'est la même
  // ligne »), mais elle casse la réactivité : Riverpod ne notifie ses
  // auditeurs que si la nouvelle valeur est `!=` de l'ancienne. Un objet
  // modifié mais « égal » par son id laissait donc les écrans afficher l'état
  // précédent. L'identité d'entité est portée par `id`, comparé explicitement
  // là où c'est nécessaire — et par `rowKey` dans les tableaux.
}
