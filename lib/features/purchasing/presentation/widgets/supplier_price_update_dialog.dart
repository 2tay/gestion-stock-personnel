import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../domain/usecases/receive_order.dart';

/// Propose de mettre à jour les tarifs fournisseurs après une réception dont
/// les prix ne correspondaient pas au catalogue.
///
/// Le point de cet écran est qu'il **demande**. Une promotion ponctuelle et
/// une hausse durable produisent exactement la même ligne de commande ; seul
/// l'utilisateur sait laquelle il vient de vivre. Appliquer d'office
/// reviendrait à enregistrer un tarif faux une fois sur deux — et l'ancien
/// code le faisait sans rien dire.
///
/// Les lignes sont cochées par défaut : le cas courant est bien une hausse
/// réelle, et refuser doit rester possible en un geste.
class SupplierPriceUpdateDialog extends StatefulWidget {
  const SupplierPriceUpdateDialog({required this.discrepancies, super.key});

  final List<SupplierPriceDiscrepancy> discrepancies;

  /// Renvoie les écarts que l'utilisateur veut appliquer. Liste vide s'il
  /// refuse ou ferme la boîte.
  static Future<List<SupplierPriceDiscrepancy>> show(
    BuildContext context, {
    required List<SupplierPriceDiscrepancy> discrepancies,
  }) async {
    final List<SupplierPriceDiscrepancy>? result =
        await FormDialog.show<List<SupplierPriceDiscrepancy>>(
      context,
      SupplierPriceUpdateDialog(discrepancies: discrepancies),
    );
    return result ?? const <SupplierPriceDiscrepancy>[];
  }

  @override
  State<SupplierPriceUpdateDialog> createState() =>
      _SupplierPriceUpdateDialogState();
}

class _SupplierPriceUpdateDialogState extends State<SupplierPriceUpdateDialog> {
  late final Set<String> _selected = <String>{
    for (final SupplierPriceDiscrepancy d in widget.discrepancies) d.productId,
  };

  @override
  Widget build(BuildContext context) {
    final int count = _selected.length;

    return FormDialog(
      title: 'Mettre à jour les tarifs ?',
      subtitle: widget.discrepancies.first.supplierName,
      width: 640,
      cancelLabel: 'Ignorer',
      confirmLabel: count == 0
          ? 'Aucun tarif à mettre à jour'
          : 'Mettre à jour $count tarif${count > 1 ? 's' : ''}',
      onConfirm: count == 0 ? null : _confirm,
      onCancel: () =>
          Navigator.of(context).pop(const <SupplierPriceDiscrepancy>[]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Les prix payés diffèrent des tarifs enregistrés. La réception '
            'est déjà enregistrée : il s’agit seulement de savoir si ces '
            'prix deviennent les nouveaux tarifs de référence.',
            style: AppTypography.bodyMd,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Une promotion ponctuelle ne devrait pas être retenue.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final SupplierPriceDiscrepancy d in widget.discrepancies)
            _DiscrepancyRow(
              discrepancy: d,
              selected: _selected.contains(d.productId),
              onChanged: (bool value) => setState(() {
                if (value) {
                  _selected.add(d.productId);
                } else {
                  _selected.remove(d.productId);
                }
              }),
            ),
        ],
      ),
    );
  }

  void _confirm() {
    Navigator.of(context).pop(
      widget.discrepancies
          .where((SupplierPriceDiscrepancy d) => _selected.contains(d.productId))
          .toList(),
    );
  }
}

class _DiscrepancyRow extends StatelessWidget {
  const _DiscrepancyRow({
    required this.discrepancy,
    required this.selected,
    required this.onChanged,
  });

  final SupplierPriceDiscrepancy discrepancy;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // Une hausse du prix d'achat est une mauvaise nouvelle : rouge.
    final Color color =
        discrepancy.isIncrease ? AppColors.danger : AppColors.success;
    final double? ratio = discrepancy.ratio;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => onChanged(!selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 32,
                  child: Checkbox(
                    value: selected,
                    onChanged: (bool? value) => onChanged(value ?? false),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(discrepancy.emoji, style: const TextStyle(fontSize: 17)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        discrepancy.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelStrong,
                      ),
                      Text(
                        'Tarif enregistré : '
                        '${Formatters.money(discrepancy.knownPrice)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      Formatters.money(discrepancy.paidPrice),
                      maxLines: 1,
                      style: AppTypography.numeric.copyWith(color: color),
                    ),
                    Text(
                      ratio == null
                          ? Formatters.signedMoney(discrepancy.difference)
                          : '${discrepancy.isIncrease ? '+' : '−'}'
                              '${Formatters.percent(ratio.abs() * 100)}',
                      maxLines: 1,
                      style: AppTypography.caption.copyWith(color: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
