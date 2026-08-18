import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Conteneur blanc arrondi : la brique de base de toutes les pages.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.onTap,
    this.borderColor,
    this.color,
    this.radius = AppRadius.lg,
    this.shadows = AppShadows.card,
    this.width,
    this.height,
    this.clip = false,
    super.key,
  });

  /// Variante sans marge intérieure, pour les cartes qui contiennent un
  /// tableau ou une liste allant jusqu'aux bords.
  const AppCard.flush({
    required this.child,
    this.margin,
    this.onTap,
    this.borderColor,
    this.color,
    this.radius = AppRadius.lg,
    this.shadows = AppShadows.card,
    this.width,
    this.height,
    super.key,
  })  : padding = EdgeInsets.zero,
        clip = true;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;
  final double radius;
  final List<BoxShadow> shadows;
  final double? width;
  final double? height;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(radius);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: br,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: shadows,
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: br, onTap: onTap, child: content),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }
    return content;
  }
}
