import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../domain/entities/inventory.dart';
import '../controllers/inventory_providers.dart';
import '../widgets/counting_screen.dart';
import '../widgets/inventory_form_dialog.dart';

/// Module Inventaire.
///
/// Deux écrans qui se remplacent : la liste des inventaires, et le comptage
/// d'un inventaire ouvert. Contrairement au module Stock, il n'y a pas de
/// panneau latéral — compter demande toute la largeur de la tablette.
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Inventory? selected = ref.watch(selectedInventoryProvider);

    void closeCounting() {
      ref.read(selectedInventoryIdProvider.notifier).state = null;
      ref.read(countingQueryProvider.notifier).reset();
    }

    return AppScaffold(
      title: 'Inventaire',
      subtitle: selected == null
          ? 'Réalisez vos inventaires et suivez les écarts'
          : 'Comptage en cours',
      userName: ref.watch(currentUserNameProvider),
      body: selected == null
          ? const _InventoryListCard()
          : CountingScreen(inventory: selected, onBack: closeCounting),
    );
  }
}

// ---------------------------------------------------------------------------
// Liste des inventaires
// ---------------------------------------------------------------------------

class _InventoryListCard extends ConsumerWidget {
  const _InventoryListCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InventoryQuery query = ref.watch(inventoryQueryProvider);
    final InventoryQueryController controller =
        ref.read(inventoryQueryProvider.notifier);
    final Map<InventoryFilter, int> counters =
        ref.watch(inventoryCountersProvider);
    final AsyncValue<List<Inventory>> inventories =
        ref.watch(visibleInventoriesProvider);
    final List<Inventory> rows = inventories.valueOrNull ?? const <Inventory>[];

    return ListPageTemplate<Inventory, InventoryFilter>(
      searchHint: 'Rechercher un inventaire…',
      onSearchChanged: controller.setSearch,
      selectedFilter: query.filter,
      onFilterChanged: controller.setFilter,
      isLoading: inventories.isLoading,
      headerActions: <Widget>[
        AppButton.primary(
          label: 'Nouvel inventaire',
          icon: Icons.add_rounded,
          onPressed: () => InventoryFormDialog.show(context),
        ),
      ],
      filters: <FilterTab<InventoryFilter>>[
        for (final InventoryFilter f in InventoryFilter.values)
          FilterTab<InventoryFilter>(
            label: f.label,
            value: f,
            count: counters[f],
          ),
      ],
      rows: rows,
      rowKey: (Inventory i) => i.id,
      onRowTap: (Inventory i) =>
          ref.read(selectedInventoryIdProvider.notifier).state = i.id,
      columns: _columns(),
      rowActions: _rowActions(context, ref),
      emptyState: query.search.isEmpty && query.filter == InventoryFilter.tous
          ? EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Aucun inventaire',
              message: 'Ouvrez un inventaire pour comparer votre stock réel '
                  'au stock théorique.',
              actionLabel: 'Nouvel inventaire',
              onAction: () => InventoryFormDialog.show(context),
            )
          : const EmptyState.noResults(),
      footer: _InventoryFooter(inventories: rows),
    );
  }

  List<AppColumn<Inventory>> _columns() {
    return <AppColumn<Inventory>>[
      AppColumn<Inventory>(
        label: 'Référence',
        flex: 3,
        sortValue: (Inventory i) => i.reference,
        cell: (Inventory i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(i.reference, style: AppTypography.labelStrong),
            Text(
              i.scopeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
      AppColumn<Inventory>.text(
        label: 'Date',
        flex: 2,
        value: (Inventory i) => Formatters.date(i.createdAt),
        sortValue: (Inventory i) => i.createdAt,
      ),
      AppColumn<Inventory>(
        label: 'Statut',
        width: 120,
        cell: (Inventory i) => StatusBadge.inventory(i.status),
      ),
      AppColumn<Inventory>(
        label: 'Avancement',
        flex: 3,
        sortValue: (Inventory i) => i.progress,
        cell: (Inventory i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${i.countedCount} / ${i.totalCount}',
              style: AppTypography.numeric.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 4),
            AppProgressBar(
              value: i.progress,
              height: 4,
              color: i.isFinal ? AppColors.success : AppColors.primary,
            ),
          ],
        ),
      ),
      AppColumn<Inventory>(
        label: 'Écart',
        flex: 2,
        alignment: Alignment.centerRight,
        sortValue: (Inventory i) => i.totalVarianceValue,
        cell: (Inventory i) => _VarianceLabel(inventory: i),
      ),
    ];
  }

  List<AppRowAction<Inventory>> _rowActions(
    BuildContext context,
    WidgetRef ref,
  ) {
    return <AppRowAction<Inventory>>[
      AppRowAction<Inventory>(
        label: 'Ouvrir le comptage',
        icon: Icons.list_alt_rounded,
        onSelected: (Inventory i) =>
            ref.read(selectedInventoryIdProvider.notifier).state = i.id,
      ),
      AppRowAction<Inventory>(
        label: 'Supprimer',
        icon: Icons.delete_outline_rounded,
        destructive: true,
        // Un inventaire validé a modifié le stock : il fait partie de
        // l'historique et ne peut plus être supprimé.
        isEnabled: (Inventory i) => !i.isFinal,
        onSelected: (Inventory i) async {
          final bool confirmed = await ConfirmDialog.show(
            context,
            title: 'Supprimer cet inventaire ?',
            message: '${i.reference} et son comptage seront définitivement '
                'supprimés. Le stock n’est pas affecté.',
            confirmLabel: 'Supprimer',
            destructive: true,
          );
          if (!confirmed) return;
          await ref.read(inventoryControllerProvider.notifier).delete(i.id);
        },
      ),
    ];
  }
}

/// Écart valorisé d'un inventaire, ou tiret tant que rien n'a été compté.
class _VarianceLabel extends StatelessWidget {
  const _VarianceLabel({required this.inventory});

  final Inventory inventory;

  @override
  Widget build(BuildContext context) {
    if (inventory.status == InventoryStatus.brouillon ||
        inventory.countedCount == 0) {
      return Text(
        '—',
        style: AppTypography.numeric.copyWith(color: AppColors.textTertiary),
      );
    }

    final double value = inventory.totalVarianceValue;
    return Text(
      Formatters.signedMoney(value),
      style: AppTypography.numeric.copyWith(
        fontWeight: FontWeight.w600,
        color: value == 0
            ? AppColors.textSecondary
            : (value > 0 ? AppColors.success : AppColors.danger),
      ),
    );
  }
}

class _InventoryFooter extends StatelessWidget {
  const _InventoryFooter({required this.inventories});

  final List<Inventory> inventories;

  @override
  Widget build(BuildContext context) {
    final int pending = inventories
        .where((Inventory i) => i.status == InventoryStatus.termine)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Affichage de ${Formatters.integer(inventories.length)} '
            'inventaire${inventories.length > 1 ? 's' : ''}',
            style: AppTypography.bodySm,
          ),
          if (pending > 0) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            StatusBadge(
              dense: true,
              tone: SemanticTone.warning,
              label: '$pending en attente de validation',
            ),
          ],
        ],
      ),
    );
  }
}
