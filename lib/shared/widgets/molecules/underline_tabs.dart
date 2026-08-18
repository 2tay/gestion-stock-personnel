import 'package:flutter/material.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/theme/theme.dart';

/// Onglets soulignés, utilisés à l'intérieur des fiches de détail :
/// « Mouvements | Informations | Fournisseurs » de la fiche produit, et plus
/// tard les onglets du détail de commande.
///
/// À ne pas confondre avec `FilterTabs`, qui filtre une liste : ici on change
/// de contenu à l'intérieur d'un même écran.
class UnderlineTabs<T> extends StatelessWidget {
  const UnderlineTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.trailing,
    super.key,
  });

  /// Couples (valeur, libellé), dans l'ordre d'affichage.
  final List<(T value, String label)> tabs;

  final T selected;
  final ValueChanged<T> onSelected;

  /// Contenu aligné à droite de la barre d'onglets (compteur, action…).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final (T value, String label) tab in tabs)
                    _Tab(
                      label: tab.$2,
                      selected: tab.$1 == selected,
                      onTap: () => onSelected(tab.$1),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: trailing,
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
