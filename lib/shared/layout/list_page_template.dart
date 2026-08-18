import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../widgets/atoms/app_card.dart';
import '../widgets/molecules/filter_tabs.dart';
import '../widgets/molecules/search_field.dart';
import '../widgets/organisms/app_data_table.dart';

/// Squelette partagé par toutes les pages de liste de l'application.
///
/// Stock, Inventaire, Commandes et Employés ont exactement la même
/// structure dans la maquette : une carte blanche contenant une barre de
/// recherche, des actions, des onglets de filtre, un tableau, puis un pied
/// de carte. Ce template encode cette structure une seule fois.
///
/// `T` est le type de ligne, `F` le type de la valeur de filtre.
class ListPageTemplate<T, F> extends StatelessWidget {
  const ListPageTemplate({
    required this.searchHint,
    required this.onSearchChanged,
    required this.columns,
    required this.rows,
    this.filters = const <Never>[],
    this.selectedFilter,
    this.onFilterChanged,
    this.headerActions = const <Widget>[],
    this.onRowTap,
    this.rowActions = const <Never>[],
    this.isLoading = false,
    this.emptyState,
    this.footer,
    this.selectedRow,
    this.rowKey,
    this.searchWidth = 320,
    super.key,
  });

  final String searchHint;
  final ValueChanged<String> onSearchChanged;

  /// Boutons à droite de la recherche : « Scanner », « Nouveau produit »…
  final List<Widget> headerActions;

  final List<FilterTab<F>> filters;
  final F? selectedFilter;
  final ValueChanged<F>? onFilterChanged;

  final List<AppColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;
  final List<AppRowAction<T>> rowActions;
  final bool isLoading;
  final Widget? emptyState;

  /// Pied de carte : pagination, lien « Voir tous les produits », total…
  final Widget? footer;

  final T? selectedRow;
  final Object Function(T row)? rowKey;
  final double searchWidth;

  @override
  Widget build(BuildContext context) {
    return AppCard.flush(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _toolbar(),
          if (filters.isNotEmpty) _filters(),
          const Divider(height: 1),
          Expanded(
            child: AppDataTable<T>(
              columns: columns,
              rows: rows,
              onRowTap: onRowTap,
              actions: rowActions,
              isLoading: isLoading,
              emptyState: emptyState,
              selectedRow: selectedRow,
              rowKey: rowKey,
              shrinkWrap: false,
            ),
          ),
          if (footer != null) ...<Widget>[
            const Divider(height: 1),
            footer!,
          ],
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: SearchField(
              hint: searchHint,
              width: searchWidth,
              onChanged: onSearchChanged,
            ),
          ),
          const Spacer(),
          for (final Widget action in headerActions) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            action,
          ],
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: FilterTabs<F>(
        tabs: filters,
        selected: selectedFilter as F,
        onSelected: onFilterChanged ?? (_) {},
      ),
    );
  }
}
