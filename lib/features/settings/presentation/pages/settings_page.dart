import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../../shared/layout/app_scaffold.dart';
import '../../../../shared/layout/module_placeholder.dart';

/// Module « Paramètres ».
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Paramètres',
      subtitle: "Configuration de l'application",
      userName: ref.watch(currentUserNameProvider),
      body: const ModulePlaceholder(
        moduleName: 'Paramètres',
        phase: 'Phase 10',
        icon: Icons.settings_rounded,
        accent: AppColors.neutral,
        screens: <String>[
          'Profil et compte',
          "Rôles et droits d'accès",
          'Unités, devise et langue',
          'Synchronisation et appareils',
        ],
      ),
    );
  }
}
