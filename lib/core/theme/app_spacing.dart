/// Échelle d'espacement (base 4). Utiliser ces constantes plutôt que des
/// valeurs libres pour garder un rythme vertical cohérent.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;

  /// Marge intérieure standard d'une page tablette.
  static const double pageH = 24;
  static const double pageV = 20;
}

/// Rayons de coin.
abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;
  static const double pill = 999;
}

/// Dimensions récurrentes de l'interface tablette.
abstract final class AppSizes {
  /// Cible tactile minimale confortable sur tablette.
  static const double minTouchTarget = 48;

  static const double navRailWidth = 76;
  static const double navRailExpandedWidth = 232;
  static const double topBarHeight = 64;

  static const double buttonHeightSm = 36;
  static const double buttonHeightMd = 44;
  static const double buttonHeightLg = 52;

  static const double fieldHeight = 44;
  static const double tableRowHeight = 52;
  static const double tableHeaderHeight = 44;

  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
}
