import 'package:flutter/material.dart';

/// Constantes visuales para la interfaz de Android TV (diseño "10-foot").
abstract final class TvTheme {
  static const Color background = Color(0xFF0E0E12);
  static const Color surface = Color(0xFF1C1C22);
  static const Color surfaceRaised = Color(0xFF2A2A33);
  static const Color accent = Color(0xFF3D8BFF);
  static const Color focusBorder = Colors.white;
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB4B4BE);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);
  static const Color favorite = Color(0xFFFFC107);

  /// Márgenes de overscan.
  static const EdgeInsets safeArea =
      EdgeInsets.symmetric(horizontal: 48, vertical: 27);

  static const double focusScale = 1.06;
  static const double focusBorderWidth = 3.0;
  static const Duration focusDuration = Duration(milliseconds: 150);
  static const double radius = 10.0;

  static const double fontSmall = 16.0;
  static const double fontBody = 18.0;
  static const double fontTitle = 26.0;

  static const double sidebarCollapsed = 84.0;
  static const double sidebarExpanded = 220.0;
  static const double groupsWidth = 240.0;
  static const double tileMaxExtent = 200.0;
  static const double tileAspectRatio = 16 / 12;
}
