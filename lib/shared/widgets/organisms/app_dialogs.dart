import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/app_button.dart';
import '../atoms/app_icon_button.dart';

/// Boîte de dialogue de formulaire : création de produit, de commande,
/// d'employé, d'inventaire…
///
/// Le contenu est libre ; l'en-tête et la barre d'actions sont normalisés.
class FormDialog extends StatelessWidget {
  const FormDialog({
    required this.title,
    required this.child,
    this.subtitle,
    this.confirmLabel = 'Enregistrer',
    this.cancelLabel = 'Annuler',
    this.onConfirm,
    this.onCancel,
    this.isSubmitting = false,
    this.width = 640,
    this.extraActions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isSubmitting;
  final double width;

  /// Actions supplémentaires placées à gauche de la barre (ex. « Supprimer »).
  final List<Widget> extraActions;

  /// Ouvre la boîte de dialogue et renvoie `true` si l'utilisateur confirme.
  static Future<T?> show<T>(BuildContext context, Widget dialog) {
    return showDialog<T>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (BuildContext _) => dialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(context),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: child,
              ),
            ),
            const Divider(height: 1),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: AppTypography.titleLg),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTypography.bodySm),
                ],
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: <Widget>[
          ...extraActions,
          const Spacer(),
          // Flexible : sur un dialogue étroit, un libellé de confirmation
          // long doit se tronquer plutôt que faire déborder la barre.
          Flexible(
            child: AppButton.secondary(
              label: cancelLabel,
              onPressed: onCancel ?? () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: AppButton.primary(
              label: confirmLabel,
              isLoading: isSubmitting,
              onPressed: onConfirm,
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation courte : suppression, annulation de commande, validation
/// d'inventaire, fin de pointage.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirmer',
    this.cancelLabel = 'Annuler',
    this.destructive = false,
    this.icon,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  /// Renvoie `true` si l'utilisateur confirme.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    bool destructive = false,
    IconData? icon,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (BuildContext _) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = destructive ? AppColors.danger : AppColors.primary;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Icon(
                      icon ??
                          (destructive
                              ? Icons.warning_amber_rounded
                              : Icons.help_outline_rounded),
                      color: accent,
                      size: AppSizes.iconLg,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: Text(title, style: AppTypography.titleMd)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(message, style: AppTypography.bodyMd),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  // Flexible : un libellé de confirmation explicite
                  // (« Valider l'inventaire ») dépasse la largeur du
                  // dialogue s'il n'a pas le droit de se compresser.
                  Flexible(
                    child: AppButton.secondary(
                      label: cancelLabel,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: AppButton(
                      label: confirmLabel,
                      variant: destructive
                          ? AppButtonVariant.danger
                          : AppButtonVariant.primary,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
