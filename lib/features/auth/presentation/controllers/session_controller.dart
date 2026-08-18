import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_enums.dart';
import '../../domain/session_user.dart';

/// Session courante de l'application.
///
/// Phase frontend : la session est simulée et démarre déjà connectée pour
/// pouvoir parcourir les écrans. Le jour où l'authentification arrive, seul
/// le corps de ce contrôleur change — ni le routeur ni les pages ne bougent.
class SessionController extends StateNotifier<SessionUser?> {
  SessionController() : super(_mockUser);

  static const SessionUser _mockUser = SessionUser(
    id: 'u-001',
    fullName: 'Admin Demo',
    role: UserRole.patron,
    jobTitle: 'Gérant',
  );

  bool get isAuthenticated => state != null;

  void signIn({UserRole role = UserRole.patron}) {
    state = _mockUser.copyWith(role: role);
  }

  /// Permet de tester l'interface avec un autre niveau d'accès sans se
  /// déconnecter (utile pendant le développement).
  void switchRole(UserRole role) {
    final SessionUser? current = state;
    if (current == null) return;
    state = current.copyWith(role: role);
  }

  void signOut() => state = null;
}

final StateNotifierProvider<SessionController, SessionUser?> sessionProvider =
    StateNotifierProvider<SessionController, SessionUser?>(
  (Ref ref) => SessionController(),
);

/// Rôle courant, avec repli sur `employe` si aucune session.
final Provider<UserRole> currentRoleProvider = Provider<UserRole>((Ref ref) {
  return ref.watch(sessionProvider)?.role ?? UserRole.employe;
});

/// Nom affiché dans la barre supérieure.
final Provider<String> currentUserNameProvider = Provider<String>((Ref ref) {
  return ref.watch(sessionProvider)?.fullName ?? 'Invité';
});
