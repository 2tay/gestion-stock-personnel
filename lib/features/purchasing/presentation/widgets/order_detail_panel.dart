import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/usecases/receive_order.dart';
import 'supplier_price_update_dialog.dart';
import '../controllers/purchasing_providers.dart';

/// Détail d'une commande et saisie de la réception.
///
/// Différence importante avec l'écran de comptage d'inventaire : ici la
/// saisie n'est **pas** enregistrée au fil de l'eau. Les quantités reçues
/// forment un brouillon local jusqu'à « Enregistrer la réception ». Une
/// réception est un acte comptable qui engage le stock et le fournisseur :
/// on la valide en bloc, pas ligne par ligne.
class OrderDetailPanel extends ConsumerStatefulWidget {
  const OrderDetailPanel({required this.order, this.onClose, super.key});

  final PurchaseOrder order;
  final VoidCallback? onClose;

  @override
  ConsumerState<OrderDetailPanel> createState() => _OrderDetailPanelState();
}

class _OrderDetailPanelState extends ConsumerState<OrderDetailPanel> {
  /// Quantités reçues en cours de saisie, par produit.
  late Map<String, double> _draft = _draftFrom(widget.order);

  bool _submitting = false;

  static Map<String, double> _draftFrom(PurchaseOrder order) {
    return <String, double>{
      for (final OrderLine line in order.lines)
        line.productId: line.quantityReceived,
    };
  }

  @override
  void didUpdateWidget(OrderDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La commande a changé (autre commande, ou réception enregistrée) :
    // le brouillon repart de l'état persisté.
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.receivedQuantity != widget.order.receivedQuantity ||
        oldWidget.order.lifecycle != widget.order.lifecycle) {
      _draft = _draftFrom(widget.order);
    }
  }

  /// Lignes dont la quantité saisie diffère de celle déjà enregistrée.
  List<OrderLine> get _changedLines => widget.order.lines
      .where(
        (OrderLine l) => (_draft[l.productId] ?? l.quantityReceived) !=
            l.quantityReceived,
      )
      .toList();

  bool get _hasChanges => _changedLines.isNotEmpty;

  /// Quantité qui va réellement entrer en stock si on valide maintenant.
  double get _incomingQuantity => _changedLines.fold<double>(
        0,
        (double sum, OrderLine l) =>
            sum + ((_draft[l.productId] ?? 0) - l.quantityReceived),
      );

  double get _incomingValue => _changedLines.fold<double>(
        0,
        (double sum, OrderLine l) =>
            sum +
            (((_draft[l.productId] ?? 0) - l.quantityReceived) * l.unitPrice),
      );

  void _receiveEverything() {
    setState(() {
      for (final OrderLine line in widget.order.lines) {
        _draft[line.productId] = line.quantityOrdered;
      }
    });
  }

  Future<void> _submitReception() async {
    final int lines = _changedLines.length;
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: 'Enregistrer la réception ?',
      message: 'Le stock va être mis à jour :\n\n'
          '• $lines ligne${lines > 1 ? 's' : ''} concernée'
          '${lines > 1 ? 's' : ''}\n'
          '• ${Formatters.signedQuantity(_incomingQuantity, 'unités')} '
          'au total\n'
          '• Valeur reçue : ${Formatters.money(_incomingValue)}\n\n'
          'Le coût moyen des produits sera recalculé à partir des prix de '
          'la commande.',
      confirmLabel: 'Enregistrer',
      icon: Icons.local_shipping_outlined,
    );
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    final OrderReceptionResult result =
        await ref.read(orderControllerProvider.notifier).receive(
              widget.order,
              receivedQuantities: Map<String, double>.of(_draft),
              receivedBy: ref.read(currentUserNameProvider),
            );
    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Réception enregistrée : ${result.linesReceived} ligne'
          '${result.linesReceived > 1 ? 's' : ''} entrée'
          '${result.linesReceived > 1 ? 's' : ''} en stock.',
        ),
      ),
    );

    // La réception est acquise. Reste une question distincte : ces prix
    // deviennent-ils les nouveaux tarifs ? On la pose, on ne la tranche pas.
    if (result.hasPriceDiscrepancies) {
      await _askAboutPrices(result);
    }
  }

  Future<void> _askAboutPrices(OrderReceptionResult result) async {
    final List<SupplierPriceDiscrepancy> accepted =
        await SupplierPriceUpdateDialog.show(
      context,
      discrepancies: result.priceDiscrepancies,
    );
    if (accepted.isEmpty || !mounted) return;

    await ref
        .read(orderControllerProvider.notifier)
        .applySupplierPrices(accepted);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${accepted.length} tarif${accepted.length > 1 ? 's' : ''} '
          'mis à jour.',
        ),
      ),
    );
  }

  Future<void> _cancelOrder() async {
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: 'Annuler la commande ?',
      message: '${widget.order.reference} sera marquée comme annulée. '
          'Aucune marchandise n’ayant été reçue, le stock n’est pas affecté.',
      confirmLabel: 'Annuler la commande',
      cancelLabel: 'Revenir',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(orderControllerProvider.notifier).cancel(widget.order.id);
  }

  Future<void> _closeOrder() async {
    final PurchaseOrder order = widget.order;
    final double remaining = order.orderedQuantity - order.receivedQuantity;
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: 'Solder la commande ?',
      message: 'Il reste ${Formatters.integer(remaining)} unités non livrées '
          'sur ${order.reference}. Solder la commande abandonne ce reliquat : '
          'ce qui a été reçu reste en stock, et on n’attend plus rien.',
      confirmLabel: 'Solder',
      icon: Icons.playlist_add_check_rounded,
    );
    if (!confirmed || !mounted) return;
    await ref.read(orderControllerProvider.notifier).close(order.id);
  }

  @override
  Widget build(BuildContext context) {
    final PurchaseOrder order = widget.order;
    final bool canManage = ref.watch(canManageCatalogProvider);
    final bool receivable = order.isReceivable && canManage;

    return DetailPanel(
      title: 'Commande ${order.reference}',
      subtitle: order.supplierName,
      onClose: widget.onClose,
      headerTrailing: StatusBadge.order(order.status),
      padding: EdgeInsets.zero,
      scrollable: false,
      footer: _Footer(
        order: order,
        canManage: canManage,
        hasChanges: _hasChanges,
        submitting: _submitting,
        onReceive: _submitReception,
        onReceiveAll: _receiveEverything,
        onCancel: _cancelOrder,
        onClose: _closeOrder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _Summary(order: order),
          ),
          const Divider(height: 1),
          Expanded(
            child: AppDataTable<OrderLine>(
              rows: order.lines,
              shrinkWrap: false,
              minWidth: 620,
              rowHeight: 56,
              rowKey: (OrderLine l) => l.productId,
              columns: _columns(receivable: receivable),
            ),
          ),
          const Divider(height: 1),
          _Totals(order: order),
        ],
      ),
    );
  }

  List<AppColumn<OrderLine>> _columns({required bool receivable}) {
    return <AppColumn<OrderLine>>[
      AppColumn<OrderLine>(
        label: 'Produit',
        flex: 4,
        sortValue: (OrderLine l) => l.productName,
        cell: (OrderLine l) => Row(
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
      AppColumn<OrderLine>.text(
        label: 'Qté commandée',
        flex: 3,
        numeric: true,
        value: (OrderLine l) => Formatters.quantity(l.quantityOrdered, l.unit),
        sortValue: (OrderLine l) => l.quantityOrdered,
      ),
      AppColumn<OrderLine>(
        label: 'Qté reçue',
        width: 150,
        alignment: Alignment.centerRight,
        sortValue: (OrderLine l) => l.quantityReceived,
        cell: (OrderLine l) => InlineNumberField(
          key: ValueKey<String>('received-${l.productId}'),
          value: _draft[l.productId],
          suffix: l.unit,
          enabled: receivable,
          hint: '0',
          onSubmitted: (double? value) => setState(
            () => _draft[l.productId] = value ?? 0,
          ),
        ),
      ),
      AppColumn<OrderLine>.text(
        label: 'Prix unitaire',
        flex: 3,
        numeric: true,
        value: (OrderLine l) => Formatters.money(l.unitPrice),
        sortValue: (OrderLine l) => l.unitPrice,
      ),
      AppColumn<OrderLine>(
        label: 'Total reçu',
        flex: 3,
        alignment: Alignment.centerRight,
        sortValue: (OrderLine l) => l.receivedTotal,
        cell: (OrderLine l) => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Une seule ligne chacun : dans un panneau étroit, un montant
            // qui passe à la ligne fait déborder la hauteur de ligne.
            Text(
              Formatters.amount(l.receivedTotal),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.numeric.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!l.isFullyReceived)
              Text(
                'reste ${Formatters.quantity(l.remaining, l.unit)}',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.warning,
                ),
              )
            else if (l.isOverDelivered)
              Text(
                'sur-livré',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.info,
                ),
              ),
          ],
        ),
      ),
    ];
  }
}

/// Bandeau fournisseur / date / avancement.
class _Summary extends StatelessWidget {
  const _Summary({required this.order});

  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: LabeledValue.boxed(
                label: 'Fournisseur',
                value: order.supplierName,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: LabeledValue.boxed(
                label: 'Date',
                value: Formatters.date(order.createdAt),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: LabeledValue.boxed(
                label: 'Livraison prévue',
                value: order.expectedAt == null
                    ? '—'
                    : Formatters.date(order.expectedAt!),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Text(
              '${Formatters.integer(order.receivedQuantity)} / '
              '${Formatters.integer(order.orderedQuantity)} unités reçues',
              style: AppTypography.label,
            ),
            const Spacer(),
            if (order.pendingLineCount > 0)
              StatusBadge(
                dense: true,
                tone: SemanticTone.warning,
                label: '${order.pendingLineCount} ligne'
                    '${order.pendingLineCount > 1 ? 's' : ''} en attente',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgressBar(
          value: order.progress,
          color: order.isFullyReceived ? AppColors.success : AppColors.primary,
        ),
      ],
    );
  }
}

/// Totaux : ce qui a été engagé, ce qui a été livré.
class _Totals extends StatelessWidget {
  const _Totals({required this.order});

  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: LabeledValue(
              label: 'Total commandé',
              value: Formatters.money(order.orderedTotal),
            ),
          ),
          Expanded(
            child: LabeledValue(
              label: 'Total reçu',
              value: Formatters.money(order.receivedTotal),
              valueColor: order.isFullyReceived ? AppColors.success : null,
              align: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre d'actions, dépendante du statut et des droits.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.order,
    required this.canManage,
    required this.hasChanges,
    required this.submitting,
    required this.onReceive,
    required this.onReceiveAll,
    required this.onCancel,
    required this.onClose,
  });

  final PurchaseOrder order;
  final bool canManage;
  final bool hasChanges;
  final bool submitting;
  final VoidCallback onReceive;
  final VoidCallback onReceiveAll;
  final VoidCallback onCancel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (!order.isReceivable) {
      return Row(
        children: <Widget>[
          Icon(
            order.status == OrderStatus.annulee
                ? Icons.cancel_outlined
                : Icons.check_circle_outline_rounded,
            size: AppSizes.iconMd,
            color: order.status == OrderStatus.annulee
                ? AppColors.danger
                : AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              switch (order.status) {
                OrderStatus.annulee => 'Commande annulée.',
                OrderStatus.soldee =>
                  'Commande soldée : le reliquat a été abandonné.',
                _ => 'Commande close.',
              },
              style: AppTypography.bodySm,
            ),
          ),
        ],
      );
    }

    final Widget? secondary = order.canCancel
        ? AppButton.secondary(
            label: 'Annuler',
            onPressed: canManage ? onCancel : null,
          )
        : (order.canClose
            ? AppButton.secondary(
                label: 'Solder',
                icon: Icons.playlist_add_check_rounded,
                onPressed: canManage ? onClose : null,
                tooltip: 'Clore la commande en abandonnant le reliquat',
              )
            : null);

    final Widget? receiveAll = order.isFullyReceived
        ? null
        : AppButton.ghost(
            label: 'Tout recevoir',
            onPressed: canManage ? onReceiveAll : null,
          );

    final Widget confirm = AppButton.primary(
      label: 'Enregistrer la réception',
      icon: Icons.local_shipping_outlined,
      isLoading: submitting,
      onPressed: canManage && hasChanges ? onReceive : null,
      tooltip: !canManage
          ? 'Seul un manager ou le patron peut enregistrer une réception'
          : (hasChanges ? null : 'Aucune quantité modifiée'),
    );

    // Le panneau de détail est étroit : trois boutons ne tiennent pas
    // toujours côte à côte. En dessous du seuil, on empile plutôt que de
    // tronquer des libellés d'action.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Seuil mesuré sur les libellés les plus longs de cette barre
        // (« Enregistrer la réception » + « Tout recevoir » + « Solder »).
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              confirm,
              if (receiveAll != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                receiveAll,
              ],
              if (secondary != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                secondary,
              ],
            ],
          );
        }

        return Row(
          children: <Widget>[
            ?secondary,
            const Spacer(),
            if (receiveAll != null) ...<Widget>[
              Flexible(child: receiveAll),
              const SizedBox(width: AppSpacing.md),
            ],
            Flexible(child: confirm),
          ],
        );
      },
    );
  }
}
