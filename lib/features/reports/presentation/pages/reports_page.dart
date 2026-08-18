import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../../shared/layout/app_scaffold.dart';
import '../../../../shared/layout/module_placeholder.dart';

/// Module « Rapports & Analyses ».
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Rapports & Analyses',
      subtitle: 'Consultez et analysez vos données',
      userName: ref.watch(currentUserNameProvider),
      body: const ModulePlaceholder(
        moduleName: 'Rapports & Analyses',
        phase: 'Phase 9',
        icon: Icons.bar_chart_rounded,
        accent: AppColors.moduleReports,
        screens: <String>[
          'Valeur du stock',
          'Mouvements de stock',
          'Achats & commandes',
          'Inventaires',
          'Pointage du personnel et heures supplémentaires',
        ],
      ),
    );
  }
}
