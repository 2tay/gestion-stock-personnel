import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement.dart';
import '../controllers/stock_providers.dart';
import 'movement_form_dialog.dart';
import 'product_form_dialog.dart';
import 'product_name_cell.dart';
import 'stock_level_bar.dart';

/// Onglets de la fiche produit.
enum _DetailTab { mouvements, informations, fournisseurs }

/// Fiche produit affichée à droite de la liste.
///
/// Reprend la structure de la maquette : en-tête produit, blocs de niveaux
/// de stock, puis les onglets Mouvements / Informations / Fournisseurs.
class ProductDetailPanel extends ConsumerStatefulWidget {
  const ProductDetailPanel({required this.product, this.onClose, super.key});

  final Product product;
  final VoidCallback? onClose;

  @override
  ConsumerState<ProductDetailPanel> createState() => _ProductDetailPanelState();
}

class _ProductDetailPanelState extends ConsumerState<ProductDetailPanel> {
  _DetailTab _tab = _DetailTab.mouvements;

  Future<void> _confirmDelete() async {
    final bool confirmed = await ConfirmDialog.show(
      context,
      title: 'Supprimer ce produit ?',
      message: '« ${widget.product.name} » et son historique de mouvements '
          'seront définitivement supprimés.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await ref.read(stockControllerProvider.notifier).delete(widget.product.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('« ${widget.product.name} » supprimé.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Product product = widget.product;

    return DetailPanel(
      title: product.name,
      subtitle: product.categoryName,
      onClose: widget.onClose,
      headerTrailing: StatusBadge.stock(product.status),
      headerActions: <Widget>[
        AppIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Modifier le produit',
          size: 36,
          onPressed: () =>
              ProductFormDialog.show(context, product: product),
        ),
        AppIconButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Supprimer le produit',
          size: 36,
          onPressed: _confirmDelete,
        ),
      ],
      footer: Row(
        children: <Widget>[
          Expanded(
            child: AppButton.secondary(
              label: 'Sortie',
              icon: Icons.north_east_rounded,
              onPressed: () => MovementFormDialog.show(
                context,
                product: product,
                initialType: MovementType.sortie,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppButton.primary(
              label: 'Entrée de stock',
              icon: Icons.south_west_rounded,
              onPressed: () => MovementFormDialog.show(
                context,
                product: product,
                initialType: MovementType.entree,
              ),
            ),
          ),
        ],
      ),
      padding: EdgeInsets.zero,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _Summary(product: product),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: UnderlineTabs<_DetailTab>(
              selected: _tab,
              onSelected: (_DetailTab value) => setState(() => _tab = value),
              tabs: const <(_DetailTab, String)>[
                (_DetailTab.mouvements, 'Mouvements'),
                (_DetailTab.informations, 'Informations'),
                (_DetailTab.fournisseurs, 'Fournisseurs'),
              ],
            ),
          ),
          Expanded(
            child: switch (_tab) {
              _DetailTab.mouvements => _MovementsTab(product: product),
              _DetailTab.informations => _InformationsTab(product: product),
              _DetailTab.fournisseurs => _SuppliersTab(product: product),
            },
          ),
        ],
      ),
    );
  }
}

/// En-tête : pictogramme, stock actuel, jauge et seuils.
class _Summary extends StatelessWidget {
  const _Summary({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            ProductAvatar(emoji: product.emoji, size: 52),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Stock actuel', style: AppTypography.caption),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.quantity(product.currentStock, product.unit),
                    style: AppTypography.numericLg,
                  ),
                ],
              ),
            ),
            Flexible(
              child: LabeledValue(
                label: 'Valeur du stock',
                value: Formatters.money(product.stockValue),
                align: CrossAxisAlignment.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        StockLevelBar(product: product),
        if (product.status != StockStatus.ok) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _ReorderHint(product: product),
        ],
      ],
    );
  }
}

/// Bandeau d'alerte proposant la quantité à commander.
class _ReorderHint extends StatelessWidget {
  const _ReorderHint({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final bool isOut = product.status == StockStatus.rupture;
    final Color color = isOut ? AppColors.danger : AppColors.warning;
    final Color background = isOut ? AppColors.dangerSoft : AppColors.warningSoft;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isOut ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            size: AppSizes.iconMd,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              isOut
                  ? 'Produit en rupture. À commander : '
                      '${Formatters.quantity(product.quantityToOrder, product.unit)}.'
                  : 'Stock sous le seuil. À commander : '
                      '${Formatters.quantity(product.quantityToOrder, product.unit)}.',
              style: AppTypography.bodySm.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onglet « Mouvements » : historique des entrées, sorties et ajustements.
class _MovementsTab extends ConsumerWidget {
  const _MovementsTab({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StockMovement>> movements =
        ref.watch(productMovementsProvider(product.id));

    return movements.when(
      loading: () => const LoadingState(compact: true),
      error: (Object error, StackTrace _) => ErrorState(
        onRetry: () => ref.invalidate(productMovementsProvider(product.id)),
      ),
      data: (List<StockMovement> list) {
        if (list.isEmpty) {
          return const EmptyState(
            compact: true,
            icon: Icons.swap_vert_rounded,
            title: 'Aucun mouvement',
            message: 'Les entrées et sorties de ce produit apparaîtront ici.',
          );
        }

        return AppDataTable<StockMovement>(
          rows: list,
          shrinkWrap: false,
          minWidth: 480,
          rowKey: (StockMovement m) => m.id,
          columns: <AppColumn<StockMovement>>[
            AppColumn<StockMovement>.text(
              label: 'Date',
              flex: 2,
              value: (StockMovement m) => Formatters.date(m.date),
              sortValue: (StockMovement m) => m.date,
            ),
            AppColumn<StockMovement>(
              label: 'Type',
              width: 110,
              cell: (StockMovement m) => StatusBadge.movement(m.type),
            ),
            AppColumn<StockMovement>(
              label: 'Quantité',
              flex: 2,
              alignment: Alignment.centerRight,
              sortValue: (StockMovement m) => m.quantity,
              cell: (StockMovement m) => Text(
                Formatters.signedQuantity(m.quantity, product.unit),
                style: AppTypography.numeric.copyWith(
                  color: m.isIncoming ? AppColors.success : AppColors.danger,
                ),
              ),
            ),
            AppColumn<StockMovement>.text(
              label: 'Référence',
              flex: 2,
              value: (StockMovement m) => m.reference ?? '—',
            ),
            AppColumn<StockMovement>.text(
              label: 'Utilisateur',
              flex: 2,
              value: (StockMovement m) => m.user,
            ),
          ],
        );
      },
    );
  }
}

/// Onglet « Informations » : identification, seuils, notes.
class _InformationsTab extends StatelessWidget {
  const _InformationsTab({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: LabeledValue.boxed(
                  label: 'Catégorie',
                  value: product.categoryName,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: LabeledValue.boxed(
                  label: 'Unité',
                  value: product.unit,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: LabeledValue.boxed(
                  label: 'Prix d’achat',
                  value: Formatters.money(product.unitPrice),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: LabeledValue.boxed(
                  label: 'Stock minimum',
                  value: Formatters.quantity(product.minStock, product.unit),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: LabeledValue.boxed(
                  label: 'Stock maximum',
                  value: Formatters.quantity(product.maxStock, product.unit),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: LabeledValue.boxed(
                  label: 'Fournisseur principal',
                  value: product.primarySupplier?.name ?? '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Identification'),
          const SizedBox(height: AppSpacing.md),
          LabeledRow(
            label: 'Code-barres',
            value: product.barcode ?? 'Non renseigné',
          ),
          const Divider(),
          LabeledRow(label: 'Référence interne', value: product.id.toUpperCase()),
          const Divider(),
          LabeledRow(
            label: 'Dernière mise à jour',
            value: product.updatedAt == null
                ? '—'
                : Formatters.dateTime(product.updatedAt!),
          ),
          if (product.notes != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Notes'),
            const SizedBox(height: AppSpacing.sm),
            Text(product.notes!, style: AppTypography.bodyMd),
          ],
        ],
      ),
    );
  }
}

/// Onglet « Fournisseurs » : qui fournit ce produit, à quel prix.
class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    if (product.suppliers.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: Icons.local_shipping_outlined,
        title: 'Aucun fournisseur associé',
        message: 'Associez un fournisseur pour pouvoir commander ce produit.',
      );
    }

    return AppDataTable<ProductSupplier>(
      rows: product.suppliers,
      shrinkWrap: false,
      minWidth: 460,
      rowKey: (ProductSupplier s) => s.id,
      columns: <AppColumn<ProductSupplier>>[
        AppColumn<ProductSupplier>(
          label: 'Fournisseur',
          flex: 3,
          cell: (ProductSupplier s) => Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelStrong,
                ),
              ),
              if (s.isPrimary) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                const StatusBadge(
                  label: 'Principal',
                  tone: SemanticTone.primary,
                  dense: true,
                ),
              ],
            ],
          ),
        ),
        AppColumn<ProductSupplier>.text(
          label: 'Référence',
          flex: 2,
          value: (ProductSupplier s) => s.reference ?? '—',
        ),
        AppColumn<ProductSupplier>.text(
          label: 'Prix unitaire',
          flex: 2,
          numeric: true,
          value: (ProductSupplier s) => Formatters.money(s.unitPrice),
          sortValue: (ProductSupplier s) => s.unitPrice,
        ),
        AppColumn<ProductSupplier>.text(
          label: 'Délai',
          width: 90,
          numeric: true,
          value: (ProductSupplier s) => '${s.deliveryDays} j',
        ),
      ],
    );
  }
}
