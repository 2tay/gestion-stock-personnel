import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Bouton icône carré : actions de la barre supérieure, menus « … » des
/// lignes de tableau, flèches de retour des panneaux de détail.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = AppSizes.minTouchTarget,
    this.iconSize = AppSizes.iconMd,
    this.color,
    this.background,
    this.showBorder = false,
    this.badgeCount,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? background;
  final bool showBorder;

  /// Pastille de notification. `0` ou `null` masque la pastille.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    Widget button = Material(
      color: background ?? Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: showBorder
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                )
              : null,
          child: Icon(
            icon,
            size: iconSize,
            color: enabled
                ? (color ?? AppColors.textSecondary)
                : AppColors.textDisabled,
          ),
        ),
      ),
    );

    if (badgeCount != null && badgeCount! > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          button,
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount! > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
