import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Puce cliquable : onglets de filtre, sélecteurs de période, tags de
/// catégorie. Pour un état non cliquable, préférer `StatusBadge`.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.trailingIcon,
    this.count,
    this.dense = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Compteur optionnel affiché à droite du libellé (ex. « En cours 3 »).
  final int? count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? AppColors.primaryOnSoft : AppColors.textSecondary;
    final Color bg = selected ? AppColors.primarySoft : Colors.transparent;
    final double padH = dense ? AppSpacing.md : AppSpacing.lg;
    final double padV = dense ? AppSpacing.xs + 2 : AppSpacing.sm;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: AppSizes.iconSm, color: fg),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: dense ? 12 : 13,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
              if (count != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : AppColors.neutralSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ],
              if (trailingIcon != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xs + 2),
                Icon(trailingIcon, size: AppSizes.iconSm, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
