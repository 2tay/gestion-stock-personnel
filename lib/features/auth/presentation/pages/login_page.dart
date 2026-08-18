import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/shared.dart';
import '../controllers/session_controller.dart';

/// Écran de connexion et de choix du niveau d'accès.
///
/// Aucune authentification réelle en phase frontend : le choix du rôle
/// alimente la session simulée, ce qui permet de vérifier que le rail et les
/// écrans réagissent bien aux droits (Patron / Manager / Employé).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _login = TextEditingController(text: 'admin');
  final TextEditingController _password = TextEditingController(text: '••••••');
  UserRole _role = UserRole.patron;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    ref.read(sessionProvider.notifier).signIn(role: _role);
    context.go(_landingFor(_role));
  }

  /// Un employé n'a pas accès au tableau de bord : il arrive sur le pointage.
  String _landingFor(UserRole role) => switch (role) {
        UserRole.patron || UserRole.manager => AppRoute.dashboard.path,
        UserRole.employe => AppRoute.staff.path,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: const Icon(
                          Icons.inventory_rounded,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Gestion Stock & Personnel',
                              style: AppTypography.titleMd,
                            ),
                            Text(
                              'Connexion à votre établissement',
                              style: AppTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  AppTextField(
                    controller: _login,
                    label: 'Identifiant',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _password,
                    label: 'Mot de passe',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const Text('Niveau d’accès', style: AppTypography.label),
                  const SizedBox(height: AppSpacing.sm),
                  for (final UserRole role in UserRole.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _RoleTile(
                        role: role,
                        selected: _role == role,
                        onTap: () => setState(() => _role = role),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton.primary(
                    label: 'Se connecter',
                    size: AppButtonSize.lg,
                    expand: true,
                    onPressed: _signIn,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (String label, String description, IconData icon) = switch (role) {
      UserRole.patron => (
          'Patron',
          'Accès complet à toutes les fonctionnalités et paramétrages',
          Icons.workspace_premium_rounded,
        ),
      UserRole.manager => (
          'Manager',
          'Gestion opérationnelle du stock, achats, livraisons et personnel',
          Icons.badge_outlined,
        ),
      UserRole.employe => (
          'Employé',
          'Accès aux fonctionnalités autorisées (pointage, consultation…)',
          Icons.person_outline_rounded,
        ),
    };

    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: AppSizes.iconLg,
                color: selected ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(label, style: AppTypography.titleSm),
                    const SizedBox(height: 2),
                    Text(description, style: AppTypography.caption),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: AppSizes.iconMd,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
