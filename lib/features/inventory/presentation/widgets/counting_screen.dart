import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/inventory_line.dart';
import '../../domain/usecases/validate_inventory.dart';
import '../controllers/inventory_providers.dart';

/// Écran de comptage d'un inventaire.
///
/// Contrairement au module Stock, le comptage **remplace** la liste au lieu de
/// s'afficher à côté : c'est une tâche qui demande de la concentration et
/// toute la largeur de la tablette, pas une consultation.
class CountingScreen extends ConsumerWidget {
  const CountingScreen({required this.inventory, required this.onBack, super.key});

  final Inventory inventory;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _CountingHeader(inventory: inventory, onBack: onBack),
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: _CountingTable(inventory: inventory)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// En-tête : périmètre, avancement, écart courant
// ---------------------------------------------------------------------------

class _CountingHeader extends ConsumerWidget {
  const _CountingHeader({required this.inventory, required this.onBack});

  final Inventory inventory;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Retour à la liste',
                onPressed: onBack,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(inventory.reference, style: AppTypography.titleLg),
                        const SizedBox(width: AppSpacing.md),
                        StatusBadge.inventory(inventory.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inventory.scopeLabel} · ouvert le '
                      '${Formatters.date(inventory.createdAt)} '
                      'par ${inventory.createdBy}',
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),
              _CountingActions(inventory: inventory),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          _CountingSummary(inventory: inventory),
        ],
      ),
    );
  }
}

/// Avancement du comptage et écart valorisé courant.
class _CountingSummary extends StatelessWidget {
  const _CountingSummary({required this.inventory});

  final Inventory inventory;

  @override
  Widget build(BuildContext context) {
    final double variance = inventory.totalVarianceValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '${inventory.countedCount} / ${inventory.totalCount} '
                    'produits comptés',
                    style: AppTypography.labelStrong,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '(${Formatters.percent(inventory.progress * 100)})',
                    style: AppTypography.caption,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppProgressBar(value: inventory.progress),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xxl),
        LabeledValue(
          label: 'Lignes en écart',
          value: Formatters.integer(inventory.varianceCount),
          valueColor:
              inventory.varianceCount > 0 ? AppColors.warning : null,
        ),
        const SizedBox(width: AppSpacing.xxl),
        LabeledValue(
          label: 'Écart valorisé',
          value: Formatters.signedMoney(variance),
          valueColor: variance == 0
              ? AppColors.textPrimary
              : (variance > 0 ? AppColors.success : AppColors.danger),
        ),
      ],
    );
  }
}

/// Boutons d'action, dépendants du statut et des droits.
class _CountingActions extends ConsumerWidget {
  const _CountingActions({required this.inventory});

  final Inventory inventory;

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: 'Clôturer le comptage ?',
      message: inventory.remainingCount == 0
          ? 'Tous les produits ont été comptés. Le comptage sera figé et ne '
              'pourra plus être modifié sans être rouvert.'
          : '${inventory.remainingCount} produit'
              '${inventory.remainingCount > 1 ? 's' : ''} sur '
              '${inventory.totalCount} n’${inventory.remainingCount > 1 ? 'ont' : 'a'} '
              'pas été compté${inventory.remainingCount > 1 ? 's' : ''}. '
              'Le stock de ces produits restera inchangé.',
      confirmLabel: 'Clôturer',
      icon: Icons.lock_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(inventoryControllerProvider.notifier).close(inventory.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Comptage de ${inventory.reference} clôturé. '
          'Le stock n’a pas encore été modifié.',
        ),
      ),
    );
  }

  Future<void> _validate(BuildContext context, WidgetRef ref) async {
    final int adjustments = inventory.varianceCount;
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: 'Valider et appliquer les écarts ?',
      message: 'Cette opération est définitive.\n\n'
          '• $adjustments ajustement${adjustments > 1 ? 's' : ''} '
          'ser${adjustments > 1 ? 'ont' : 'a'} enregistré'
          '${adjustments > 1 ? 's' : ''} dans le stock\n'
          '• ${inventory.remainingCount} produit'
          '${inventory.remainingCount > 1 ? 's' : ''} non compté'
          '${inventory.remainingCount > 1 ? 's' : ''} — stock inchangé\n'
          '• Écart valorisé : '
          '${Formatters.signedMoney(inventory.totalVarianceValue)}',
      confirmLabel: 'Valider l’inventaire',
      destructive: true,
      icon: Icons.published_with_changes_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final InventoryValidationResult result =
        await ref.read(inventoryControllerProvider.notifier).validate(
              inventory,
              validatedBy: ref.read(currentUserNameProvider),
            );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${inventory.reference} validé — '
          '${result.adjustmentsApplied} ajustement'
          '${result.adjustmentsApplied > 1 ? 's' : ''} appliqué'
          '${result.adjustmentsApplied > 1 ? 's' : ''} au stock.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canValidate = ref.watch(canManageCatalogProvider);

    if (inventory.isFinal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.verified_rounded,
            size: AppSizes.iconMd,
            color: AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Validé le ${Formatters.date(inventory.validatedAt!)}',
            style: AppTypography.label,
          ),
        ],
      );
    }

    if (inventory.canValidate) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppButton.secondary(
            label: 'Rouvrir',
            icon: Icons.lock_open_rounded,
            onPressed: () => ref
                .read(inventoryControllerProvider.notifier)
                .reopen(inventory.id),
          ),
          const SizedBox(width: AppSpacing.md),
          AppButton.primary(
            label: 'Valider l’inventaire',
            icon: Icons.published_with_changes_rounded,
            // Seuls le patron et le manager appliquent les écarts au stock.
            onPressed: canValidate ? () => _validate(context, ref) : null,
            tooltip: canValidate
                ? null
                : 'Seul un manager ou le patron peut valider un inventaire',
          ),
        ],
      );
    }

    return AppButton.primary(
      label: 'Enregistrer le comptage',
      icon: Icons.check_rounded,
      onPressed:
          inventory.canClose ? () => _close(context, ref) : null,
      tooltip: inventory.canClose
          ? null
          : 'Comptez au moins un produit pour pouvoir clôturer',
    );
  }
}

// ---------------------------------------------------------------------------
// Tableau de comptage
// ---------------------------------------------------------------------------

class _CountingTable extends ConsumerWidget {
  const _CountingTable({required this.inventory});

  final Inventory inventory;

  /// Scanner un code-barres filtre la liste sur ce produit : la ligne
  /// devient la seule affichée, prête à être saisie.
  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final String? code = await ScannerSheet.show(
      context,
      title: 'Scanner un produit à compter',
    );
    if (code == null || !context.mounted) return;

    final Iterable<InventoryLine> match = inventory.lines
        .where((InventoryLine l) => l.barcode == code.trim());

    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aucun produit de cet inventaire ne correspond au code $code.',
          ),
        ),
      );
      return;
    }

    ref.read(countingQueryProvider.notifier).setSearch(match.first.productName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CountingQuery query = ref.watch(countingQueryProvider);
    final CountingQueryController controller =
        ref.read(countingQueryProvider.notifier);
    final List<InventoryLine> lines = ref.watch(visibleCountingLinesProvider);
    final bool editable = inventory.isCountable;

    return ListPageTemplate<InventoryLine, CountingFilter>(
      searchHint: 'Rechercher un produit…',
      onSearchChanged: controller.setSearch,
      selectedFilter: query.filter,
      onFilterChanged: controller.setFilter,
      headerActions: <Widget>[
        AppButton.soft(
          label: 'Scanner',
          icon: Icons.qr_code_scanner_rounded,
          onPressed: () => _scan(context, ref),
        ),
      ],
      filters: <FilterTab<CountingFilter>>[
        FilterTab<CountingFilter>(
          label: CountingFilter.tous.label,
          value: CountingFilter.tous,
          count: inventory.totalCount,
        ),
        FilterTab<CountingFilter>(
          label: CountingFilter.nonComptes.label,
          value: CountingFilter.nonComptes,
          count: inventory.remainingCount,
        ),
        FilterTab<CountingFilter>(
          label: CountingFilter.ecarts.label,
          value: CountingFilter.ecarts,
          count: inventory.varianceCount,
        ),
      ],
      rows: lines,
      rowKey: (InventoryLine l) => l.productId,
      emptyState: query.filter == CountingFilter.nonComptes
          ? const EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Tout est compté',
              message: 'Chaque produit de cet inventaire a une quantité '
                  'saisie. Vous pouvez clôturer le comptage.',
            )
          : const EmptyState.noResults(),
      columns: _columns(context, ref, editable: editable),
      footer: _CountingFooter(inventory: inventory, visible: lines.length),
    );
  }

  List<AppColumn<InventoryLine>> _columns(
    BuildContext context,
    WidgetRef ref, {
    required bool editable,
  }) {
    return <AppColumn<InventoryLine>>[
      AppColumn<InventoryLine>(
        label: 'Produit',
        flex: 4,
        sortValue: (InventoryLine l) => l.productName,
        cell: (InventoryLine l) => Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(l.emoji, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelStrong,
              ),
            ),
          ],
        ),
      ),
      AppColumn<InventoryLine>.text(
        label: 'Stock théorique',
        flex: 3,
        numeric: true,
        value: (InventoryLine l) =>
            Formatters.quantity(l.theoreticalStock, l.unit),
        sortValue: (InventoryLine l) => l.theoreticalStock,
      ),
      AppColumn<InventoryLine>(
        label: 'Stock réel',
        width: 150,
        alignment: Alignment.centerRight,
        sortValue: (InventoryLine l) => l.countedStock ?? -1,
        cell: (InventoryLine l) => InlineNumberField(
          key: ValueKey<String>('count-${l.productId}'),
          value: l.countedStock,
          suffix: l.unit,
          enabled: editable,
          onSubmitted: (double? value) => ref
              .read(inventoryControllerProvider.notifier)
              .saveCount(
                inventoryId: inventory.id,
                productId: l.productId,
                countedStock: value,
              ),
        ),
      ),
      AppColumn<InventoryLine>(
        label: 'Écart',
        width: 130,
        alignment: Alignment.centerRight,
        sortValue: (InventoryLine l) => l.variance ?? 0,
        cell: (InventoryLine l) => _VarianceCell(line: l),
      ),
    ];
  }
}

/// Cellule d'écart : neutre si non compté, verte ou rouge sinon.
class _VarianceCell extends StatelessWidget {
  const _VarianceCell({required this.line});

  final InventoryLine line;

  @override
  Widget build(BuildContext context) {
    if (!line.isCounted) {
      return Text('—', style: AppTypography.numeric.copyWith(
        color: AppColors.textTertiary,
      ));
    }

    final double variance = line.variance!;
    if (variance == 0) {
      return const StatusBadge(
        label: 'Conforme',
        tone: SemanticTone.success,
        dense: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          Formatters.signedQuantity(variance, line.unit),
          style: AppTypography.numeric.copyWith(
            fontWeight: FontWeight.w600,
            color: variance > 0 ? AppColors.success : AppColors.danger,
          ),
        ),
        Text(
          Formatters.signedMoney(line.varianceValue),
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

class _CountingFooter extends StatelessWidget {
  const _CountingFooter({required this.inventory, required this.visible});

  final Inventory inventory;
  final int visible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Text(
            '$visible ligne${visible > 1 ? 's' : ''} affichée'
            '${visible > 1 ? 's' : ''}',
            style: AppTypography.bodySm,
          ),
          const Spacer(),
          if (!inventory.isCountable)
            const StatusBadge(
              label: 'Comptage clos',
              tone: SemanticTone.neutral,
              dense: true,
            )
          else
            const Text(
              'La saisie est enregistrée automatiquement.',
              style: AppTypography.caption,
            ),
        ],
      ),
    );
  }
}
