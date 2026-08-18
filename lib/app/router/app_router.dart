import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_enums.dart';
import '../../features/auth/domain/session_user.dart';
import '../../features/auth/presentation/controllers/session_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/gallery/presentation/pages/gallery_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/purchasing/presentation/pages/purchasing_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/staff/presentation/pages/staff_page.dart';
import '../../features/stock/presentation/pages/stock_page.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellKey = GlobalKey<NavigatorState>();

/// Routeur de l'application.
///
/// Une `ShellRoute` porte le rail de navigation ; toutes les pages de module
/// vivent à l'intérieur. La redirection applique le contrôle d'accès :
/// une route dont le rôle courant n'a pas les droits renvoie vers sa page
/// d'accueil autorisée.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final SessionUser? session = ref.watch(sessionProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoute.dashboard.path,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.uri.path;
      final bool goingToLogin = location == AppRoute.login.path;

      if (session == null) {
        return goingToLogin ? null : AppRoute.login.path;
      }
      if (goingToLogin) return _landingFor(session.role);

      // La vitrine du design system reste accessible en développement.
      if (location == AppRoute.gallery.path) return null;

      final NavDestination? destination = _destinationFor(location);
      if (destination != null && !destination.isVisibleFor(session.role)) {
        return _landingFor(session.role);
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.login.path,
        name: AppRoute.login.name,
        parentNavigatorKey: _rootKey,
        builder: (BuildContext _, GoRouterState state) => const LoginPage(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (BuildContext _, GoRouterState state, Widget child) =>
            AppShell(child: child),
        routes: <RouteBase>[
          _shellRoute(AppRoute.dashboard, const DashboardPage()),
          _shellRoute(
            AppRoute.stock,
            const StockPage(),
            // La fiche produit s'affiche en panneau latéral ; la sous-route
            // sert au lien profond et sera exploitée en phase 4.
            subRoute: AppRoute.productDetail,
          ),
          _shellRoute(
            AppRoute.inventory,
            const InventoryPage(),
            subRoute: AppRoute.inventoryCount,
          ),
          _shellRoute(
            AppRoute.purchasing,
            const PurchasingPage(),
            subRoute: AppRoute.orderDetail,
          ),
          _shellRoute(
            AppRoute.staff,
            const StaffPage(),
            subRoute: AppRoute.timeClock,
          ),
          _shellRoute(AppRoute.reports, const ReportsPage()),
          _shellRoute(AppRoute.settings, const SettingsPage()),
          _shellRoute(AppRoute.gallery, const GalleryPage()),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        _RouteErrorPage(location: state.uri.toString()),
  );
});

GoRoute _shellRoute(AppRoute route, Widget page, {AppRoute? subRoute}) {
  return GoRoute(
    path: route.path,
    name: route.name,
    builder: (BuildContext _, GoRouterState state) => page,
    routes: <RouteBase>[
      if (subRoute != null)
        GoRoute(
          // `/stock/:id` -> `:id`
          path: subRoute.path.split('/').last,
          name: subRoute.name,
          builder: (BuildContext _, GoRouterState state) => page,
        ),
    ],
  );
}

/// Page d'accueil autorisée pour un rôle donné.
String _landingFor(UserRole role) => switch (role) {
      UserRole.patron || UserRole.manager => AppRoute.dashboard.path,
      UserRole.employe => AppRoute.staff.path,
    };

/// Retrouve la destination de navigation qui couvre un chemin donné.
NavDestination? _destinationFor(String location) {
  NavDestination? match;
  int bestLength = -1;
  for (final NavDestination d in AppDestinations.all) {
    final String path = d.route.path;
    final bool matches = path == '/'
        ? location == '/'
        : location == path || location.startsWith('$path/');
    if (matches && path.length > bestLength) {
      match = d;
      bestLength = path.length;
    }
  }
  return match;
}

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.link_off_rounded, size: 40),
            const SizedBox(height: 12),
            Text('Page introuvable : $location'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(AppRoute.dashboard.path),
              child: const Text('Retour à l’accueil'),
            ),
          ],
        ),
      ),
    );
  }
}
