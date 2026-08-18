import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Construit une interface différente selon la classe de largeur.
///
/// ```dart
/// ResponsiveBuilder(
///   expanded: (_) => const TwoPaneLayout(),
///   medium: (_) => const SinglePaneLayout(),
/// )
/// ```
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    required this.expanded,
    this.medium,
    this.compact,
    super.key,
  });

  /// Cible principale (tablette paysage). Sert de valeur par défaut.
  final WidgetBuilder expanded;

  /// Repli tablette portrait. À défaut, [expanded] est utilisé.
  final WidgetBuilder? medium;

  /// Repli étroit. À défaut, [medium] puis [expanded] sont utilisés.
  final WidgetBuilder? compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ScreenSize size = Breakpoints.fromWidth(constraints.maxWidth);
        return switch (size) {
          ScreenSize.expanded => expanded(context),
          ScreenSize.medium => (medium ?? expanded)(context),
          ScreenSize.compact => (compact ?? medium ?? expanded)(context),
        };
      },
    );
  }
}
