import 'package:flutter/material.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/theme.dart';
import '../atoms/app_card.dart';
import 'status_badge.dart';

/// Tuile d'indicateur du tableau de bord : « Valeur du stock 125 430,00 MAD »,
/// « Produits en stock 182 », « Stocks faibles 12 »…
class KpiCard extends StatelessWidget {
  const KpiCard({
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.tone = SemanticTone.neutral,
    this.trend,
    this.onTap,
    super.key,
  });

  final String label;

  /// Valeur déjà formatée (passer par `Formatters`).
  final String value;

  /// Suffixe discret affiché après la valeur, ex. `MAD`.
  final String? unit;
  final IconData? icon;

  /// Colore la valeur : `warning` pour les stocks faibles, etc.
  final SemanticTone tone;

  /// Variation en pourcentage. Positif = vert, négatif = rouge.
  final double? trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color valueColor = switch (tone) {
      SemanticTone.neutral => AppColors.textPrimary,
      SemanticTone.success => AppColors.success,
      SemanticTone.warning => AppColors.warning,
      SemanticTone.danger => AppColors.danger,
      SemanticTone.info => AppColors.info,
      SemanticTone.primary => AppColors.primary,
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null)
                Icon(icon, size: AppSizes.iconSm, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.numericLg.copyWith(color: valueColor),
                ),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Text(unit!, style: AppTypography.caption),
              ],
            ],
          ),
          if (trend != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _TrendPill(value: trend!),
          ],
        ],
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final bool up = value >= 0;
    return StatusBadge(
      dense: true,
      tone: up ? SemanticTone.success : SemanticTone.danger,
      label: '${up ? '+' : ''}${value.toStringAsFixed(1)} %',
    );
  }
}
