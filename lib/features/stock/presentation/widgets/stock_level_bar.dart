import 'package:flutter/material.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/product.dart';

/// Jauge de niveau de stock : position du stock actuel entre 0 et le stock
/// maximum, avec le repère du seuil minimum.
///
/// Rend visible d'un coup d'œil ce que le badge de statut ne dit pas : de
/// combien on est au-dessus ou en dessous du seuil d'alerte.
class StockLevelBar extends StatelessWidget {
  const StockLevelBar({
    required this.product,
    this.showLegend = true,
    this.height = 8,
    super.key,
  });

  final Product product;
  final bool showLegend;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (product.status) {
      StockStatus.ok => AppColors.success,
      StockStatus.faible => AppColors.warning,
      StockStatus.rupture => AppColors.danger,
    };

    final double minRatio = product.maxStock <= 0
        ? 0
        : (product.minStock / product.maxStock).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            return SizedBox(
              height: height + 6,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  // Fond de la jauge.
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: AppColors.neutralSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  // Remplissage selon le stock actuel.
                  Container(
                    height: height,
                    width: width * product.fillRatio,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  // Repère du stock minimum.
                  Positioned(
                    left: (width * minRatio) - 1,
                    top: -3,
                    child: Container(
                      width: 2,
                      height: height + 6,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (showLegend) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              const Text('0', style: AppTypography.caption),
              const Spacer(),
              Text(
                'Seuil ${Formatters.quantity(product.minStock, product.unit)}',
                style: AppTypography.caption,
              ),
              const Spacer(),
              Text(
                Formatters.quantity(product.maxStock, product.unit),
                style: AppTypography.caption,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
