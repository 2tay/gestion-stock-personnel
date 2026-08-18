import 'package:flutter/material.dart';

import '../responsive/breakpoints.dart';

/// Raccourcis de lecture du contexte, pour éviter les `Theme.of(context)`
/// répétés dans les widgets.
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get texts => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;

  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);

  ScreenSize get breakpoint => Breakpoints.of(this);
  bool get isExpanded => breakpoint.isExpanded;
  bool get isCompact => breakpoint.isCompact;

  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  void unfocus() => FocusScope.of(this).unfocus();
}
