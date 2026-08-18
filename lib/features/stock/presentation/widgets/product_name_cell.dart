import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/entities/product.dart';

/// Cellule « Produit » du tableau : pictogramme + nom, comme dans la maquette.
class ProductNameCell extends StatelessWidget {
  const ProductNameCell({
    required this.product,
    this.showBarcode = false,
    super.key,
  });

  final Product product;

  /// Affiche le code-barres en seconde ligne (résultats de scan).
  final bool showBarcode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ProductAvatar(emoji: product.emoji),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelStrong,
              ),
              if (showBarcode && product.barcode != null)
                Text(product.barcode!, style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pastille carrée contenant le pictogramme d'un produit.
class ProductAvatar extends StatelessWidget {
  const ProductAvatar({required this.emoji, this.size = 30, super.key});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.52)),
    );
  }
}
