import 'package:flutter/material.dart';

/// Ombres douces de la maquette (cartes blanches sur fond gris clair).
abstract final class AppShadows {
  static const List<BoxShadow> none = <BoxShadow>[];

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> dialog = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F0F172A),
      blurRadius: 40,
      offset: Offset(0, 16),
    ),
  ];
}
