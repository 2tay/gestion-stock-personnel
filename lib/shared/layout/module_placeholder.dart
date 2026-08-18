import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../widgets/atoms/app_card.dart';
import '../widgets/molecules/state_views.dart';

/// Contenu temporaire d'un module dont l'interface sera construite lors
/// d'une phase ultérieure.
///
/// À supprimer au fur et à mesure : chaque page de module remplace son
/// [ModulePlaceholder] par son écran réel.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    required this.moduleName,
    required this.phase,
    required this.icon,
    this.accent = AppColors.primary,
    this.screens = const <String>[],
    super.key,
  });

  final String moduleName;

  /// Phase du plan de développement qui livrera cet écran.
  final String phase;

  final IconData icon;
  final Color accent;

  /// Écrans prévus pour ce module, listés à titre indicatif.
  final List<String> screens;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(icon, size: 28, color: accent),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(moduleName, style: AppTypography.titleLg),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Interface prévue en $phase.',
                style: AppTypography.bodySm,
              ),
              if (screens.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: <Widget>[
                      for (final String screen in screens)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.check_box_outline_blank_rounded,
                                size: AppSizes.iconSm,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  screen,
                                  style: AppTypography.bodySm,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const SkeletonBox(width: 220, height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
