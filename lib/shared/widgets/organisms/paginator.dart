import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../atoms/app_icon_button.dart';

/// Pied de tableau : « Affichage 1 à 5 sur 5 » + navigation entre les pages.
class Paginator extends StatelessWidget {
  const Paginator({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.onPageChanged,
    this.itemLabel = 'éléments',
    super.key,
  });

  /// Index de page à partir de 0.
  final int page;
  final int pageSize;
  final int totalItems;
  final ValueChanged<int> onPageChanged;

  /// Nom des éléments listés, pour le libellé (« produits », « commandes »).
  final String itemLabel;

  int get pageCount => totalItems == 0 ? 1 : (totalItems / pageSize).ceil();
  int get firstIndex => totalItems == 0 ? 0 : page * pageSize + 1;
  int get lastIndex =>
      ((page + 1) * pageSize) > totalItems ? totalItems : (page + 1) * pageSize;

  @override
  Widget build(BuildContext context) {
    final bool canPrevious = page > 0;
    final bool canNext = page < pageCount - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Affichage ${Formatters.integer(firstIndex)} à '
            '${Formatters.integer(lastIndex)} sur '
            '${Formatters.integer(totalItems)}',
            style: AppTypography.bodySm,
          ),
          const Spacer(),
          AppIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Page précédente',
            size: 36,
            showBorder: true,
            onPressed: canPrevious ? () => onPageChanged(page - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              '${page + 1} / $pageCount',
              style: AppTypography.labelStrong,
            ),
          ),
          AppIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Page suivante',
            size: 36,
            showBorder: true,
            onPressed: canNext ? () => onPageChanged(page + 1) : null,
          ),
        ],
      ),
    );
  }
}
