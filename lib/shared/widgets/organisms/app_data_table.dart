import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../molecules/state_views.dart';

/// Description d'une colonne de [AppDataTable].
///
/// La cellule est un widget : une colonne peut donc afficher un texte, un
/// `StatusBadge`, une miniature produit ou un menu d'actions.
class AppColumn<T> {
  const AppColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.width,
    this.alignment = Alignment.centerLeft,
    this.sortValue,
    this.numeric = false,
  });

  /// Colonne de texte simple : le cas le plus fréquent.
  factory AppColumn.text({
    required String label,
    required String Function(T row) value,
    int flex = 1,
    double? width,
    bool numeric = false,
    Comparable<Object>? Function(T row)? sortValue,
    TextStyle? style,
  }) {
    return AppColumn<T>(
      label: label,
      flex: flex,
      width: width,
      numeric: numeric,
      alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
      sortValue: sortValue,
      cell: (T row) => Text(
        value(row),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style ?? (numeric ? AppTypography.numeric : AppTypography.bodyMd),
      ),
    );
  }

  final String label;
  final Widget Function(T row) cell;

  /// Largeur proportionnelle, ignorée si [width] est défini.
  final int flex;

  /// Largeur fixe en pixels (colonnes de statut, d'actions, de date).
  final double? width;

  final Alignment alignment;

  /// Rend la colonne triable. `null` = non triable.
  final Comparable<Object>? Function(T row)? sortValue;

  /// Aligne l'en-tête à droite et utilise les chiffres tabulaires.
  final bool numeric;

  bool get sortable => sortValue != null;
}

/// Action du menu « … » en fin de ligne.
class AppRowAction<T> {
  const AppRowAction({
    required this.label,
    required this.onSelected,
    this.icon,
    this.destructive = false,
    this.isEnabled,
  });

  final String label;
  final void Function(T row) onSelected;
  final IconData? icon;
  final bool destructive;
  final bool Function(T row)? isEnabled;
}

/// Tableau de données générique — le composant le plus réutilisé de
/// l'application : produits, inventaires, commandes, employés, mouvements,
/// lignes de comptage et lignes de réception passent tous par ici.
///
/// Il gère l'en-tête, le tri, le survol, le clic de ligne, le menu d'actions
/// et les états vide / chargement. Il ne connaît aucun modèle métier.
class AppDataTable<T> extends StatefulWidget {
  const AppDataTable({
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.actions = const <Never>[],
    this.isLoading = false,
    this.emptyState,
    this.rowHeight = AppSizes.tableRowHeight,
    this.minWidth = 720,
    this.shrinkWrap = true,
    this.selectedRow,
    this.rowKey,
    super.key,
  });

  final List<AppColumn<T>> columns;
  final List<T> rows;

  /// Ouvre la fiche de détail (produit, commande, employé…).
  final void Function(T row)? onRowTap;

  /// Ajoute une colonne « … » en fin de ligne si la liste n'est pas vide.
  final List<AppRowAction<T>> actions;

  final bool isLoading;

  /// Affiché quand [rows] est vide. Par défaut : [EmptyState.noResults].
  final Widget? emptyState;

  final double rowHeight;

  /// En dessous de cette largeur, le tableau défile horizontalement plutôt
  /// que de compresser les colonnes.
  final double minWidth;

  /// `true` : le tableau prend la hauteur de son contenu (dans une carte).
  /// `false` : il défile dans l'espace disponible (page de liste).
  final bool shrinkWrap;

  /// Ligne actuellement ouverte dans le panneau de détail.
  final T? selectedRow;

  /// Identité stable d'une ligne, utilisée pour la sélection et les clés.
  final Object Function(T row)? rowKey;

  @override
  State<AppDataTable<T>> createState() => _AppDataTableState<T>();
}

class _AppDataTableState<T> extends State<AppDataTable<T>> {
  int? _sortColumn;
  bool _sortAscending = true;
  int? _hoveredIndex;

  List<T> get _sortedRows {
    final int? index = _sortColumn;
    if (index == null) return widget.rows;

    final AppColumn<T> column = widget.columns[index];
    final Comparable<Object>? Function(T)? key = column.sortValue;
    if (key == null) return widget.rows;

    final List<T> sorted = List<T>.of(widget.rows);
    sorted.sort((T a, T b) {
      final Comparable<Object>? va = key(a);
      final Comparable<Object>? vb = key(b);
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;
      final int result = va.compareTo(vb);
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  void _onHeaderTap(int index) {
    if (!widget.columns[index].sortable) return;
    setState(() {
      if (_sortColumn == index) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = index;
        _sortAscending = true;
      }
    });
  }

  bool _isSelected(T row) {
    final T? selected = widget.selectedRow;
    if (selected == null) return false;
    final Object Function(T)? key = widget.rowKey;
    return key == null ? selected == row : key(selected) == key(row);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _SkeletonTable(
        columns: widget.columns.length,
        rowHeight: widget.rowHeight,
      );
    }

    if (widget.rows.isEmpty) {
      return widget.emptyState ?? const EmptyState.noResults();
    }

    final List<T> rows = _sortedRows;

    final Widget table = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _header(),
        const Divider(height: 1),
        if (widget.shrinkWrap)
          for (int i = 0; i < rows.length; i++) _row(rows[i], i)
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              itemBuilder: (BuildContext _, int i) => _row(rows[i], i),
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= widget.minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: widget.minWidth, child: table),
        );
      },
    );
  }

  Widget _header() {
    return SizedBox(
      height: AppSizes.tableHeaderHeight,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < widget.columns.length; i++)
            _cellWrapper(
              column: widget.columns[i],
              child: _HeaderCell(
                column: widget.columns[i],
                sorted: _sortColumn == i,
                ascending: _sortAscending,
                onTap: () => _onHeaderTap(i),
              ),
            ),
          if (widget.actions.isNotEmpty)
            const SizedBox(width: AppSizes.minTouchTarget),
        ],
      ),
    );
  }

  Widget _row(T row, int index) {
    final bool selected = _isSelected(row);
    final bool hovered = _hoveredIndex == index;

    final Color background = selected
        ? AppColors.primarySoft.withValues(alpha: 0.45)
        : hovered
            ? AppColors.surfaceHover
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: widget.onRowTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(row),
        child: Container(
          height: widget.rowHeight,
          color: background,
          child: Row(
            children: <Widget>[
              for (final AppColumn<T> column in widget.columns)
                _cellWrapper(
                  column: column,
                  child: Align(
                    alignment: column.alignment,
                    child: column.cell(row),
                  ),
                ),
              if (widget.actions.isNotEmpty) _actionsMenu(row),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cellWrapper({required AppColumn<T> column, required Widget child}) {
    final Widget padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: child,
    );
    return column.width != null
        ? SizedBox(width: column.width, child: padded)
        : Expanded(flex: column.flex, child: padded);
  }

  Widget _actionsMenu(T row) {
    final List<AppRowAction<T>> available = widget.actions
        .where((AppRowAction<T> a) => a.isEnabled?.call(row) ?? true)
        .toList();

    return SizedBox(
      width: AppSizes.minTouchTarget,
      child: PopupMenuButton<AppRowAction<T>>(
        tooltip: 'Actions',
        icon: const Icon(
          Icons.more_horiz_rounded,
          size: AppSizes.iconMd,
          color: AppColors.textTertiary,
        ),
        position: PopupMenuPosition.under,
        enabled: available.isNotEmpty,
        onSelected: (AppRowAction<T> action) => action.onSelected(row),
        itemBuilder: (BuildContext _) => <PopupMenuEntry<AppRowAction<T>>>[
          for (final AppRowAction<T> action in available)
            PopupMenuItem<AppRowAction<T>>(
              value: action,
              height: 40,
              child: Row(
                children: <Widget>[
                  if (action.icon != null) ...<Widget>[
                    Icon(
                      action.icon,
                      size: AppSizes.iconSm,
                      color: action.destructive
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Text(
                    action.label,
                    style: AppTypography.bodyMd.copyWith(
                      color: action.destructive ? AppColors.danger : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCell<T> extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.sorted,
    required this.ascending,
    required this.onTap,
  });

  final AppColumn<T> column;
  final bool sorted;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget label = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            column.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.tableHeader.copyWith(
              color: sorted ? AppColors.textSecondary : null,
            ),
          ),
        ),
        if (column.sortable) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Icon(
            sorted
                ? (ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 13,
            color: sorted ? AppColors.primary : AppColors.textTertiary,
          ),
        ],
      ],
    );

    final Widget aligned = Align(alignment: column.alignment, child: label);
    if (!column.sortable) return aligned;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: aligned,
    );
  }
}

class _SkeletonTable extends StatelessWidget {
  const _SkeletonTable({required this.columns, required this.rowHeight});

  final int columns;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int r = 0; r < 6; r++)
          SizedBox(
            height: rowHeight,
            child: Row(
              children: <Widget>[
                for (int c = 0; c < columns; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: SkeletonBox(width: c == 0 ? 140 : 70),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
