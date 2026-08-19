import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../stock/domain/entities/product.dart';
import '../../../stock/presentation/controllers/stock_providers.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier.dart';
import '../controllers/purchasing_providers.dart';

/// Création d'une commande fournisseur.
///
/// Choisir le fournisseur en premier n'est pas un détail : c'est lui qui
/// détermine le prix proposé sur chaque ligne. Un produit référencé chez ce
/// fournisseur reprend son prix catalogue ; sinon on retombe sur le dernier
/// prix d'achat connu du produit.
class OrderFormDialog extends ConsumerStatefulWidget {
  const OrderFormDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (BuildContext _) => const OrderFormDialog(),
    );
  }

  @override
  ConsumerState<OrderFormDialog> createState() => _OrderFormDialogState();
}

class _OrderFormDialogState extends ConsumerState<OrderFormDialog> {
  String? _supplierId;
  final Map<String, _DraftLine> _lines = <String, _DraftLine>{};
  bool _submitting = false;
  String? _error;

  /// Prix proposé pour un produit chez le fournisseur sélectionné.
  double _priceFor(Product product) {
    for (final ProductSupplier s in product.suppliers) {
      if (s.id == _supplierId) return s.unitPrice;
    }
    return product.averageCost;
  }

  void _addProduct(Product product) {
    setState(() {
      _lines[product.id] = _DraftLine(
        product: product,
        // Proposition de départ : de quoi remonter au stock maximum.
        quantity: product.quantityToOrder > 0 ? product.quantityToOrder : 1,
        unitPrice: _priceFor(product),
      );
      _error = null;
    });
  }

  double get _total => _lines.values.fold<double>(
        0,
        (double sum, _DraftLine l) => sum + l.total,
      );

  Future<void> _submit(List<Supplier> suppliers) async {
    if (_supplierId == null) {
      setState(() => _error = 'Choisissez un fournisseur.');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'Ajoutez au moins un produit à commander.');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final Supplier supplier =
        suppliers.firstWhere((Supplier s) => s.id == _supplierId);

    final PurchaseOrder created =
        await ref.read(orderControllerProvider.notifier).create(
              supplier: supplier,
              createdBy: ref.read(currentUserNameProvider),
              lines: _lines.values
                  .map(
                    (_DraftLine l) => OrderLine(
                      productId: l.product.id,
                      productName: l.product.name,
                      emoji: l.product.emoji,
                      unit: l.product.unit,
                      quantityOrdered: l.quantity,
                      unitPrice: l.unitPrice,
                    ),
                  )
                  .toList(),
            );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${created.reference} créée pour ${created.supplierName} — '
          '${Formatters.money(created.orderedTotal)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Supplier> suppliers = ref.watch(activeSuppliersProvider);
    final List<Product> products =
        ref.watch(stockControllerProvider).valueOrNull ?? const <Product>[];

    final List<Product> available = products
        .where((Product p) => !_lines.containsKey(p.id))
        .toList()
      ..sort((Product a, Product b) => a.name.compareTo(b.name));

    return FormDialog(
      title: 'Nouvelle commande',
      subtitle: 'Choisissez le fournisseur, puis les produits',
      width: 760,
      confirmLabel: 'Créer la commande',
      isSubmitting: _submitting,
      onConfirm: _submitting ? null : () => _submit(suppliers),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppDropdown<String>(
            label: 'Fournisseur',
            hint: 'Choisir…',
            value: _supplierId,
            items: suppliers.map((Supplier s) => s.id).toList(),
            labelBuilder: (String id) {
              final Supplier s =
                  suppliers.firstWhere((Supplier s) => s.id == id);
              return '${s.name}  ·  livraison sous ${s.deliveryDays} j';
            },
            onChanged: (String? value) => setState(() {
              _supplierId = value;
              _error = null;
              // Les prix dépendent du fournisseur : on les réaligne.
              for (final _DraftLine line in _lines.values) {
                line.unitPrice = _priceFor(line.product);
              }
            }),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text('Produits à commander',
                    style: AppTypography.labelStrong),
              ),
              SizedBox(
                width: 280,
                child: AppDropdown<String>(
                  hint: 'Ajouter un produit…',
                  value: null,
                  dense: true,
                  enabled: available.isNotEmpty,
                  items: available.map((Product p) => p.id).toList(),
                  labelBuilder: (String id) {
                    final Product p =
                        available.firstWhere((Product p) => p.id == id);
                    return '${p.emoji}  ${p.name}';
                  },
                  onChanged: (String? id) {
                    if (id == null) return;
                    _addProduct(
                      available.firstWhere((Product p) => p.id == id),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_lines.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.add_shopping_cart_rounded,
              title: 'Aucun produit',
              message: 'Ajoutez les produits à commander à ce fournisseur.',
            )
          else
            ..._lines.values.map(
              (_DraftLine line) => _DraftLineRow(
                line: line,
                onChanged: () => setState(() {}),
                onRemoved: () =>
                    setState(() => _lines.remove(line.product.id)),
              ),
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ],
          if (_lines.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            LabeledRow(
              label: 'Total de la commande',
              value: Formatters.money(_total),
              emphasized: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ligne en cours de saisie dans le formulaire.
class _DraftLine {
  _DraftLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  final Product product;
  double quantity;
  double unitPrice;

  double get total => quantity * unitPrice;
}

class _DraftLineRow extends StatelessWidget {
  const _DraftLineRow({
    required this.line,
    required this.onChanged,
    required this.onRemoved,
  });

  final _DraftLine line;
  final VoidCallback onChanged;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Text(line.product.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              line.product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMd,
            ),
          ),
          InlineNumberField(
            key: ValueKey<String>('qty-${line.product.id}'),
            value: line.quantity,
            suffix: line.product.unit,
            width: 120,
            onSubmitted: (double? value) {
              line.quantity = value ?? 0;
              onChanged();
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          InlineNumberField(
            key: ValueKey<String>('price-${line.product.id}'),
            value: line.unitPrice,
            suffix: 'MAD',
            width: 130,
            onSubmitted: (double? value) {
              line.unitPrice = value ?? 0;
              onChanged();
            },
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 100,
            child: Text(
              Formatters.amount(line.total),
              textAlign: TextAlign.right,
              style: AppTypography.numeric.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Retirer',
            size: 36,
            onPressed: onRemoved,
          ),
        ],
      ),
    );
  }
}
