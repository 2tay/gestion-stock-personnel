import 'package:flutter/widgets.dart';

/// Sucre syntaxique de mise en page, utilisé avec parcimonie.
extension WidgetX on Widget {
  Widget paddedAll(double value) =>
      Padding(padding: EdgeInsets.all(value), child: this);

  Widget paddedSymmetric({double h = 0, double v = 0}) => Padding(
        padding: EdgeInsets.symmetric(horizontal: h, vertical: v),
        child: this,
      );

  Widget paddedOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) =>
      Padding(
        padding: EdgeInsets.only(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
        child: this,
      );

  Widget expanded([int flex = 1]) => Expanded(flex: flex, child: this);

  Widget get flexible => Flexible(child: this);

  /// Masque le widget sans le retirer de l'arbre (conserve l'espace).
  Widget visible(bool value) => Visibility(
        visible: value,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: this,
      );
}

/// Espaceurs concis : `const Gap.md()` plutôt que `SizedBox(height: 12)`.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  const Gap.xs({super.key}) : size = 4;
  const Gap.sm({super.key}) : size = 8;
  const Gap.md({super.key}) : size = 12;
  const Gap.lg({super.key}) : size = 16;
  const Gap.xl({super.key}) : size = 24;
  const Gap.xxl({super.key}) : size = 32;

  final double size;

  @override
  Widget build(BuildContext context) {
    final Axis? axis = _axisOf(context);
    return SizedBox(
      width: axis == Axis.horizontal ? size : null,
      height: axis == Axis.vertical ? size : null,
    );
  }

  Axis? _axisOf(BuildContext context) {
    final Flex? flex = context.findAncestorWidgetOfExactType<Flex>();
    return flex?.direction ?? Axis.vertical;
  }
}
