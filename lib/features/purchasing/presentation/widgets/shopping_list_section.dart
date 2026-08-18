import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/shopping_item.dart';
import '../controllers/purchasing_providers.dart';

/// Section « À commander ».
///
/// Répond à la demande du cahier des charges : identifier les produits à
/// commander et en faire des listes de courses par fournisseur. La liste est
/// entièrement dérivée du stock et des commandes en cours — rien n'y est
/// saisi à la main.
class ShoppingListSection extends ConsumerWidget {
  const ShoppingListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ShoppingList> state =
        ref.watch(shoppingListControllerProvider);

    return state.when(
      loading: () => const AppCard(child: LoadingState()),
      error: (Object error, StackTrace _) => AppCard(
        child: ErrorState(
          onRetry: () =>
              ref.read(shoppingListControllerProvider.notifier).load(),
        ),
      ),
      data: (ShoppingList list) {
        if (list.isEmpty) {
          return AppCard(
            child: EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Rien à commander',
              message: list.coveredByPendingOrders > 0
                  ? 'Tous les produits sont au-dessus de leur seuil, ou déjà '
                      'couverts par une commande en cours '
                      '(${list.coveredByPendingOrders}).'
                  : 'Tous les produits sont au-dessus de leur seuil.',
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(list: list),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final ShoppingGroup group
                      in ref.watch(shoppingGroupsProvider))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: _SupplierGroupCard(group: group),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bandeau récapitulatif et génération globale.
class _Header extends ConsumerWidget {
  const _Header({required this.list});

  final ShoppingList list;

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final int suppliers = list.selectedItems
        .map((ShoppingItem i) => i.supplierId)
        .toSet()
        .length;

    final bool confirmed = await ConfirmDialog.show(
      context,
      title: 'Générer les commandes ?',
      message: '${list.selectedItems.length} produit'
          '${list.selectedItems.length > 1 ? 's' : ''} '
          'répartis sur $suppliers fournisseur${suppliers > 1 ? 's' : ''}.\n\n'
          'Une commande sera créée par fournisseur, pour un total de '
          '${Formatters.money(list.selectedTotal)}. Le stock ne bouge qu’à la '
          'réception.',
      confirmLabel: 'Générer',
      icon: Icons.playlist_add_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final List<PurchaseOrder> created =
        await ref.read(shoppingListControllerProvider.notifier).generateOrders(
              createdBy: ref.read(currentUserNameProvider),
            );
    if (!context.mounted) return;

    ref.read(purchasingSectionProvider.notifier).state =
        PurchasingSection.commandes;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${created.length} commande${created.length > 1 ? 's' : ''} créée'
          '${created.length > 1 ? 's' : ''} : '
          '${created.map((PurchaseOrder o) => o.reference).join(', ')}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canManage = ref.watch(canManageCatalogProvider);
    final ShoppingListController controller =
        ref.read(shoppingListControllerProvider.notifier);
    final int selected = list.selectedItems.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SectionHeader(
                  title: 'Produits à commander',
                  icon: Icons.add_shopping_cart_rounded,
                  iconColor: AppColors.modulePurchasing,
                  subtitle: '${list.items.length} produit'
                      '${list.items.length > 1 ? 's' : ''} sous leur seuil'
                      '${list.outOfStockCount > 0 ? ', dont '
                          '${list.outOfStockCount} en rupture' : ''}',
                ),
              ),
              AppButton.ghost(
                label: selected == list.items.length
                    ? 'Tout décocher'
                    : 'Tout cocher',
                onPressed: () =>
                    controller.selectAll(selected != list.items.length),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton.primary(
                label: 'Générer les commandes',
                icon: Icons.playlist_add_rounded,
                onPressed: canManage && selected > 0
                    ? () => _generate(context, ref)
                    : null,
                tooltip: canManage
                    ? (selected > 0 ? null : 'Cochez au moins un produit')
                    : 'Seul un manager ou le patron peut commander',
              ),
            ],
          ),
          if (list.coveredByPendingOrders > 0 ||
              list.withoutSupplierCount > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                if (list.coveredByPendingOrders > 0)
                  _Note(
                    icon: Icons.local_shipping_outlined,
                    tone: SemanticTone.info,
                    text: '${list.coveredByPendingOrders} produit'
                        '${list.coveredByPendingOrders > 1 ? 's' : ''} sous '
                        'seuil déjà couvert'
                        '${list.coveredByPendingOrders > 1 ? 's' : ''} par une '
                        'commande en cours',
                  ),
                if (list.coveredByPendingOrders > 0 &&
                    list.withoutSupplierCount > 0)
                  const SizedBox(width: AppSpacing.xl),
                if (list.withoutSupplierCount > 0)
                  _Note(
                    icon: Icons.help_outline_rounded,
                    tone: SemanticTone.warning,
                    text: '${list.withoutSupplierCount} produit'
                        '${list.withoutSupplierCount > 1 ? 's' : ''} sans '
                        'fournisseur associé',
                  ),
                const Spacer(),
                const Text('Total sélectionné', style: AppTypography.caption),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  Formatters.money(list.selectedTotal),
                  style: AppTypography.numeric.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.tone, required this.text});

  final IconData icon;
  final SemanticTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ToneColors colors = StatusBadge.toneColors(tone);
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppSizes.iconSm, color: colors.foreground),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              style: AppTypography.caption.copyWith(color: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un fournisseur et ses produits à commander.
class _SupplierGroupCard extends ConsumerWidget {
  const _SupplierGroupCard({required this.group});

  final ShoppingGroup group;

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final List<PurchaseOrder> created =
        await ref.read(shoppingListControllerProvider.notifier).generateOrders(
              createdBy: ref.read(currentUserNameProvider),
              onlySupplierId: group.supplierId,
            );
    if (!context.mounted || created.isEmpty) return;

    ref.read(purchasingSectionProvider.notifier).state =
        PurchasingSection.commandes;
    ref.read(selectedOrderIdProvider.notifier).state = created.first.id;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${created.first.reference} créée pour ${group.supplierName} — '
          '${Formatters.money(created.first.orderedTotal)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canManage = ref.watch(canManageCatalogProvider);
    final ShoppingListController controller =
        ref.read(shoppingListControllerProvider.notifier);

    return AppCard.flush(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SectionHeader(
              title: group.supplierName,
              subtitle: '${group.items.length} produit'
                  '${group.items.length > 1 ? 's' : ''}'
                  '${group.canOrder ? ' · ${Formatters.money(group.total)}' : ''}',
              icon: group.canOrder
                  ? Icons.local_shipping_outlined
                  : Icons.help_outline_rounded,
              iconColor:
                  group.canOrder ? AppColors.primary : AppColors.warning,
              actions: <Widget>[
                if (group.canOrder)
                  AppButton.secondary(
                    label: 'Générer la commande',
                    icon: Icons.playlist_add_rounded,
                    size: AppButtonSize.sm,
                    onPressed: canManage && group.selectedItems.isNotEmpty
                        ? () => _generate(context, ref)
                        : null,
                  )
                else
                  const StatusBadge(
                    label: 'Associez un fournisseur au produit',
                    tone: SemanticTone.warning,
                    dense: true,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          AppDataTable<ShoppingItem>(
            rows: group.items,
            minWidth: 900,
            rowHeight: 56,
            rowKey: (ShoppingItem i) => i.productId,
            columns: _columns(controller, enabled: canManage),
          ),
        ],
      ),
    );
  }

  List<AppColumn<ShoppingItem>> _columns(
    ShoppingListController controller, {
    required bool enabled,
  }) {
    return <AppColumn<ShoppingItem>>[
      AppColumn<ShoppingItem>(
        label: 'Produit',
        flex: 4,
        sortValue: (ShoppingItem i) => i.productName,
        cell: (ShoppingItem i) => Row(
          children: <Widget>[
            SizedBox(
              width: 32,
              child: Checkbox(
                value: i.isSelected,
                onChanged: enabled
                    ? (bool? value) =>
                        controller.setSelected(i.productId, value ?? false)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(i.emoji, style: const TextStyle(fontSize: 17)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                i.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelStrong,
              ),
            ),
          ],
        ),
      ),
      AppColumn<ShoppingItem>(
        label: 'Stock',
        flex: 3,
        alignment: Alignment.centerRight,
        sortValue: (ShoppingItem i) => i.currentStock,
        cell: (ShoppingItem i) => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              Formatters.quantity(i.currentStock, i.unit),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.numeric.copyWith(
                color: i.status == StockStatus.rupture
                    ? AppColors.danger
                    : AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'seuil ${Formatters.quantity(i.minStock, i.unit)}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
      AppColumn<ShoppingItem>(
        label: 'En attente',
        flex: 2,
        alignment: Alignment.centerRight,
        sortValue: (ShoppingItem i) => i.pendingQuantity,
        cell: (ShoppingItem i) => Text(
          i.pendingQuantity == 0
              ? '—'
              : Formatters.quantity(i.pendingQuantity, i.unit),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.numeric.copyWith(
            color: i.pendingQuantity == 0
                ? AppColors.textTertiary
                : AppColors.info,
          ),
        ),
      ),
      AppColumn<ShoppingItem>(
        label: 'À commander',
        width: 140,
        alignment: Alignment.centerRight,
        sortValue: (ShoppingItem i) => i.quantity,
        cell: (ShoppingItem i) => InlineNumberField(
          key: ValueKey<String>('order-qty-${i.productId}'),
          value: i.quantity,
          suffix: i.unit,
          enabled: enabled,
          onSubmitted: (double? value) =>
              controller.setQuantity(i.productId, value ?? 0),
        ),
      ),
      AppColumn<ShoppingItem>(
        label: 'Fournisseur',
        width: 190,
        cell: (ShoppingItem i) => i.hasAlternatives
            ? AppDropdown<String>(
                value: i.supplierId,
                dense: true,
                enabled: enabled,
                items: i.supplierOptions
                    .map((SupplierOption o) => o.id)
                    .toList(),
                labelBuilder: (String id) {
                  final SupplierOption o = i.supplierOptions
                      .firstWhere((SupplierOption o) => o.id == id);
                  return '${o.name} · ${Formatters.amount(o.unitPrice)}';
                },
                onChanged: (String? id) {
                  if (id != null) controller.setSupplier(i.productId, id);
                },
              )
            : Text(
                i.supplierName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySm,
              ),
      ),
      AppColumn<ShoppingItem>.text(
        label: 'Total',
        flex: 2,
        numeric: true,
        value: (ShoppingItem i) => Formatters.amount(i.total),
        sortValue: (ShoppingItem i) => i.total,
      ),
    ];
  }
}
