import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../widgets/organisms/app_top_bar.dart';

/// Squelette d'une page de module : barre supérieure + contenu sur fond gris.
///
/// Le rail de navigation n'est pas inclus : il est fourni une seule fois par
/// la coque de navigation (`AppShell`), ce qui évite de le reconstruire à
/// chaque changement de page.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    required this.userName,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.notificationCount = 0,
    this.onNotificationsTap,
    this.onProfileTap,
    this.floatingAction,
    this.padded = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final String userName;
  final Widget? leading;
  final List<Widget> actions;
  final int notificationCount;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final Widget? floatingAction;

  /// Applique la marge intérieure standard autour du contenu.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: floatingAction,
      body: Column(
        children: <Widget>[
          AppTopBar(
            title: title,
            subtitle: subtitle,
            userName: userName,
            leading: leading,
            actions: actions,
            notificationCount: notificationCount,
            onNotificationsTap: onNotificationsTap,
            onProfileTap: onProfileTap,
          ),
          Expanded(
            child: padded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageH,
                      AppSpacing.pageV,
                      AppSpacing.pageH,
                      AppSpacing.pageV,
                    ),
                    child: body,
                  )
                : body,
          ),
        ],
      ),
    );
  }
}
