import 'package:flutter/material.dart';

import '../atoms/app_dropdown.dart';

/// Périodes proposées sur les graphiques du tableau de bord et des rapports.
enum ReportPeriod {
  last7Days,
  last30Days,
  currentMonth,
  lastMonth,
  currentYear;

  String get label => switch (this) {
        ReportPeriod.last7Days => '7 derniers jours',
        ReportPeriod.last30Days => '30 derniers jours',
        ReportPeriod.currentMonth => 'Mois en cours',
        ReportPeriod.lastMonth => 'Mois dernier',
        ReportPeriod.currentYear => 'Année en cours',
      };
}

/// Sélecteur compact de période, aligné à droite des en-têtes de graphique.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    required this.value,
    required this.onChanged,
    this.width = 190,
    super.key,
  });

  final ReportPeriod value;
  final ValueChanged<ReportPeriod> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return AppDropdown<ReportPeriod>(
      value: value,
      dense: true,
      width: width,
      items: ReportPeriod.values,
      labelBuilder: (ReportPeriod p) => p.label,
      prefixIcon: Icons.calendar_today_rounded,
      onChanged: (ReportPeriod? v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
