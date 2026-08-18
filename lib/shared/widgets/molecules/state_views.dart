import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/app_button.dart';

/// Les trois états non nominaux d'une zone de contenu : vide, erreur,
/// chargement. Chaque liste et chaque carte doit pouvoir les afficher.

/// Aucun résultat : liste vide, filtre trop restrictif, module non encore
/// alimenté.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  /// Variante « aucun résultat de recherche ».
  const EmptyState.noResults({
    this.title = 'Aucun résultat',
    this.message = 'Essayez de modifier votre recherche ou vos filtres.',
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  }) : icon = Icons.search_off_rounded;

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _StateShell(
      compact: compact,
      icon: icon,
      iconColor: AppColors.textTertiary,
      iconBackground: AppColors.neutralSoft,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// Échec de chargement, avec possibilité de réessayer.
class ErrorState extends StatelessWidget {
  const ErrorState({
    this.title = 'Une erreur est survenue',
    this.message = 'Impossible de charger les données pour le moment.',
    this.onRetry,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _StateShell(
      compact: compact,
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.danger,
      iconBackground: AppColors.dangerSoft,
      title: title,
      message: message,
      actionLabel: onRetry == null ? null : 'Réessayer',
      onAction: onRetry,
    );
  }
}

/// Indicateur de chargement centré.
class LoadingState extends StatelessWidget {
  const LoadingState({this.message, this.compact = false, super.key});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? AppSpacing.xxl : AppSpacing.giant,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(message!, style: AppTypography.bodySm),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bloc gris animé qui remplace le contenu pendant le chargement.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    this.width,
    this.height = 14,
    this.radius = AppRadius.sm,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.neutralSoft,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class _StateShell extends StatelessWidget {
  const _StateShell({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.compact,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: compact ? AppSpacing.xxl : AppSpacing.giant,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: compact ? 40 : 56,
              height: compact ? 40 : 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: compact ? 20 : 28, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: compact ? AppTypography.titleSm : AppTypography.titleMd,
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              AppButton.secondary(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
