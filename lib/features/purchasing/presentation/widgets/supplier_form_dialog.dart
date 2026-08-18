import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/shared.dart';
import '../../domain/entities/supplier.dart';
import '../controllers/purchasing_providers.dart';

/// Création et édition d'un fournisseur.
class SupplierFormDialog extends ConsumerStatefulWidget {
  const SupplierFormDialog({this.supplier, super.key});

  final Supplier? supplier;

  static Future<void> show(BuildContext context, {Supplier? supplier}) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (BuildContext _) => SupplierFormDialog(supplier: supplier),
    );
  }

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _paymentTerms;
  late final TextEditingController _deliveryDays;
  late final TextEditingController _notes;

  late bool _isActive;
  bool _submitting = false;
  String? _nameError;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final Supplier? s = widget.supplier;
    _name = TextEditingController(text: s?.name ?? '');
    _contact = TextEditingController(text: s?.contactName ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _email = TextEditingController(text: s?.email ?? '');
    _address = TextEditingController(text: s?.address ?? '');
    _paymentTerms = TextEditingController(text: s?.paymentTerms ?? '');
    _deliveryDays = TextEditingController(text: '${s?.deliveryDays ?? 1}');
    _notes = TextEditingController(text: s?.notes ?? '');
    _isActive = s?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _paymentTerms.dispose();
    _deliveryDays.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _trimmed(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Le nom du fournisseur est obligatoire.');
      return;
    }
    setState(() {
      _nameError = null;
      _submitting = true;
    });

    final SupplierController controller =
        ref.read(supplierControllerProvider.notifier);

    final Supplier supplier = Supplier(
      id: widget.supplier?.id ?? controller.nextSupplierId(),
      name: _name.text.trim(),
      contactName: _trimmed(_contact),
      phone: _trimmed(_phone),
      email: _trimmed(_email),
      address: _trimmed(_address),
      paymentTerms: _trimmed(_paymentTerms),
      deliveryDays: int.tryParse(_deliveryDays.text.trim()) ?? 1,
      isActive: _isActive,
      notes: _trimmed(_notes),
    );

    await controller.save(supplier);
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Fournisseur « ${supplier.name} » mis à jour.'
              : 'Fournisseur « ${supplier.name} » créé.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: _isEditing ? 'Modifier le fournisseur' : 'Nouveau fournisseur',
      subtitle: _isEditing
          ? widget.supplier!.name
          : 'Renseignez les coordonnées du fournisseur',
      confirmLabel: _isEditing ? 'Enregistrer' : 'Créer',
      isSubmitting: _submitting,
      onConfirm: _submitting ? null : _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTextField(
            controller: _name,
            label: 'Nom',
            hint: 'Ex. AgriPlus',
            errorText: _nameError,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _contact,
                  label: 'Contact',
                  hint: 'Nom de l’interlocuteur',
                  prefixIcon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: AppTextField(
                  controller: _phone,
                  label: 'Téléphone',
                  hint: '05 22 00 00 00',
                  prefixIcon: Icons.phone_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _email,
            label: 'Email',
            hint: 'commandes@fournisseur.ma',
            prefixIcon: Icons.mail_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _address,
            label: 'Adresse',
            hint: 'Ville, zone…',
            prefixIcon: Icons.place_outlined,
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('Conditions', style: AppTypography.labelStrong),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _paymentTerms,
                  label: 'Règlement',
                  hint: 'Ex. 30 jours fin de mois',
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: AppTextField.numeric(
                  controller: _deliveryDays,
                  label: 'Délai de livraison',
                  hint: '1',
                  suffixText: 'jours',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _notes,
            label: 'Notes',
            hint: 'Horaires de livraison, remarques…',
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile.adaptive(
            value: _isActive,
            onChanged: (bool value) => setState(() => _isActive = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('Fournisseur actif', style: AppTypography.bodyMd),
            subtitle: Text(
              _isActive
                  ? 'Proposé lors de la création d’une commande.'
                  : 'Masqué à la commande, conservé dans l’historique.',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}
