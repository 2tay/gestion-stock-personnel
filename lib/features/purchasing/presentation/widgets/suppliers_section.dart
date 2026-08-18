import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../domain/entities/supplier.dart';
import '../controllers/purchasing_providers.dart';
import 'supplier_form_dialog.dart';

/// Section « Fournisseurs » du module Achats.
class SuppliersSection extends ConsumerStatefulWidget {
  const SuppliersSection({super.key});

  @override
  ConsumerState<SuppliersSection> createState() => _SuppliersSectionState();
}

class _SuppliersSectionState extends ConsumerState<SuppliersSection> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Supplier>> suppliers =
        ref.watch(supplierControllerProvider);
    final Map<String, int> orderCounts =
        ref.watch(orderCountBySupplierProvider);
    final bool canManage = ref.watch(canManageCatalogProvider);

    final String needle = _search.trim().toLowerCase();
    final List<Supplier> rows =
        (suppliers.valueOrNull ?? const <Supplier>[]).where((Supplier s) {
      if (needle.isEmpty) return true;
      return s.name.toLowerCase().contains(needle) ||
          (s.contactName?.toLowerCase().contains(needle) ?? false) ||
          (s.phone?.contains(needle) ?? false);
    }).toList()
          ..sort((Supplier a, Supplier b) => a.name.compareTo(b.name));

    return ListPageTemplate<Supplier, int>(
      searchHint: 'Rechercher un fournisseur…',
      onSearchChanged: (String value) => setState(() => _search = value),
      isLoading: suppliers.isLoading,
      headerActions: <Widget>[
        if (canManage)
          AppButton.primary(
            label: 'Nouveau fournisseur',
            icon: Icons.add_rounded,
            onPressed: () => SupplierFormDialog.show(context),
          ),
      ],
      rows: rows,
      rowKey: (Supplier s) => s.id,
      onRowTap: canManage
          ? (Supplier s) => SupplierFormDialog.show(context, supplier: s)
          : null,
      rowActions: canManage
          ? _rowActions(context, ref, orderCounts)
          : const <AppRowAction<Supplier>>[],
      emptyState: needle.isEmpty
          ? EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Aucun fournisseur',
              message: 'Créez vos fournisseurs pour pouvoir passer des '
                  'commandes.',
              actionLabel: canManage ? 'Nouveau fournisseur' : null,
              onAction:
                  canManage ? () => SupplierFormDialog.show(context) : null,
            )
          : const EmptyState.noResults(),
      columns: _columns(orderCounts),
      footer: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Text(
          '${Formatters.integer(rows.length)} fournisseur'
          '${rows.length > 1 ? 's' : ''}',
          style: AppTypography.bodySm,
        ),
      ),
    );
  }

  List<AppColumn<Supplier>> _columns(Map<String, int> orderCounts) {
    return <AppColumn<Supplier>>[
      AppColumn<Supplier>(
        label: 'Fournisseur',
        flex: 3,
        sortValue: (Supplier s) => s.name,
        cell: (Supplier s) => Row(
          children: <Widget>[
            AppAvatar(name: s.name, size: 30),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelStrong,
              ),
            ),
          ],
        ),
      ),
      AppColumn<Supplier>.text(
        label: 'Contact',
        flex: 3,
        value: (Supplier s) => s.contactLine,
      ),
      AppColumn<Supplier>.text(
        label: 'Règlement',
        flex: 2,
        value: (Supplier s) => s.paymentTerms ?? '—',
      ),
      AppColumn<Supplier>.text(
        label: 'Délai',
        width: 90,
        numeric: true,
        value: (Supplier s) => '${s.deliveryDays} j',
        sortValue: (Supplier s) => s.deliveryDays,
      ),
      AppColumn<Supplier>.text(
        label: 'Commandes',
        width: 110,
        numeric: true,
        value: (Supplier s) => Formatters.integer(orderCounts[s.id] ?? 0),
        sortValue: (Supplier s) => orderCounts[s.id] ?? 0,
      ),
      AppColumn<Supplier>(
        label: 'Statut',
        width: 100,
        cell: (Supplier s) => StatusBadge(
          dense: true,
          label: s.isActive ? 'Actif' : 'Inactif',
          tone: s.isActive ? SemanticTone.success : SemanticTone.neutral,
        ),
      ),
    ];
  }

  List<AppRowAction<Supplier>> _rowActions(
    BuildContext context,
    WidgetRef ref,
    Map<String, int> orderCounts,
  ) {
    return <AppRowAction<Supplier>>[
      AppRowAction<Supplier>(
        label: 'Modifier',
        icon: Icons.edit_outlined,
        onSelected: (Supplier s) =>
            SupplierFormDialog.show(context, supplier: s),
      ),
      AppRowAction<Supplier>(
        label: 'Supprimer',
        icon: Icons.delete_outline_rounded,
        destructive: true,
        // Un fournisseur qui a des commandes fait partie de l'historique :
        // on le désactive au lieu de le supprimer.
        isEnabled: (Supplier s) => (orderCounts[s.id] ?? 0) == 0,
        onSelected: (Supplier s) async {
          final bool confirmed = await ConfirmDialog.show(
            context,
            title: 'Supprimer ce fournisseur ?',
            message: '« ${s.name} » sera définitivement supprimé.',
            confirmLabel: 'Supprimer',
            destructive: true,
          );
          if (!confirmed) return;
          await ref.read(supplierControllerProvider.notifier).delete(s.id);
        },
      ),
    ];
  }
}
