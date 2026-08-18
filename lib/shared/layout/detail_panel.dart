import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../widgets/atoms/app_card.dart';
import '../widgets/atoms/app_icon_button.dart';

/// Panneau de détail affiché à droite de la liste : fiche produit, détail de
/// commande, carte de pointage, comptage d'inventaire.
///
/// En-tête normalisé (titre, sous-titre, retour, actions) et pied de panneau
/// optionnel pour les boutons de validation.
class DetailPanel extends StatelessWidget {
  const DetailPanel({
    required this.title,
    required this.child,
    this.subtitle,
    this.onClose,
    this.headerActions = const <Widget>[],
    this.footer,
    this.headerTrailing,
    this.scrollable = true,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Ferme le panneau (flèche de retour de la maquette).
  final VoidCallback? onClose;

  final List<Widget> headerActions;

  /// Élément aligné à droite du titre : badge de statut, chrono…
  final Widget? headerTrailing;

  /// Barre d'actions basse : « Annuler / Modifier / Enregistrer la réception ».
  final Widget? footer;

  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(padding: padding, child: child);

    return AppCard.flush(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _header(),
          const Divider(height: 1),
          Expanded(
            child: scrollable
                ? SingleChildScrollView(child: content)
                : content,
          ),
          if (footer != null) ...<Widget>[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: footer,
            ),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          if (onClose != null) ...<Widget>[
            AppIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Fermer le détail',
              size: 36,
              onPressed: onClose,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMd,
                ),
                if (subtitle != null)
                  Text(subtitle!, style: AppTypography.caption),
              ],
            ),
          ),
          if (headerTrailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            headerTrailing!,
          ],
          for (final Widget action in headerActions) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            action,
          ],
        ],
      ),
    );
  }
}
