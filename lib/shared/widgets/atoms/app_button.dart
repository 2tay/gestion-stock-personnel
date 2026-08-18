import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Variantes visuelles de bouton présentes dans la maquette.
enum AppButtonVariant {
  /// Bleu plein : « Nouveau produit », « Enregistrer le comptage ».
  primary,

  /// Bordure grise, fond blanc : « Annuler », « Modifier ».
  secondary,

  /// Rouge plein : « Pointer la fin ».
  danger,

  /// Sans fond ni bordure : actions tertiaires, « Voir tous les produits ».
  ghost,

  /// Bleu clair sur fond bleu pâle : « Scanner ».
  soft,
}

enum AppButtonSize { sm, md, lg }

/// Bouton unique de l'application. Ne jamais utiliser [ElevatedButton] ou
/// [TextButton] directement dans une feature.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
    this.tooltip,
    super.key,
  });

  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
    this.tooltip,
    super.key,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
    this.tooltip,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
    this.tooltip,
    super.key,
  }) : variant = AppButtonVariant.danger;

  const AppButton.ghost({
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
    this.tooltip,
    super.key,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.soft({
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
    this.tooltip,
    super.key,
  }) : variant = AppButtonVariant.soft;

  final String label;

  /// `null` désactive le bouton.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;

  /// Occupe toute la largeur disponible.
  final bool expand;
  final String? tooltip;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final _ButtonStyleTokens t = _tokens(variant, _enabled);
    final double height = switch (size) {
      AppButtonSize.sm => AppSizes.buttonHeightSm,
      AppButtonSize.md => AppSizes.buttonHeightMd,
      AppButtonSize.lg => AppSizes.buttonHeightLg,
    };
    final double fontSize = switch (size) {
      AppButtonSize.sm => 13,
      AppButtonSize.md => 14,
      AppButtonSize.lg => 15,
    };
    final double padH = switch (size) {
      AppButtonSize.sm => AppSpacing.md,
      AppButtonSize.md => AppSpacing.lg,
      AppButtonSize.lg => AppSpacing.xl,
    };
    final double iconSize = size == AppButtonSize.sm ? 16.0 : 18.0;

    Widget child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (isLoading)
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(t.foreground),
            ),
          )
        else if (icon != null)
          Icon(icon, size: iconSize, color: t.foreground),
        if (isLoading || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: t.foreground,
              height: 1.2,
            ),
          ),
        ),
        if (trailingIcon != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: iconSize, color: t.foreground),
        ],
      ],
    );

    child = Material(
      color: t.background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: _enabled ? onPressed : null,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: padH),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: t.border == null
                ? null
                : Border.all(color: t.border!, width: 1),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );

    if (expand) child = SizedBox(width: double.infinity, child: child);
    if (tooltip != null) child = Tooltip(message: tooltip!, child: child);
    return child;
  }

  _ButtonStyleTokens _tokens(AppButtonVariant v, bool enabled) {
    if (!enabled) {
      return const _ButtonStyleTokens(
        background: AppColors.neutralSoft,
        foreground: AppColors.textDisabled,
        border: AppColors.border,
      );
    }
    return switch (v) {
      AppButtonVariant.primary => const _ButtonStyleTokens(
          background: AppColors.primary,
          foreground: AppColors.textOnPrimary,
        ),
      AppButtonVariant.secondary => const _ButtonStyleTokens(
          background: AppColors.surface,
          foreground: AppColors.textSecondary,
          border: AppColors.borderStrong,
        ),
      AppButtonVariant.danger => const _ButtonStyleTokens(
          background: AppColors.danger,
          foreground: AppColors.textOnPrimary,
        ),
      AppButtonVariant.ghost => const _ButtonStyleTokens(
          background: Colors.transparent,
          foreground: AppColors.primary,
        ),
      AppButtonVariant.soft => const _ButtonStyleTokens(
          background: AppColors.primarySoft,
          foreground: AppColors.primaryOnSoft,
        ),
    };
  }
}

class _ButtonStyleTokens {
  const _ButtonStyleTokens({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;
}
