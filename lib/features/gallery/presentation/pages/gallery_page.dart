import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/shared.dart';
import '../../../auth/presentation/controllers/session_controller.dart';

/// Vitrine du design system.
///
/// Page interne de référence : elle montre chaque composant partagé dans ses
/// variantes. À consulter avant d'écrire un nouveau widget — si le composant
/// existe déjà ici, il ne doit pas être réécrit dans une feature.
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  String _filter = 'tous';
  ReportPeriod _period = ReportPeriod.last7Days;
  final TextEditingController _text = TextEditingController();
  String? _unit = 'kg';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Design system',
      subtitle: 'Référence visuelle des composants partagés',
      userName: ref.watch(currentUserNameProvider),
      body: ListView(
        children: <Widget>[
          _section(
            'Couleurs',
            const Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                _Swatch('primary', AppColors.primary),
                _Swatch('success', AppColors.success),
                _Swatch('warning', AppColors.warning),
                _Swatch('danger', AppColors.danger),
                _Swatch('neutral', AppColors.neutral),
                _Swatch('background', AppColors.background),
                _Swatch('border', AppColors.border),
                _Swatch('textPrimary', AppColors.textPrimary),
              ],
            ),
          ),
          _section(
            'Typographie',
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Display large', style: AppTypography.displayLg),
                Text('Titre large', style: AppTypography.titleLg),
                Text('Titre moyen', style: AppTypography.titleMd),
                Text('Corps de texte', style: AppTypography.bodyMd),
                Text('Texte secondaire', style: AppTypography.bodySm),
                Text('EN-TÊTE DE TABLEAU', style: AppTypography.tableHeader),
                Text('125 430,00', style: AppTypography.numericLg),
              ],
            ),
          ),
          _section(
            'Boutons',
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                AppButton.primary(
                  label: 'Nouveau produit',
                  icon: Icons.add_rounded,
                  onPressed: () {},
                ),
                AppButton.secondary(label: 'Modifier', onPressed: () {}),
                AppButton.danger(label: 'Pointer la fin', onPressed: () {}),
                AppButton.soft(
                  label: 'Scanner',
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () {},
                ),
                AppButton.ghost(
                  label: 'Voir tous les produits',
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: () {},
                ),
                const AppButton.primary(label: 'Désactivé', onPressed: null),
                AppButton.primary(
                  label: 'Chargement',
                  isLoading: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          _section(
            'Champs de saisie',
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: <Widget>[
                SizedBox(
                  width: 280,
                  child: AppTextField(
                    controller: _text,
                    label: 'Nom du produit',
                    hint: 'Ex. Tomate',
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: AppTextField.numeric(
                    label: 'Stock réel',
                    hint: '0',
                    suffixText: 'kg',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: AppDropdown<String>(
                    label: 'Unité',
                    value: _unit,
                    items: const <String>['kg', 'un.', 'L', 'g'],
                    labelBuilder: (String u) => u,
                    onChanged: (String? v) => setState(() => _unit = v),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: SearchField(
                    hint: 'Rechercher un produit…',
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(
                  width: 280,
                  child: AppTextField(
                    label: 'Champ en erreur',
                    errorText: 'Ce champ est obligatoire',
                  ),
                ),
              ],
            ),
          ),
          _section(
            'Badges de statut',
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final StockStatus s in StockStatus.values)
                  StatusBadge.stock(s),
                for (final OrderStatus s in OrderStatus.values)
                  StatusBadge.order(s),
                for (final AttendanceStatus s in AttendanceStatus.values)
                  StatusBadge.attendance(s),
                for (final MovementType m in MovementType.values)
                  StatusBadge.movement(m),
              ],
            ),
          ),
          _section(
            'Onglets de filtre',
            FilterTabs<String>(
              selected: _filter,
              onSelected: (String v) => setState(() => _filter = v),
              tabs: const <FilterTab<String>>[
                FilterTab<String>(label: 'Tous', value: 'tous', count: 182),
                FilterTab<String>(label: 'Catégories', value: 'cat'),
                FilterTab<String>(
                  label: 'Stock faible',
                  value: 'faible',
                  count: 12,
                ),
              ],
            ),
          ),
          _section(
            'Indicateurs',
            Row(
              children: <Widget>[
                Expanded(
                  child: KpiCard(
                    label: 'Valeur du stock',
                    value: Formatters.amount(125430),
                    unit: 'MAD',
                    icon: Icons.savings_outlined,
                    trend: 4.2,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                const Expanded(
                  child: KpiCard(
                    label: 'Produits en stock',
                    value: '182',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                const Expanded(
                  child: KpiCard(
                    label: 'Stocks faibles',
                    value: '12',
                    tone: SemanticTone.warning,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: PeriodSelector(
                    value: _period,
                    onChanged: (ReportPeriod p) => setState(() => _period = p),
                  ),
                ),
              ],
            ),
          ),
          _section(
            'Valeurs étiquetées',
            const Row(
              children: <Widget>[
                Expanded(
                  child: LabeledValue.boxed(
                    label: 'Stock minimum',
                    value: '40 kg',
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: LabeledValue.boxed(
                    label: 'Stock maximum',
                    value: '120 kg',
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: LabeledValue.boxed(
                    label: 'Fournisseur principal',
                    value: 'AgriPlus',
                  ),
                ),
              ],
            ),
          ),
          _section(
            'Tableau générique',
            AppDataTable<_DemoRow>(
              rows: _demoRows,
              onRowTap: (_) {},
              actions: <AppRowAction<_DemoRow>>[
                AppRowAction<_DemoRow>(
                  label: 'Modifier',
                  icon: Icons.edit_outlined,
                  onSelected: (_) {},
                ),
                AppRowAction<_DemoRow>(
                  label: 'Supprimer',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  onSelected: (_) {},
                ),
              ],
              columns: <AppColumn<_DemoRow>>[
                AppColumn<_DemoRow>.text(
                  label: 'Produit',
                  flex: 3,
                  value: (_DemoRow r) => r.name,
                  sortValue: (_DemoRow r) => r.name,
                  style: AppTypography.labelStrong,
                ),
                AppColumn<_DemoRow>.text(
                  label: 'Catégorie',
                  flex: 2,
                  value: (_DemoRow r) => r.category,
                ),
                AppColumn<_DemoRow>.text(
                  label: 'Stock',
                  numeric: true,
                  value: (_DemoRow r) => Formatters.quantity(r.stock, r.unit),
                  sortValue: (_DemoRow r) => r.stock,
                ),
                AppColumn<_DemoRow>(
                  label: 'Statut',
                  width: 110,
                  cell: (_DemoRow r) => StatusBadge.stock(r.status),
                ),
              ],
            ),
          ),
          _section(
            'États',
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: EmptyState.noResults(compact: true)),
                Expanded(child: ErrorState(compact: true)),
                Expanded(child: LoadingState(compact: true)),
              ],
            ),
          ),
          _section(
            'Dialogues',
            Wrap(
              spacing: AppSpacing.md,
              children: <Widget>[
                AppButton.secondary(
                  label: 'Formulaire',
                  onPressed: () => FormDialog.show<void>(
                    context,
                    FormDialog(
                      title: 'Nouveau produit',
                      subtitle: 'Renseignez les informations du produit',
                      onConfirm: () => Navigator.of(context).pop(),
                      child: const AppTextField(label: 'Nom du produit'),
                    ),
                  ),
                ),
                AppButton.secondary(
                  label: 'Confirmation',
                  onPressed: () => ConfirmDialog.show(
                    context,
                    title: 'Supprimer le produit ?',
                    message: 'Cette action est irréversible.',
                    destructive: true,
                  ),
                ),
                AppButton.secondary(
                  label: 'Scanner',
                  onPressed: () => ScannerSheet.show(context),
                ),
              ],
            ),
          ),
          _section(
            'Pagination',
            Paginator(
              page: 0,
              pageSize: 5,
              totalItems: 5,
              onPageChanged: (_) {},
            ),
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(title: title),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 96,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(name, style: AppTypography.caption),
      ],
    );
  }
}

class _DemoRow {
  const _DemoRow(this.name, this.category, this.stock, this.unit, this.status);

  final String name;
  final String category;
  final double stock;
  final String unit;
  final StockStatus status;
}

const List<_DemoRow> _demoRows = <_DemoRow>[
  _DemoRow('Tomate', 'Légumes', 95, 'kg', StockStatus.ok),
  _DemoRow('Oignon', 'Légumes', 50, 'kg', StockStatus.ok),
  _DemoRow('Pomme de terre', 'Légumes', 82, 'kg', StockStatus.ok),
  _DemoRow('Carotte', 'Légumes', 55, 'kg', StockStatus.faible),
  _DemoRow('Huile 5L', 'Épicerie', 25, 'un.', StockStatus.ok),
  _DemoRow('Riz 10kg', 'Épicerie', 38, 'un.', StockStatus.faible),
];
