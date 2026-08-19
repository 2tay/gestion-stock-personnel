import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/shared.dart';
import '../../domain/entities/measurement_unit.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../controllers/stock_providers.dart';

/// Formulaire de création et d'édition d'un produit.
///
/// Le même dialogue sert aux deux cas : [product] à `null` crée, sinon
/// modifie. Le stock actuel n'est saisissable qu'à la création — ensuite il
/// ne peut évoluer que par un mouvement, pour préserver la traçabilité.
class ProductFormDialog extends ConsumerStatefulWidget {
  const ProductFormDialog({this.product, this.prefilledBarcode, super.key});

  final Product? product;

  /// Code-barres issu du scanner quand le produit n'a pas été reconnu.
  final String? prefilledBarcode;

  static Future<void> show(
    BuildContext context, {
    Product? product,
    String? prefilledBarcode,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (BuildContext _) => ProductFormDialog(
        product: product,
        prefilledBarcode: prefilledBarcode,
      ),
    );
  }

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _currentStock;
  late final TextEditingController _minStock;
  late final TextEditingController _maxStock;
  late final TextEditingController _unitPrice;
  late final TextEditingController _notes;

  String? _categoryId;
  String? _unit;
  String _emoji = '📦';
  bool _submitting = false;
  final Map<String, String> _errors = <String, String>{};

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final Product? p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(
      text: p?.barcode ?? widget.prefilledBarcode ?? '',
    );
    _currentStock = TextEditingController(
      text: p == null ? '' : _number(p.currentStock),
    );
    _minStock = TextEditingController(text: p == null ? '' : _number(p.minStock));
    _maxStock = TextEditingController(text: p == null ? '' : _number(p.maxStock));
    _unitPrice = TextEditingController(
      text: p == null ? '' : _number(p.averageCost),
    );
    _notes = TextEditingController(text: p?.notes ?? '');
    _categoryId = p?.categoryId;
    _unit = p?.unit;
    _emoji = p?.emoji ?? '📦';
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _currentStock.dispose();
    _minStock.dispose();
    _maxStock.dispose();
    _unitPrice.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  double _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  bool _validate() {
    final Map<String, String> errors = <String, String>{};
    if (_name.text.trim().isEmpty) {
      errors['name'] = 'Le nom du produit est obligatoire.';
    }
    if (_categoryId == null) errors['category'] = 'Choisissez une catégorie.';
    if (_unit == null) errors['unit'] = 'Choisissez une unité.';
    if (_parse(_maxStock) > 0 && _parse(_minStock) > _parse(_maxStock)) {
      errors['minStock'] = 'Le minimum doit être inférieur au maximum.';
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final List<ProductCategory> categories =
        ref.read(categoriesProvider).valueOrNull ?? const <ProductCategory>[];
    final ProductCategory category = categories.firstWhere(
      (ProductCategory c) => c.id == _categoryId,
    );

    final StockController controller =
        ref.read(stockControllerProvider.notifier);

    final Product product = Product(
      id: widget.product?.id ?? controller.nextProductId(),
      name: _name.text.trim(),
      emoji: _emoji,
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      categoryId: category.id,
      categoryName: category.name,
      unit: _unit!,
      currentStock:
          _isEditing ? widget.product!.currentStock : _parse(_currentStock),
      minStock: _parse(_minStock),
      maxStock: _parse(_maxStock),
      averageCost: _parse(_unitPrice),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      suppliers: widget.product?.suppliers ?? const <ProductSupplier>[],
    );

    setState(() => _submitting = true);
    await controller.save(product);
    if (!mounted) return;

    ref.read(selectedProductIdProvider.notifier).state = product.id;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Produit « ${product.name} » mis à jour.'
              : 'Produit « ${product.name} » créé.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ProductCategory> categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <ProductCategory>[];
    final List<MeasurementUnit> units =
        ref.watch(unitsProvider).valueOrNull ?? const <MeasurementUnit>[];

    return FormDialog(
      title: _isEditing ? 'Modifier le produit' : 'Nouveau produit',
      subtitle: _isEditing
          ? widget.product!.name
          : 'Renseignez les informations du produit',
      confirmLabel: _isEditing ? 'Enregistrer' : 'Créer le produit',
      isSubmitting: _submitting,
      onConfirm: _submitting ? null : _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _EmojiPicker(
                value: _emoji,
                onChanged: (String value) => setState(() => _emoji = value),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: AppTextField(
                  controller: _name,
                  label: 'Nom du produit',
                  hint: 'Ex. Tomate',
                  errorText: _errors['name'],
                  autofocus: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: AppDropdown<String>(
                  label: 'Catégorie',
                  hint: 'Choisir…',
                  value: _categoryId,
                  items: categories.map((ProductCategory c) => c.id).toList(),
                  labelBuilder: (String id) => categories
                      .firstWhere((ProductCategory c) => c.id == id)
                      .name,
                  onChanged: (String? v) => setState(() => _categoryId = v),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: AppDropdown<String>(
                  label: 'Unité',
                  hint: 'Choisir…',
                  value: _unit,
                  items: units.map((MeasurementUnit u) => u.code).toList(),
                  labelBuilder: (String code) => units
                      .firstWhere((MeasurementUnit u) => u.code == code)
                      .label,
                  onChanged: (String? v) => setState(() => _unit = v),
                ),
              ),
            ],
          ),
          if (_errors['category'] != null || _errors['unit'] != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _errors['category'] ?? _errors['unit']!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const _FieldGroupLabel('Niveaux de stock'),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: AppTextField.numeric(
                  controller: _currentStock,
                  label: 'Stock actuel',
                  hint: '0',
                  enabled: !_isEditing,
                  suffixText: _unit,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: AppTextField.numeric(
                  controller: _minStock,
                  label: 'Stock minimum',
                  hint: '0',
                  suffixText: _unit,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: AppTextField.numeric(
                  controller: _maxStock,
                  label: 'Stock maximum',
                  hint: '0',
                  suffixText: _unit,
                ),
              ),
            ],
          ),
          if (_isEditing) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Le stock actuel se modifie par une entrée, une sortie ou un '
              'inventaire, jamais directement.',
              style: AppTypography.caption,
            ),
          ],
          if (_errors['minStock'] != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _errors['minStock']!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const _FieldGroupLabel('Identification et prix'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _barcode,
                  label: 'Code-barres',
                  hint: 'Ex. 6111000000011',
                  prefixIcon: Icons.qr_code_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: AppTextField.numeric(
                  controller: _unitPrice,
                  // Saisi à la création, puis recalculé à chaque réception :
                  // ce n'est pas un tarif, c'est ce que vaut le stock détenu.
                  label: 'Coût unitaire moyen',
                  hint: '0,00',
                  suffixText: 'MAD',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _notes,
            label: 'Notes',
            hint: 'Conditions de conservation, remarques…',
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _FieldGroupLabel extends StatelessWidget {
  const _FieldGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTypography.labelStrong);
  }
}

/// Choix du pictogramme du produit dans une courte liste.
///
/// Un emoji plutôt qu'une photo : rien à téléverser, rien à télécharger,
/// cohérent avec le fonctionnement hors connexion.
class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const List<String> _choices = <String>[
    '📦', '🍅', '🧅', '🥔', '🥕', '🥒', '🥬', '🍋', '🌾', '🍚',
    '🫒', '🧂', '🥛', '🧈', '🧀', '🥚', '🥩', '🍗', '🐟', '🍞',
    '💧', '🥤', '☕', '🍬',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Pictogramme', style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs + 2),
        PopupMenuButton<String>(
          tooltip: 'Choisir un pictogramme',
          position: PopupMenuPosition.under,
          onSelected: onChanged,
          itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              enabled: false,
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 260,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Wrap(
                    children: <Widget>[
                      for (final String emoji in _choices)
                        InkWell(
                          onTap: () => Navigator.of(context).pop(emoji),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          child: Container(
            width: AppSizes.fieldHeight,
            height: AppSizes.fieldHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(value, style: const TextStyle(fontSize: 20)),
          ),
        ),
      ],
    );
  }
}
