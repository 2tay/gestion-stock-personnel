import '../../../core/constants/app_enums.dart';

/// Utilisateur connecté, tel que l'interface a besoin de le connaître.
///
/// Aucune donnée d'authentification réelle ici : la couche `data` de la
/// feature `auth` la fournira quand le backend sera branché.
class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.role,
    this.jobTitle,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? jobTitle;

  String get roleLabel => switch (role) {
        UserRole.patron => 'Patron',
        UserRole.manager => 'Manager',
        UserRole.employe => 'Employé',
      };

  /// Description du niveau d'accès, reprise du cahier des charges.
  String get roleDescription => switch (role) {
        UserRole.patron =>
          'Accès complet à toutes les fonctionnalités et paramétrages',
        UserRole.manager =>
          'Gestion opérationnelle du stock, achats, livraisons et personnel',
        UserRole.employe =>
          'Accès aux fonctionnalités autorisées (pointage, consultation…)',
      };

  SessionUser copyWith({String? fullName, UserRole? role, String? jobTitle}) {
    return SessionUser(
      id: id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      jobTitle: jobTitle ?? this.jobTitle,
    );
  }
}
