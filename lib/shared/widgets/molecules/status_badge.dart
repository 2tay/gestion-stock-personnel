import 'package:flutter/material.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/theme/theme.dart';

/// Étiquette d'état non cliquable : « OK », « Faible », « En cours »,
/// « Terminé », « Reçue », « Pointé »…
///
/// Un seul composant pour tous les modules : la traduction d'un enum métier
/// vers un couple (libellé, tonalité) vit ici et nulle part ailleurs.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.tone,
    this.dense = false,
    this.showDot = false,
    super.key,
  });

  StatusBadge.stock(StockStatus status, {this.dense = false, super.key})
      : showDot = false,
        label = switch (status) {
          StockStatus.ok => 'OK',
          StockStatus.faible => 'Faible',
          StockStatus.rupture => 'Rupture',
        },
        tone = switch (status) {
          StockStatus.ok => SemanticTone.success,
          StockStatus.faible => SemanticTone.warning,
          StockStatus.rupture => SemanticTone.danger,
        };

  StatusBadge.inventory(InventoryStatus status, {this.dense = false, super.key})
      : showDot = false,
        label = switch (status) {
          InventoryStatus.brouillon => 'Brouillon',
          InventoryStatus.enCours => 'En cours',
          InventoryStatus.termine => 'Terminé',
          InventoryStatus.valide => 'Validé',
        },
        tone = switch (status) {
          InventoryStatus.brouillon => SemanticTone.neutral,
          InventoryStatus.enCours => SemanticTone.info,
          InventoryStatus.termine => SemanticTone.success,
          InventoryStatus.valide => SemanticTone.primary,
        };

  StatusBadge.order(OrderStatus status, {this.dense = false, super.key})
      : showDot = false,
        label = switch (status) {
          OrderStatus.brouillon => 'Brouillon',
          OrderStatus.enCours => 'En cours',
          OrderStatus.partielle => 'Partielle',
          OrderStatus.recue => 'Reçue',
          OrderStatus.annulee => 'Annulée',
        },
        tone = switch (status) {
          OrderStatus.brouillon => SemanticTone.neutral,
          OrderStatus.enCours => SemanticTone.info,
          OrderStatus.partielle => SemanticTone.warning,
          OrderStatus.recue => SemanticTone.success,
          OrderStatus.annulee => SemanticTone.danger,
        };

  StatusBadge.attendance(
    AttendanceStatus status, {
    this.dense = false,
    super.key,
  })  : showDot = false,
        label = switch (status) {
          AttendanceStatus.pointe => 'Pointé',
          AttendanceStatus.enPause => 'En pause',
          AttendanceStatus.termine => 'Terminé',
          AttendanceStatus.absent => 'Absent',
        },
        tone = switch (status) {
          AttendanceStatus.pointe => SemanticTone.success,
          AttendanceStatus.enPause => SemanticTone.warning,
          AttendanceStatus.termine => SemanticTone.neutral,
          AttendanceStatus.absent => SemanticTone.danger,
        };

  StatusBadge.movement(MovementType type, {this.dense = false, super.key})
      : showDot = false,
        label = switch (type) {
          MovementType.entree => 'Entrée',
          MovementType.sortie => 'Sortie',
          MovementType.ajustement => 'Ajustement',
        },
        tone = switch (type) {
          MovementType.entree => SemanticTone.success,
          MovementType.sortie => SemanticTone.danger,
          MovementType.ajustement => SemanticTone.neutral,
        };

  final String label;
  final SemanticTone tone;
  final bool dense;

  /// Ajoute un point de couleur avant le libellé.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final ToneColors c = toneColors(tone);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md - 2,
        vertical: dense ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showDot) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: c.foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm - 2),
          ],
          Text(
            label,
            style: AppTypography.badge.copyWith(
              color: c.foreground,
              fontSize: dense ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Mapping tonalité -> couleurs. Réutilisé par les alertes et indicateurs.
  static ToneColors toneColors(SemanticTone tone) => switch (tone) {
        SemanticTone.success => const ToneColors(
            AppColors.successSoft,
            AppColors.successOnSoft,
          ),
        SemanticTone.warning => const ToneColors(
            AppColors.warningSoft,
            AppColors.warningOnSoft,
          ),
        SemanticTone.danger => const ToneColors(
            AppColors.dangerSoft,
            AppColors.dangerOnSoft,
          ),
        SemanticTone.info => const ToneColors(
            AppColors.infoSoft,
            AppColors.infoOnSoft,
          ),
        SemanticTone.primary => const ToneColors(
            AppColors.primarySoft,
            AppColors.primaryOnSoft,
          ),
        SemanticTone.neutral => const ToneColors(
            AppColors.neutralSoft,
            AppColors.neutralOnSoft,
          ),
      };
}

/// Couple (fond, texte) associé à une tonalité sémantique.
class ToneColors {
  const ToneColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}
