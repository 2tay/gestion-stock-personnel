import 'package:flutter/widgets.dart';

/// Classes de largeur. L'application cible la tablette en paysage ;
/// les classes plus étroites servent de repli (tablette 8" en portrait).
enum ScreenSize {
  /// < 700 : téléphone / tablette étroite en portrait.
  compact,

  /// 700–1099 : tablette 8-10" en portrait, ou fenêtre réduite.
  medium,

  /// >= 1100 : cible principale, tablette 10-13" en paysage.
  expanded,
}

abstract final class Breakpoints {
  static const double medium = 700;
  static const double expanded = 1100;

  static ScreenSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static ScreenSize fromWidth(double width) {
    if (width >= expanded) return ScreenSize.expanded;
    if (width >= medium) return ScreenSize.medium;
    return ScreenSize.compact;
  }
}

extension ScreenSizeX on ScreenSize {
  bool get isCompact => this == ScreenSize.compact;
  bool get isMedium => this == ScreenSize.medium;
  bool get isExpanded => this == ScreenSize.expanded;

  /// Le rail de navigation est toujours visible à partir de [medium].
  bool get showNavRail => this != ScreenSize.compact;

  /// Le détail s'affiche à côté de la liste uniquement en [expanded].
  bool get showSideDetail => this == ScreenSize.expanded;

  /// Le rail affiche les libellés en plus des icônes.
  bool get showNavLabels => this == ScreenSize.expanded;
}
