import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../domain/entities/purchase_order.dart';
import '../controllers/purchasing_providers.dart';
import '../widgets/order_detail_panel.dart';
import '../widgets/order_form_dialog.dart';
import '../widgets/shopping_list_section.dart';
import '../widgets/suppliers_section.dart';

/// Module Courses & Achats.
///
/// Deux sections — Commandes et Fournisseurs — pour ne pas ajouter deux
/// entrées au rail de navigation, qui a été dimensionné pour sept.
class PurchasingPage extends ConsumerWidget {
  const PurchasingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PurchasingSection section = ref.watch(purchasingSectionProvider);
    final PurchaseOrder? selected = ref.watch(selectedOrderProvider);

    return AppScaffold(
      title: 'Courses & Achats',
      subtitle: 'Gérez vos fournisseurs, commandes et réceptions',
      userName: ref.watch(currentUserNameProvider),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: UnderlineTabs<PurchasingSection>(
              selected: section,
              onSelected: (PurchasingSection value) =>
                  ref.read(purchasingSectionProvider.notifier).state = value,
              tabs: <(PurchasingSection, String)>[
                for (final PurchasingSection s in PurchasingSection.values)
                  (s, s.label),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: switch (section) {
              PurchasingSection.aCommander => const ShoppingListSection(),
              PurchasingSection.commandes => MasterDetailLayout(
                  master: const _OrderListCard(),
                  detail: selected == null
                      ? null
                      : OrderDetailPanel(
                          key: ValueKey<String>(selected.id),
                          order: selected,
                          onClose: () => ref
                              .read(selectedOrderIdProvider.notifier)
                              .state = null,
                        ),
                ),
              PurchasingSection.fournisseurs => const SuppliersSection(),
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Liste des commandes
// ---------------------------------------------------------------------------

class _OrderListCard extends ConsumerWidget {
  const _OrderListCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OrderQuery query = ref.watch(orderQueryProvider);
    final OrderQueryController controller =
        ref.read(orderQueryProvider.notifier);
    final Map<OrderFilter, int> counters = ref.watch(orderCountersProvider);
    final AsyncValue<List<PurchaseOrder>> orders =
        ref.watch(visibleOrdersProvider);
    final List<PurchaseOrder> rows =
        orders.valueOrNull ?? const <PurchaseOrder>[];
    final bool canManage = ref.watch(canManageCatalogProvider);

    return ListPageTemplate<PurchaseOrder, OrderFilter>(
      searchHint: 'Rechercher une commande…',
      onSearchChanged: controller.setSearch,
      selectedFilter: query.filter,
      onFilterChanged: controller.setFilter,
      isLoading: orders.isLoading,
      headerActions: <Widget>[
        if (canManage)
          AppButton.primary(
            label: 'Nouvelle commande',
            icon: Icons.add_rounded,
            onPressed: () => OrderFormDialog.show(context),
          ),
      ],
      filters: <FilterTab<OrderFilter>>[
        for (final OrderFilter f in OrderFilter.values)
          FilterTab<OrderFilter>(label: f.label, value: f, count: counters[f]),
      ],
      rows: rows,
      rowKey: (PurchaseOrder o) => o.id,
      selectedRow: ref.watch(selectedOrderProvider),
      onRowTap: (PurchaseOrder o) =>
          ref.read(selectedOrderIdProvider.notifier).state = o.id,
      columns: _columns(),
      rowActions: _rowActions(context, ref, canManage: canManage),
      emptyState: query.search.isEmpty && query.filter == OrderFilter.toutes
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Aucune commande',
              message: 'Créez une commande pour réapprovisionner votre stock.',
              actionLabel: canManage ? 'Nouvelle commande' : null,
              onAction: canManage ? () => OrderFormDialog.show(context) : null,
            )
          : const EmptyState.noResults(),
      footer: _OrderFooter(orders: rows),
    );
  }

  List<AppColumn<PurchaseOrder>> _columns() {
    return <AppColumn<PurchaseOrder>>[
      AppColumn<PurchaseOrder>(
        label: 'N° Commande',
        flex: 3,
        sortValue: (PurchaseOrder o) => o.reference,
        cell: (PurchaseOrder o) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(o.reference, style: AppTypography.labelStrong),
            Text(
              '${o.lines.length} ligne${o.lines.length > 1 ? 's' : ''}',
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
      AppColumn<PurchaseOrder>.text(
        label: 'Fournisseur',
        flex: 3,
        value: (PurchaseOrder o) => o.supplierName,
        sortValue: (PurchaseOrder o) => o.supplierName,
      ),
      AppColumn<PurchaseOrder>.text(
        label: 'Date',
        flex: 2,
        value: (PurchaseOrder o) => Formatters.date(o.createdAt),
        sortValue: (PurchaseOrder o) => o.createdAt,
      ),
      AppColumn<PurchaseOrder>(
        label: 'Statut',
        width: 120,
        cell: (PurchaseOrder o) => StatusBadge.order(o.status),
      ),
      AppColumn<PurchaseOrder>(
        label: 'Réception',
        flex: 2,
        sortValue: (PurchaseOrder o) => o.progress,
        cell: (PurchaseOrder o) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: AppProgressBar(
            value: o.progress,
            height: 4,
            color: o.isFullyReceived ? AppColors.success : AppColors.primary,
          ),
        ),
      ),
      AppColumn<PurchaseOrder>.text(
        label: 'Total',
        flex: 2,
        numeric: true,
        value: (PurchaseOrder o) => Formatters.money(o.orderedTotal),
        sortValue: (PurchaseOrder o) => o.orderedTotal,
      ),
    ];
  }

  List<AppRowAction<PurchaseOrder>> _rowActions(
    BuildContext context,
    WidgetRef ref, {
    required bool canManage,
  }) {
    if (!canManage) return const <AppRowAction<PurchaseOrder>>[];

    return <AppRowAction<PurchaseOrder>>[
      AppRowAction<PurchaseOrder>(
        label: 'Ouvrir',
        icon: Icons.open_in_new_rounded,
        onSelected: (PurchaseOrder o) =>
            ref.read(selectedOrderIdProvider.notifier).state = o.id,
      ),
      AppRowAction<PurchaseOrder>(
        label: 'Annuler la commande',
        icon: Icons.cancel_outlined,
        destructive: true,
        isEnabled: (PurchaseOrder o) => o.canCancel,
        onSelected: (PurchaseOrder o) async {
          final bool confirmed = await ConfirmDialog.show(
            context,
            title: 'Annuler la commande ?',
            message: '${o.reference} sera marquée comme annulée. '
                'Le stock n’est pas affecté.',
            confirmLabel: 'Annuler la commande',
            cancelLabel: 'Revenir',
            destructive: true,
          );
          if (!confirmed) return;
          await ref.read(orderControllerProvider.notifier).cancel(o.id);
        },
      ),
      AppRowAction<PurchaseOrder>(
        label: 'Supprimer',
        icon: Icons.delete_outline_rounded,
        destructive: true,
        // Une commande qui a fait entrer de la marchandise fait partie de
        // l'historique du stock : elle ne se supprime pas.
        isEnabled: (PurchaseOrder o) => o.receivedQuantity == 0,
        onSelected: (PurchaseOrder o) async {
          final bool confirmed = await ConfirmDialog.show(
            context,
            title: 'Supprimer cette commande ?',
            message: '${o.reference} sera définitivement supprimée.',
            confirmLabel: 'Supprimer',
            destructive: true,
          );
          if (!confirmed) return;
          await ref.read(orderControllerProvider.notifier).delete(o.id);
        },
      ),
    ];
  }
}

class _OrderFooter extends StatelessWidget {
  const _OrderFooter({required this.orders});

  final List<PurchaseOrder> orders;

  @override
  Widget build(BuildContext context) {
    final int pending = orders
        .where(
          (PurchaseOrder o) =>
              o.status == OrderStatus.enCours ||
              o.status == OrderStatus.partielle,
        )
        .length;
    final double total = orders.fold<double>(
      0,
      (double sum, PurchaseOrder o) => sum + o.orderedTotal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Text(
            '${Formatters.integer(orders.length)} commande'
            '${orders.length > 1 ? 's' : ''}',
            style: AppTypography.bodySm,
          ),
          if (pending > 0) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            StatusBadge(
              dense: true,
              tone: SemanticTone.warning,
              label: '$pending en attente de livraison',
            ),
          ],
          const Spacer(),
          const Text('Total commandé', style: AppTypography.caption),
          const SizedBox(width: AppSpacing.sm),
          Text(Formatters.money(total), style: AppTypography.numeric),
        ],
      ),
    );
  }
}
