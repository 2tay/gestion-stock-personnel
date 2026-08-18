import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../../shared/layout/app_scaffold.dart';
import '../../../../shared/layout/module_placeholder.dart';

/// Module « Tableau de bord ».
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Tableau de bord',
      subtitle: "Vue d'ensemble de votre activité",
      userName: ref.watch(currentUserNameProvider),
      body: const ModulePlaceholder(
        moduleName: 'Tableau de bord',
        phase: 'Phase 8',
        icon: Icons.dashboard_rounded,
        accent: AppColors.moduleDashboard,
        screens: <String>[
          'KPI (valeur du stock, produits, stocks faibles, commandes, employés pointés)',
          'Produits à commander',
          'Évolution du stock (graphique)',
          'Activités récentes',
        ],
      ),
    );
  }
}
