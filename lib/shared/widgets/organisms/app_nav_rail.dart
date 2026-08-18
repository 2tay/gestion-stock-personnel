import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Une entrée du rail de navigation.
///
/// Le rail ne connaît ni `go_router` ni les routes : la configuration lui est
/// fournie par la couche `app/`, ce qui le garde réutilisable et testable.
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Pastille numérique (ex. commandes en attente de réception).
  final int? badgeCount;
}

/// Rail de navigation latéral permanent : Accueil, Stock, Inventaire,
/// Achats, Personnel, Rapports, Paramètres.
///
/// Deux largeurs : icônes seules (tablette étroite) ou icônes + libellés
/// (tablette en paysage).
class AppNavRail extends StatelessWidget {
  const AppNavRail({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.expanded = false,
    this.header,
    this.footer,
    super.key,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Affiche les libellés à côté des icônes.
  final bool expanded;

  /// Logo ou titre affiché en haut du rail.
  final Widget? header;

  /// Zone basse : état de synchronisation, profil, déconnexion.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded ? AppSizes.navRailExpandedWidth : AppSizes.navRailWidth,
      decoration: const BoxDecoration(
        color: AppColors.navSurface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: header,
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                itemCount: items.length,
                itemBuilder: (BuildContext _, int index) => _NavTile(
                  item: items[index],
                  selected: index == selectedIndex,
                  expanded: expanded,
                  onTap: () => onSelected(index),
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? AppColors.textOnPrimary : AppColors.textSecondary;
    final Color bg = selected ? AppColors.primary : Colors.transparent;

    Widget icon = Icon(
      selected ? item.selectedIcon : item.icon,
      size: AppSizes.iconMd,
      color: fg,
    );

    if (item.badgeCount != null && item.badgeCount! > 0) {
      icon = Badge.count(
        count: item.badgeCount!,
        backgroundColor: selected ? AppColors.surface : AppColors.danger,
        textColor: selected ? AppColors.primary : AppColors.textOnPrimary,
        child: icon,
      );
    }

    final Widget tile = Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          height: AppSizes.minTouchTarget,
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? AppSpacing.md : 0,
          ),
          child: expanded
              ? Row(
                  children: <Widget>[
                    icon,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    icon,
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.1,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: expanded ? tile : Tooltip(message: item.label, child: tile),
    );
  }
}
