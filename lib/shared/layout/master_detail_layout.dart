import 'package:flutter/material.dart';

import '../../core/constants/app_durations.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/theme.dart';

/// Liste à gauche, détail à droite en tablette paysage ; en dessous, le
/// détail remplace la liste.
///
/// C'est le schéma de Stock (liste + fiche produit), Achats (commandes +
/// détail), Personnel (employés + pointage) et Inventaire (liste + comptage).
class MasterDetailLayout extends StatelessWidget {
  const MasterDetailLayout({
    required this.master,
    this.detail,
    this.detailFlex = 4,
    this.masterFlex = 6,
    this.minDetailWidth = 380,
    this.gap = AppSpacing.lg,
    super.key,
  });

  final Widget master;

  /// `null` = aucun élément sélectionné : la liste occupe toute la largeur.
  final Widget? detail;

  final int masterFlex;
  final int detailFlex;
  final double minDetailWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ScreenSize size = Breakpoints.fromWidth(constraints.maxWidth);
        final bool sideBySide = size.showSideDetail && detail != null;

        if (!sideBySide) {
          return AnimatedSwitcher(
            duration: AppDurations.fast,
            child: detail ?? master,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(flex: masterFlex, child: master),
            SizedBox(width: gap),
            Expanded(
              flex: detailFlex,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minDetailWidth),
                child: detail!,
              ),
            ),
          ],
        );
      },
    );
  }
}
