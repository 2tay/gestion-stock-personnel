import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../../shared/layout/app_scaffold.dart';
import '../../../../shared/layout/module_placeholder.dart';

/// Module « Personnel ».
class StaffPage extends ConsumerWidget {
  const StaffPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Personnel',
      subtitle: 'Gérez vos employés et suivez le pointage',
      userName: ref.watch(currentUserNameProvider),
      body: const ModulePlaceholder(
        moduleName: 'Personnel',
        phase: 'Phase 7',
        icon: Icons.people_rounded,
        accent: AppColors.moduleStaff,
        screens: <String>[
          'Liste des employés et statut de pointage',
          'Carte de pointage (début, pause, reprise, fin)',
          'Heures travaillées et heures supplémentaires',
          'Historique des pointages',
        ],
      ),
    );
  }
}
