import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../stock/domain/entities/product.dart';
import '../../../stock/domain/entities/product_category.dart';
import '../../../stock/presentation/controllers/stock_providers.dart';
import '../../domain/entities/inventory.dart';
import '../controllers/inventory_providers.dart';

/// Ouverture d'un nouvel inventaire.
///
/// Le seul choix réel est le périmètre : tous les produits, ou une catégorie.
/// L'inventaire tournant par catégorie est l'usage courant en restauration —
/// compter 182 références chaque semaine n'est pas réaliste.
class InventoryFormDialog extends ConsumerStatefulWidget {
  const InventoryFormDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (BuildContext _) => const InventoryFormDialog(),
    );
  }

  @override
  ConsumerState<InventoryFormDialog> createState() =>
      _InventoryFormDialogState();
}

class _InventoryFormDialogState extends ConsumerState<InventoryFormDialog> {
  InventoryScope _scope = InventoryScope.tous;
  String? _categoryId;
  bool _submitting = false;
  String? _error;

  /// Nombre de produits que couvrira l'inventaire, affiché avant création.
  int _productCount(List<Product> products) {
    if (_scope == InventoryScope.tous) return products.length;
    if (_categoryId == null) return 0;
    return products.where((Product p) => p.categoryId == _categoryId).length;
  }

  Future<void> _submit(List<ProductCategory> categories) async {
    if (_scope == InventoryScope.categorie && _categoryId == null) {
      setState(() => _error = 'Choisissez la catégorie à inventorier.');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final ProductCategory? category = _categoryId == null
        ? null
        : categories.firstWhere((ProductCategory c) => c.id == _categoryId);

    final Inventory created =
        await ref.read(inventoryControllerProvider.notifier).create(
              scope: _scope,
              createdBy: ref.read(currentUserNameProvider),
              categoryId: category?.id,
              categoryName: category?.name,
            );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${created.reference} ouvert — ${created.totalCount} produits à '
          'compter.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> products =
        ref.watch(stockControllerProvider).valueOrNull ?? const <Product>[];
    final List<ProductCategory> categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <ProductCategory>[];
    final int count = _productCount(products);

    return FormDialog(
      title: 'Nouvel inventaire',
      subtitle: 'Choisissez les produits à compter',
      confirmLabel: 'Ouvrir l’inventaire',
      isSubmitting: _submitting,
      onConfirm: _submitting || count == 0
          ? null
          : () => _submit(categories),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Périmètre', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          for (final InventoryScope scope in InventoryScope.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ScopeOption(
                scope: scope,
                selected: _scope == scope,
                onTap: () => setState(() {
                  _scope = scope;
                  _error = null;
                }),
              ),
            ),
          if (_scope == InventoryScope.categorie) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: 'Catégorie',
              hint: 'Choisir…',
              value: _categoryId,
              items: categories.map((ProductCategory c) => c.id).toList(),
              labelBuilder: (String id) {
                final ProductCategory c =
                    categories.firstWhere((ProductCategory c) => c.id == id);
                final int n = products
                    .where((Product p) => p.categoryId == id)
                    .length;
                return '${c.emoji}  ${c.name}  ($n produits)';
              },
              onChanged: (String? v) => setState(() {
                _categoryId = v;
                _error = null;
              }),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _ScopeSummary(count: count),
        ],
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.scope,
    required this.selected,
    required this.onTap,
  });

  final InventoryScope scope;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (String description, IconData icon) = switch (scope) {
      InventoryScope.tous => (
          'Comptage complet de toutes les références du stock',
          Icons.all_inclusive_rounded,
        ),
      InventoryScope.categorie => (
          'Inventaire tournant : une catégorie à la fois',
          Icons.category_outlined,
        ),
    };

    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: AppSizes.iconLg,
                color: selected ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(scope.label, style: AppTypography.titleSm),
                    const SizedBox(height: 2),
                    Text(description, style: AppTypography.caption),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: AppSizes.iconMd,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rappelle ce qui va être créé, et surtout que le stock est figé maintenant.
class _ScopeSummary extends StatelessWidget {
  const _ScopeSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final bool empty = count == 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: empty ? AppColors.warningSoft : AppColors.infoSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            empty ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: AppSizes.iconMd,
            color: empty ? AppColors.warningOnSoft : AppColors.infoOnSoft,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              empty
                  ? 'Aucun produit dans ce périmètre.'
                  : '$count produit${count > 1 ? 's' : ''} à compter. '
                      'Le stock théorique sera figé à l’ouverture : les '
                      'mouvements enregistrés pendant le comptage '
                      'n’affecteront pas les écarts.',
              style: AppTypography.bodySm.copyWith(
                color: empty ? AppColors.warningOnSoft : AppColors.infoOnSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
