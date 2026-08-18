/// Durées d'animation homogènes.
abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Anti-rebond des champs de recherche.
  static const Duration searchDebounce = Duration(milliseconds: 300);
}
