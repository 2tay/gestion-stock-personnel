import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';

/// Pastille d'identité : initiales colorées, ou icône si le nom est inconnu.
///
/// Utilisée dans la barre supérieure, la liste des employés et le pointage.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    this.size = 36,
    this.imageUrl,
    this.onTap,
    this.badgeColor,
    super.key,
  });

  const AppAvatar.small({required this.name, this.imageUrl, this.onTap, super.key})
      : size = 28,
        badgeColor = null;

  const AppAvatar.large({required this.name, this.imageUrl, this.onTap, super.key})
      : size = 56,
        badgeColor = null;

  final String name;
  final double size;
  final String? imageUrl;
  final VoidCallback? onTap;

  /// Pastille d'état affichée en bas à droite (ex. employé pointé).
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final Color base = _colorFor(name);

    Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        image: imageUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              ),
      ),
      child: imageUrl != null
          ? null
          : Text(
              Formatters.initials(name),
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w600,
                color: base,
                height: 1,
              ),
            ),
    );

    if (badgeColor != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      avatar = InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatar,
      );
    }
    return avatar;
  }

  /// Couleur déterministe dérivée du nom : le même employé garde sa teinte.
  static Color _colorFor(String name) {
    if (name.isEmpty) return AppColors.neutral;
    final int hash = name.codeUnits.fold<int>(0, (int a, int b) => a + b);
    return AppColors.chartSeries[hash % AppColors.chartSeries.length];
  }
}
