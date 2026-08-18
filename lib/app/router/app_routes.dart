import 'package:flutter/material.dart';

import '../../core/constants/app_enums.dart';
import '../../shared/widgets/organisms/app_nav_rail.dart';

/// Toutes les routes de l'application, en un seul endroit.
///
/// Les chemins ne sont jamais écrits en dur dans les features : on passe par
/// `context.goNamed(AppRoute.stock.name)` ou par les helpers de navigation.
enum AppRoute {
  login('/connexion'),
  dashboard('/'),
  stock('/stock'),
  productDetail('/stock/:id'),
  inventory('/inventaire'),
  inventoryCount('/inventaire/:id'),
  purchasing('/achats'),
  orderDetail('/achats/:id'),
  staff('/personnel'),
  timeClock('/personnel/:id'),
  reports('/rapports'),
  settings('/parametres'),
  gallery('/design-system');

  const AppRoute(this.path);

  /// Chemin déclaré dans `go_router`.
  final String path;
}

/// Une entrée du rail, associée à sa route et aux rôles qui peuvent la voir.
class NavDestination {
  const NavDestination({
    required this.route,
    required this.item,
    required this.allowedRoles,
  });

  final AppRoute route;
  final NavItem item;

  /// Contrôle d'accès de l'interface : le rail n'affiche que ce que le rôle
  /// courant a le droit d'ouvrir (Patron / Manager / Employé).
  final Set<UserRole> allowedRoles;

  bool isVisibleFor(UserRole role) => allowedRoles.contains(role);
}

/// Configuration du rail de navigation, dans l'ordre de la maquette.
abstract final class AppDestinations {
  static const Set<UserRole> _all = <UserRole>{
    UserRole.patron,
    UserRole.manager,
    UserRole.employe,
  };
  static const Set<UserRole> _management = <UserRole>{
    UserRole.patron,
    UserRole.manager,
  };
  static const Set<UserRole> _ownerOnly = <UserRole>{UserRole.patron};

  static const List<NavDestination> all = <NavDestination>[
    NavDestination(
      route: AppRoute.dashboard,
      allowedRoles: _management,
      item: NavItem(
        label: 'Accueil',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
      ),
    ),
    NavDestination(
      route: AppRoute.stock,
      allowedRoles: _all,
      item: NavItem(
        label: 'Stock',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
      ),
    ),
    NavDestination(
      route: AppRoute.inventory,
      allowedRoles: _all,
      item: NavItem(
        label: 'Inventaire',
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check_rounded,
      ),
    ),
    NavDestination(
      route: AppRoute.purchasing,
      allowedRoles: _management,
      item: NavItem(
        label: 'Achats',
        icon: Icons.shopping_cart_outlined,
        selectedIcon: Icons.shopping_cart_rounded,
      ),
    ),
    NavDestination(
      route: AppRoute.staff,
      allowedRoles: _all,
      item: NavItem(
        label: 'Personnel',
        icon: Icons.people_outline_rounded,
        selectedIcon: Icons.people_rounded,
      ),
    ),
    NavDestination(
      route: AppRoute.reports,
      allowedRoles: _management,
      item: NavItem(
        label: 'Rapports',
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart_rounded,
      ),
    ),
    NavDestination(
      route: AppRoute.settings,
      allowedRoles: _ownerOnly,
      item: NavItem(
        label: 'Paramètres',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
      ),
    ),
  ];

  /// Destinations visibles par le rôle donné.
  static List<NavDestination> forRole(UserRole role) =>
      all.where((NavDestination d) => d.isVisibleFor(role)).toList();
}
