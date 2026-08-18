import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/app_chip.dart';

/// Un onglet de filtre : libellé + valeur associée + compteur optionnel.
class FilterTab<T> {
  const FilterTab({
    required this.label,
    required this.value,
    this.count,
    this.icon,
  });

  final String label;
  final T value;
  final int? count;
  final IconData? icon;
}

/// Barre d'onglets de filtre : « Tous | Catégories | Stock faible »,
/// « Toutes | En cours | Partielles | Reçues »…
///
/// Générique sur la valeur pour être réutilisée par tous les modules.
class FilterTabs<T> extends StatelessWidget {
  const FilterTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.dense = false,
    super.key,
  });

  final List<FilterTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final FilterTab<T> tab in tabs) ...<Widget>[
            AppChip(
              label: tab.label,
              icon: tab.icon,
              count: tab.count,
              dense: dense,
              selected: tab.value == selected,
              onTap: () => onSelected(tab.value),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}
