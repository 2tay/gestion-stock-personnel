import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../domain/entities/product.dart';
import '../controllers/stock_providers.dart';
import '../widgets/product_detail_panel.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/product_name_cell.dart';

/// Module Stock : liste des produits à gauche, fiche produit à droite.
class StockPage extends ConsumerWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Product? selected = ref.watch(selectedProductProvider);

    return AppScaffold(
      title: 'Stock',
      subtitle: 'Gérez vos produits et suivez vos stocks en temps réel',
      userName: ref.watch(currentUserNameProvider),
      body: MasterDetailLayout(
        master: const _ProductListCard(),
        detail: selected == null
            ? null
            : ProductDetailPanel(
                key: ValueKey<String>(selected.id),
                product: selected,
                onClose: () =>
                    ref.read(selectedProductIdProvider.notifier).state = null,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Liste
// ---------------------------------------------------------------------------

class _ProductListCard extends ConsumerWidget {
  const _ProductListCard();

  /// Ouvre le scanner, puis sélectionne le produit correspondant au code.
  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final String? code = await ScannerSheet.show(context);
    if (code == null || !context.mounted) return;

    final Product? found =
        await ref.read(productRepositoryProvider).findByBarcode(code);
    if (!context.mounted) return;

    if (found != null) {
      ref.read(selectedProductIdProvider.notifier).state = found.id;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produit trouvé : ${found.name}')),
      );
      return;
    }

    final bool create = await ConfirmDialog.show(
      context,
      title: 'Produit inconnu',
      message: 'Aucun produit ne correspond au code $code. '
          'Voulez-vous créer une fiche avec ce code-barres ?',
      confirmLabel: 'Créer le produit',
      icon: Icons.qr_code_scanner_rounded,
    );
    if (!create || !context.mounted) return;
    await ProductFormDialog.show(context, prefilledBarcode: code);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StockQuery query = ref.watch(stockQueryProvider);
    final StockQueryController queryController =
        ref.read(stockQueryProvider.notifier);
    final StockCounters counters = ref.watch(stockCountersProvider);
    final bool canManage = ref.watch(canManageCatalogProvider);

    final List<FilterTab<StockFilter>> filters = <FilterTab<StockFilter>>[
      FilterTab<StockFilter>(
        label: StockFilter.tous.label,
        value: StockFilter.tous,
        count: counters.total,
      ),
      FilterTab<StockFilter>(
        label: StockFilter.categories.label,
        value: StockFilter.categories,
        count: counters.categories,
      ),
      FilterTab<StockFilter>(
        label: StockFilter.faible.label,
        value: StockFilter.faible,
        count: counters.low,
      ),
    ];

    final List<Widget> headerActions = <Widget>[
      if (query.categoryId != null)
        _CategoryFilterChip(
          categoryId: query.categoryId!,
          onCleared: queryController.clearCategory,
        ),
      AppButton.soft(
        label: 'Scanner',
        icon: Icons.qr_code_scanner_rounded,
        onPressed: () => _scan(context, ref),
      ),
      if (canManage)
        AppButton.primary(
          label: 'Nouveau produit',
          icon: Icons.add_rounded,
          onPressed: () => ProductFormDialog.show(context),
        ),
    ];

    // L'onglet « Catégories » remplace le tableau des produits par celui des
    // catégories ; le reste de la structure (recherche, filtres) est le même.
    if (query.filter == StockFilter.categories) {
      return ListPageTemplate<CategoryStats, StockFilter>(
        searchHint: 'Rechercher un produit…',
        onSearchChanged: queryController.setSearch,
        headerActions: headerActions,
        filters: filters,
        selectedFilter: query.filter,
        onFilterChanged: queryController.setFilter,
        rows: ref.watch(categoryStatsProvider),
        rowKey: (CategoryStats c) => c.category.id,
        onRowTap: (CategoryStats c) =>
            queryController.selectCategory(c.category.id),
        columns: _categoryColumns(),
        emptyState: const EmptyState(
          icon: Icons.category_outlined,
          title: 'Aucune catégorie',
          message: 'Créez un produit pour voir apparaître sa catégorie.',
        ),
      );
    }

    final AsyncValue<List<Product>> products = ref.watch(visibleProductsProvider);
    final List<Product> rows = products.valueOrNull ?? const <Product>[];

    return ListPageTemplate<Product, StockFilter>(
      searchHint: 'Rechercher un produit…',
      onSearchChanged: queryController.setSearch,
      headerActions: headerActions,
      filters: filters,
      selectedFilter: query.filter,
      onFilterChanged: queryController.setFilter,
      isLoading: products.isLoading,
      rows: rows,
      rowKey: (Product p) => p.id,
      selectedRow: ref.watch(selectedProductProvider),
      onRowTap: (Product p) =>
          ref.read(selectedProductIdProvider.notifier).state = p.id,
      columns: _productColumns(),
      rowActions: _rowActions(context, ref, canManage: canManage),
      emptyState: query.search.isEmpty && query.filter == StockFilter.tous
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Aucun produit',
              message: 'Créez votre premier produit pour commencer à suivre '
                  'votre stock.',
              actionLabel: canManage ? 'Nouveau produit' : null,
              onAction:
                  canManage ? () => ProductFormDialog.show(context) : null,
            )
          : const EmptyState.noResults(),
      footer: _StockFooter(products: rows),
    );
  }

  List<AppColumn<Product>> _productColumns() {
    return <AppColumn<Product>>[
      AppColumn<Product>(
        label: 'Produit',
        flex: 4,
        sortValue: (Product p) => p.name,
        cell: (Product p) => ProductNameCell(product: p),
      ),
      AppColumn<Product>.text(
        label: 'Catégorie',
        flex: 3,
        value: (Product p) => p.categoryName,
        sortValue: (Product p) => p.categoryName,
      ),
      AppColumn<Product>.text(
        label: 'Stock',
        flex: 2,
        numeric: true,
        value: (Product p) => Formatters.quantity(p.currentStock, p.unit),
        sortValue: (Product p) => p.currentStock,
      ),
      AppColumn<Product>.text(
        label: 'Unité',
        width: 90,
        value: (Product p) => p.unit,
      ),
      AppColumn<Product>.text(
        label: 'Valeur',
        flex: 2,
        numeric: true,
        value: (Product p) => Formatters.amount(p.stockValue),
        sortValue: (Product p) => p.stockValue,
      ),
      AppColumn<Product>(
        label: 'Statut',
        width: 110,
        cell: (Product p) => StatusBadge.stock(p.status),
      ),
    ];
  }

  List<AppColumn<CategoryStats>> _categoryColumns() {
    return <AppColumn<CategoryStats>>[
      AppColumn<CategoryStats>(
        label: 'Catégorie',
        flex: 4,
        sortValue: (CategoryStats c) => c.category.name,
        cell: (CategoryStats c) => Row(
          children: <Widget>[
            ProductAvatar(emoji: c.category.emoji),
            const SizedBox(width: AppSpacing.md),
            Text(c.category.name, style: AppTypography.labelStrong),
          ],
        ),
      ),
      AppColumn<CategoryStats>.text(
        label: 'Produits',
        flex: 2,
        numeric: true,
        value: (CategoryStats c) => Formatters.integer(c.productCount),
        sortValue: (CategoryStats c) => c.productCount,
      ),
      AppColumn<CategoryStats>(
        label: 'À surveiller',
        flex: 2,
        alignment: Alignment.centerRight,
        sortValue: (CategoryStats c) => c.lowCount,
        cell: (CategoryStats c) => c.lowCount == 0
            ? const Text('—', style: AppTypography.numeric)
            : StatusBadge(
                dense: true,
                tone: SemanticTone.warning,
                label: '${c.lowCount} produit${c.lowCount > 1 ? 's' : ''}',
              ),
      ),
      AppColumn<CategoryStats>.text(
        label: 'Valeur du stock',
        flex: 3,
        numeric: true,
        value: (CategoryStats c) => Formatters.money(c.stockValue),
        sortValue: (CategoryStats c) => c.stockValue,
      ),
    ];
  }

  List<AppRowAction<Product>> _rowActions(
    BuildContext context,
    WidgetRef ref, {
    required bool canManage,
  }) {
    if (!canManage) return const <AppRowAction<Product>>[];

    return <AppRowAction<Product>>[
      AppRowAction<Product>(
        label: 'Modifier',
        icon: Icons.edit_outlined,
        onSelected: (Product p) => ProductFormDialog.show(context, product: p),
      ),
      AppRowAction<Product>(
        label: 'Supprimer',
        icon: Icons.delete_outline_rounded,
        destructive: true,
        onSelected: (Product p) async {
          final bool confirmed = await ConfirmDialog.show(
            context,
            title: 'Supprimer ce produit ?',
            message: '« ${p.name} » et son historique de mouvements seront '
                'définitivement supprimés.',
            confirmLabel: 'Supprimer',
            destructive: true,
          );
          if (!confirmed) return;
          await ref.read(stockControllerProvider.notifier).delete(p.id);
        },
      ),
    ];
  }
}

/// Puce indiquant la catégorie active, avec sa croix de suppression.
class _CategoryFilterChip extends ConsumerWidget {
  const _CategoryFilterChip({required this.categoryId, required this.onCleared});

  final String categoryId;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CategoryStats> stats = ref.watch(categoryStatsProvider);
    final String name = stats
        .where((CategoryStats c) => c.category.id == categoryId)
        .map((CategoryStats c) => c.category.name)
        .firstOrNull ??
        'Catégorie';

    return AppChip(
      label: name,
      selected: true,
      trailingIcon: Icons.close_rounded,
      onTap: onCleared,
    );
  }
}

/// Pied de tableau : nombre de produits, alertes et valeur totale.
class _StockFooter extends StatelessWidget {
  const _StockFooter({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final int lowCount = products
        .where((Product p) => p.status != StockStatus.ok)
        .length;
    final double totalValue = products.fold<double>(
      0,
      (double sum, Product p) => sum + p.stockValue,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Text(
            '${Formatters.integer(products.length)} produit'
            '${products.length > 1 ? 's' : ''} affiché'
            '${products.length > 1 ? 's' : ''}',
            style: AppTypography.bodySm,
          ),
          if (lowCount > 0) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            StatusBadge(
              dense: true,
              tone: SemanticTone.warning,
              label: '$lowCount à commander',
            ),
          ],
          const Spacer(),
          const Text('Valeur totale', style: AppTypography.caption),
          const SizedBox(width: AppSpacing.sm),
          Text(Formatters.money(totalValue), style: AppTypography.numeric),
        ],
      ),
    );
  }
}
