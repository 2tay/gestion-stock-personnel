import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../atoms/app_avatar.dart';
import '../atoms/app_icon_button.dart';

/// Barre supérieure commune à toutes les pages : titre du module, zone
/// d'actions, notifications et avatar utilisateur.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    required this.title,
    required this.userName,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.notificationCount = 0,
    this.onNotificationsTap,
    this.onProfileTap,
    this.showBorder = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String userName;

  /// Bouton de retour dans les vues de détail plein écran.
  final Widget? leading;

  /// Recherche globale, bouton d'action principal, sélecteurs…
  final List<Widget> actions;

  final int notificationCount;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final bool showBorder;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.topBarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.topBarHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: showBorder
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: AppTypography.titleMd),
              if (subtitle != null)
                Text(subtitle!, style: AppTypography.caption),
            ],
          ),
          const Spacer(),
          for (final Widget action in actions) ...<Widget>[
            action,
            const SizedBox(width: AppSpacing.md),
          ],
          AppIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            badgeCount: notificationCount,
            onPressed: onNotificationsTap,
          ),
          const SizedBox(width: AppSpacing.md),
          AppAvatar(
            name: userName,
            size: 34,
            onTap: onProfileTap,
          ),
        ],
      ),
    );
  }
}
