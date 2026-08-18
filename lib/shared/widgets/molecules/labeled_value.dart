import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Couple libellé / valeur encadré, comme dans les fiches de la maquette :
/// « Stock minimum 40 kg », « Fournisseur principal AgriPlus »,
/// « Heures travaillées 04:28 ».
class LabeledValue extends StatelessWidget {
  const LabeledValue({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
    this.boxed = false,
    this.icon,
    this.align = CrossAxisAlignment.start,
    super.key,
  });

  /// Variante encadrée sur fond gris clair (blocs de la fiche produit).
  const LabeledValue.boxed({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
    this.icon,
    this.align = CrossAxisAlignment.start,
    super.key,
  }) : boxed = true;

  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;
  final bool boxed;
  final IconData? icon;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.xs + 2),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(
          value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: (valueStyle ?? AppTypography.titleSm).copyWith(
            color: valueColor,
          ),
        ),
      ],
    );

    if (!boxed) return content;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: content,
    );
  }
}

/// Ligne « libellé ......... valeur », pour les récapitulatifs (totaux de
/// commande, informations fournisseur).
class LabeledRow extends StatelessWidget {
  const LabeledRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
    super.key,
  });

  final String label;
  final String value;

  /// Met la ligne en gras : ligne de total.
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: emphasized ? AppTypography.labelStrong : AppTypography.label,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Text(
            value,
            style: (emphasized
                    ? AppTypography.numeric.copyWith(fontWeight: FontWeight.w700)
                    : AppTypography.numeric)
                .copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}
