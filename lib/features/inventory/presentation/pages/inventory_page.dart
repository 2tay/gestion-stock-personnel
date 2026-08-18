import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../../shared/layout/app_scaffold.dart';
import '../../../../shared/layout/module_placeholder.dart';

/// Module « Inventaire ».
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Inventaire',
      subtitle: 'Réalisez vos inventaires et suivez les écarts',
      userName: ref.watch(currentUserNameProvider),
      body: const ModulePlaceholder(
        moduleName: 'Inventaire',
        phase: 'Phase 5',
        icon: Icons.fact_check_rounded,
        accent: AppColors.moduleInventory,
        screens: <String>[
          'Liste des inventaires (Tous / En cours / Brouillon / Terminé)',
          'Écran de comptage avec scan',
          'Comparaison stock théorique / stock réel',
          'Validation des écarts',
        ],
      ),
    );
  }
}
