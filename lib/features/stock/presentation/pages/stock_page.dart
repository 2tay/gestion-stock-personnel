import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../../shared/layout/app_scaffold.dart';
import '../../../../shared/layout/module_placeholder.dart';

/// Module « Stock ».
class StockPage extends ConsumerWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Stock',
      subtitle: 'Gérez vos produits et suivez vos stocks en temps réel',
      userName: ref.watch(currentUserNameProvider),
      body: const ModulePlaceholder(
        moduleName: 'Stock',
        phase: 'Phase 4',
        icon: Icons.inventory_2_rounded,
        accent: AppColors.moduleStock,
        screens: <String>[
          'Liste des produits (Tous / Catégories / Stock faible)',
          'Fiche produit (mouvements, informations, fournisseurs)',
          'Création et édition de produit',
          'Entrées et sorties de stock',
        ],
      ),
    );
  }
}
