import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement.dart';
import '../controllers/stock_providers.dart';

/// Saisie d'une entrée, d'une sortie ou d'un ajustement de stock.
///
/// C'est le seul chemin pour faire varier le stock d'un produit hors
/// inventaire : la quantité, la raison et l'utilisateur sont enregistrés
/// ensemble, conformément à l'exigence de traçabilité.
/// Clé du champ de quantité, utilisée par les tests de widgets pour viser ce
/// champ précis plutôt que de compter les `TextField` de l'écran.
const Key quantityFieldKey = Key('movement-quantity-field');

class MovementFormDialog extends ConsumerStatefulWidget {
  const MovementFormDialog({
    required this.product,
    this.initialType = MovementType.entree,
    super.key,
  });

  final Product product;
  final MovementType initialType;

  static Future<void> show(
    BuildContext context, {
    required Product product,
    MovementType initialType = MovementType.entree,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (BuildContext _) => MovementFormDialog(
        product: product,
        initialType: initialType,
      ),
    );
  }

  @override
  ConsumerState<MovementFormDialog> createState() => _MovementFormDialogState();
}

class _MovementFormDialogState extends ConsumerState<MovementFormDialog> {
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _note = TextEditingController();

  late MovementType _type = widget.initialType;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _parsedQuantity =>
      double.tryParse(_quantity.text.trim().replaceAll(',', '.')) ?? 0;

  /// Quantité signée réellement appliquée au stock.
  double get _signedQuantity => switch (_type) {
        MovementType.entree => _parsedQuantity,
        MovementType.sortie => -_parsedQuantity,
        MovementType.ajustement => _parsedQuantity - widget.product.currentStock,
      };

  double get _resultingStock {
    final double result = widget.product.currentStock + _signedQuantity;
    return result < 0 ? 0 : result;
  }

  Future<void> _submit() async {
    if (_parsedQuantity <= 0 && _type != MovementType.ajustement) {
      setState(() => _error = 'Saisissez une quantité supérieure à zéro.');
      return;
    }
    if (_type == MovementType.sortie &&
        _parsedQuantity > widget.product.currentStock) {
      setState(
        () => _error = 'La sortie dépasse le stock disponible '
            '(${Formatters.quantity(widget.product.currentStock, widget.product.unit)}).',
      );
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final String user = ref.read(currentUserNameProvider);
    await ref.read(stockControllerProvider.notifier).registerMovement(
          StockMovement(
            id: '',
            productId: widget.product.id,
            date: DateTime.now(),
            type: _type,
            quantity: _signedQuantity,
            reference: _reference.text.trim().isEmpty
                ? _defaultReference
                : _reference.text.trim(),
            user: user,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_typeLabel enregistrée pour ${widget.product.name}.')),
    );
  }

  String get _defaultReference => switch (_type) {
        MovementType.entree => 'Réception',
        MovementType.sortie => 'Vente',
        MovementType.ajustement => 'Ajustement manuel',
      };

  String get _typeLabel => switch (_type) {
        MovementType.entree => 'Entrée',
        MovementType.sortie => 'Sortie',
        MovementType.ajustement => 'Correction',
      };

  @override
  Widget build(BuildContext context) {
    final Product product = widget.product;

    return FormDialog(
      title: 'Mouvement de stock',
      subtitle: product.name,
      width: 560,
      confirmLabel: 'Enregistrer le mouvement',
      isSubmitting: _submitting,
      onConfirm: _submitting ? null : _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Type de mouvement', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (final MovementType type in MovementType.values) ...<Widget>[
                Expanded(
                  child: _TypeOption(
                    type: type,
                    selected: _type == type,
                    onTap: () => setState(() {
                      _type = type;
                      _error = null;
                    }),
                  ),
                ),
                if (type != MovementType.values.last)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField.numeric(
            key: quantityFieldKey,
            controller: _quantity,
            autofocus: true,
            suffixText: product.unit,
            label: _type == MovementType.ajustement
                ? 'Stock réel constaté'
                : 'Quantité',
            hint: '0',
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _reference,
            label: 'Référence',
            hint: _defaultReference,
            prefixIcon: Icons.tag_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _note,
            label: 'Note',
            hint: 'Optionnel',
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.xl),
          _StockPreview(
            product: product,
            resultingStock: _resultingStock,
            delta: _signedQuantity,
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final MovementType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (String label, IconData icon, Color color) = switch (type) {
      MovementType.entree => (
          'Entrée',
          Icons.south_west_rounded,
          AppColors.success,
        ),
      MovementType.sortie => (
          'Sortie',
          Icons.north_east_rounded,
          AppColors.danger,
        ),
      MovementType.ajustement => (
          'Correction',
          Icons.tune_rounded,
          AppColors.neutral,
        ),
    };

    return Material(
      color: selected ? color.withValues(alpha: 0.1) : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: AppSizes.iconSm,
                color: selected ? color : AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelStrong.copyWith(
                    color: selected ? color : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Récapitulatif « stock actuel → stock après mouvement ».
class _StockPreview extends StatelessWidget {
  const _StockPreview({
    required this.product,
    required this.resultingStock,
    required this.delta,
  });

  final Product product;
  final double resultingStock;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final Color deltaColor = delta == 0
        ? AppColors.textTertiary
        : (delta > 0 ? AppColors.success : AppColors.danger);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: LabeledValue(
              label: 'Stock actuel',
              value: Formatters.quantity(product.currentStock, product.unit),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: AppSizes.iconMd,
              color: deltaColor,
            ),
          ),
          Expanded(
            child: LabeledValue(
              label: 'Après mouvement',
              value: Formatters.quantity(resultingStock, product.unit),
              valueColor: deltaColor,
              align: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }
}
