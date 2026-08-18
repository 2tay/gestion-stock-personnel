import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_enums.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/theme.dart';
import '../../features/auth/presentation/controllers/session_controller.dart';
import '../../shared/widgets/organisms/app_nav_rail.dart';
import 'app_routes.dart';

/// Coque de navigation : le rail à gauche, la page courante à droite.
///
/// Monté une seule fois par `ShellRoute`, il survit aux changements de page ;
/// les pages n'ont donc jamais à se soucier de la navigation latérale.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserRole role = ref.watch(currentRoleProvider);
    final List<NavDestination> destinations = AppDestinations.forRole(role);
    final ScreenSize size = Breakpoints.of(context);

    final String location = GoRouterState.of(context).uri.path;
    final int selectedIndex = _indexOf(location, destinations);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: <Widget>[
          if (size.showNavRail)
            AppNavRail(
              expanded: size.showNavLabels,
              selectedIndex: selectedIndex,
              header: _BrandHeader(expanded: size.showNavLabels),
              footer: _SyncStatus(expanded: size.showNavLabels),
              items: destinations
                  .map((NavDestination d) => d.item)
                  .toList(growable: false),
              onSelected: (int index) =>
                  context.go(destinations[index].route.path),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: size.showNavRail
          ? null
          : _CompactNavBar(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: (int index) =>
                  context.go(destinations[index].route.path),
            ),
    );
  }

  /// Retrouve l'onglet actif à partir du chemin courant, en tenant compte
  /// des sous-routes (`/stock/12` sélectionne « Stock »).
  int _indexOf(String location, List<NavDestination> destinations) {
    int best = 0;
    int bestLength = -1;
    for (int i = 0; i < destinations.length; i++) {
      final String path = destinations[i].route.path;
      final bool matches = path == '/'
          ? location == '/'
          : location == path || location.startsWith('$path/');
      if (matches && path.length > bestLength) {
        best = i;
        bestLength = path.length;
      }
    }
    return best;
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Widget logo = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Icon(
        Icons.inventory_rounded,
        color: AppColors.textOnPrimary,
        size: AppSizes.iconMd,
      ),
    );

    if (!expanded) return Center(child: logo);

    return Row(
      children: <Widget>[
        logo,
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Gestion Stock',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text('& Personnel', style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }
}

/// Indicateur de synchronisation / mode hors connexion, prévu au cahier des
/// charges. Statique pour l'instant : la logique arrivera avec la couche
/// de données.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    const Widget dot = Icon(
      Icons.cloud_done_rounded,
      size: AppSizes.iconMd,
      color: AppColors.success,
    );

    if (!expanded) {
      return const Tooltip(
        message: 'Données synchronisées',
        child: SizedBox(height: 40, child: Center(child: dot)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        children: <Widget>[
          dot,
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Synchronisé',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.successOnSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Repli pour les écrans étroits : barre basse au lieu du rail.
class _CompactNavBar extends StatelessWidget {
  const _CompactNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
      onDestinationSelected: onSelected,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      destinations: <Widget>[
        for (final NavDestination d in destinations)
          NavigationDestination(
            icon: Icon(d.item.icon),
            selectedIcon: Icon(d.item.selectedIcon),
            label: d.item.label,
          ),
      ],
    );
  }
}
