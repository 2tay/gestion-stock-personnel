import 'package:flutter/material.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/theme/theme.dart';

/// Barre de progression fine : avancement d'un comptage d'inventaire,
/// réception partielle d'une commande, remplissage d'un objectif.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    this.color = AppColors.primary,
    this.background = AppColors.neutralSoft,
    this.height = 6,
    this.animate = true,
    super.key,
  });

  /// Avancement entre 0 et 1. Les valeurs hors bornes sont ramenées.
  final double value;

  final Color color;
  final Color background;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final double ratio = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget fill = Container(
              width: constraints.maxWidth * ratio,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            );

            return Stack(
              children: <Widget>[
                Container(color: background),
                if (animate)
                  AnimatedContainer(
                    duration: AppDurations.normal,
                    curve: Curves.easeOut,
                    width: constraints.maxWidth * ratio,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  )
                else
                  fill,
              ],
            );
          },
        ),
      ),
    );
  }
}
