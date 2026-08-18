import 'package:flutter/material.dart';

/// Palette de l'application, extraite de la maquette.
///
/// Ne jamais utiliser de `Color(0x...)` en dur dans les features :
/// toute couleur doit passer par ici (ou par le [ColorScheme] du thème).
abstract final class AppColors {
  // --- Marque -------------------------------------------------------------
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color primaryPressed = Color(0xFF1E40AF);
  static const Color primarySoft = Color(0xFFDBEAFE);
  static const Color primaryOnSoft = Color(0xFF1D4ED8);

  // --- Accents de module (en-têtes de la maquette) ------------------------
  static const Color moduleStock = Color(0xFF2563EB);
  static const Color moduleInventory = Color(0xFF16A34A);
  static const Color modulePurchasing = Color(0xFF7C3AED);
  static const Color moduleStaff = Color(0xFFF97316);
  static const Color moduleDashboard = Color(0xFF2563EB);
  static const Color moduleReports = Color(0xFF9333EA);

  // --- Surfaces -----------------------------------------------------------
  static const Color background = Color(0xFFF1F5F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color surfaceHover = Color(0xFFF1F5F9);
  static const Color navSurface = Color(0xFFFFFFFF);
  static const Color overlay = Color(0x66101828);

  // --- Bordures -----------------------------------------------------------
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color divider = Color(0xFFEEF2F6);

  // --- Texte --------------------------------------------------------------
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textDisabled = Color(0xFFCBD5E1);

  // --- Sémantique ---------------------------------------------------------
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color successOnSoft = Color(0xFF15803D);

  static const Color warning = Color(0xFFEA580C);
  static const Color warningSoft = Color(0xFFFFEDD5);
  static const Color warningOnSoft = Color(0xFFC2410C);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color dangerOnSoft = Color(0xFFB91C1C);

  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFDBEAFE);
  static const Color infoOnSoft = Color(0xFF1D4ED8);

  static const Color neutral = Color(0xFF64748B);
  static const Color neutralSoft = Color(0xFFF1F5F9);
  static const Color neutralOnSoft = Color(0xFF475569);

  // --- Séries de graphiques (tableau de bord / rapports) ------------------
  static const List<Color> chartSeries = <Color>[
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFF97316),
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
    Color(0xFFDC2626),
  ];
}
