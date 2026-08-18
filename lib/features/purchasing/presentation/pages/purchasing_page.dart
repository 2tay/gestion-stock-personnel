import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../../shared/layout/app_scaffold.dart';
import '../../../../shared/layout/module_placeholder.dart';

/// Module « Courses & Achats ».
class PurchasingPage extends ConsumerWidget {
  const PurchasingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Courses & Achats',
      subtitle: 'Gérez vos fournisseurs, commandes et réceptions',
      userName: ref.watch(currentUserNameProvider),
      body: const ModulePlaceholder(
        moduleName: 'Courses & Achats',
        phase: 'Phase 6',
        icon: Icons.shopping_cart_rounded,
        accent: AppColors.modulePurchasing,
        screens: <String>[
          'Liste des commandes (Toutes / En cours / Partielles / Reçues)',
          'Détail de commande et réception',
          'Liste de courses par fournisseur',
          'Gestion des fournisseurs',
        ],
      ),
    );
  }
}
