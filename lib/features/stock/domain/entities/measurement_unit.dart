/// Unité de mesure d'un produit : kg, unité, litre…
///
/// Les unités sont configurables par l'établissement ; elles ne sont donc pas
/// une énumération mais une donnée.
class MeasurementUnit {
  const MeasurementUnit({
    required this.code,
    required this.label,
    this.allowsDecimals = true,
  });

  /// Abréviation affichée dans les tableaux : `kg`, `un.`, `L`.
  final String code;

  /// Libellé complet, affiché dans les formulaires : `Kilogramme`.
  final String label;

  /// `false` pour les unités indivisibles (bouteilles, sacs) : la saisie de
  /// quantité refuse alors les décimales.
  final bool allowsDecimals;

  @override
  bool operator ==(Object other) =>
      other is MeasurementUnit && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
