import 'package:flutter/material.dart';

/// Centralised colour tokens for Bano Qabil.
///
/// The visual system follows Bano Qabil's teal-led identity with a warm yellow
/// action accent, supported by mint surfaces and restrained ink neutrals.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------- Brand
  /// Deep teal: trust, focus, and the primary navigation anchor.
  static const Color primary = Color(0xFF1A5C56);
  static const Color primaryBright = Color(0xFF2D8E84);
  static const Color primarySoft = Color(0xFFE8F3F2);
  /// Warm yellow: action, progress, and moments of optimism.
  static const Color secondary = Color(0xFFFCBB00);
  static const Color secondaryBright = Color(0xFFFFD236);
  static const Color secondarySoft = Color(0xFFFEF3C6);
  static const Color accentBlue = Color(0xFF4285F4);

  // ----------------------------------------------------------- Neutrals
  static const Color background = Color(0xFFF5F9F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE8F3F2);
  static const Color fieldFill = Color(0xFFF0F9F8);
  static const Color textPrimary = Color(0xFF252525);
  static const Color textSecondary = Color(0xFF647184);

  // ------------------------------------------------------------ Semantic
  static const Color success = Color(0xFF257972);
  static const Color successSoft = Color(0xFFE8F3F2);
  static const Color warning = Color(0xFFC28A18);
  static const Color warningSoft = Color(0xFFFEF3C6);
  static const Color error = Color(0xFFFF6568);
  static const Color errorSoft = Color(0xFFFFE2E2);
  static const Color info = Color(0xFF4285F4);
  static const Color infoSoft = Color(0xFFF0F9F8);
  static const Color purple = Color(0xFF6A56B5);
  static const Color purpleSoft = Color(0xFFF0F9F8);

  // ----------------------------------------------------- Dark-mode tokens
  static const Color darkBackground = Color(0xFF123F3B);
  static const Color darkSurface = Color(0xFF1A5C56);
  static const Color darkBorder = Color(0xFF257972);
  static const Color darkFieldFill = Color(0xFF1F6B65);
  static const Color darkTextPrimary = Color(0xFFF5F9F9);
  static const Color darkTextSecondary = Color(0xFFB9D7D3);

  // ------------------------------------------------------------ Geometry
  static const double radiusCard = 20.0;
  static const double radiusField = 14.0;
  static const double radiusPill = 28.0;

  /// Soft, warm shadow used in place of harsh Material elevation.
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.07),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];

  // ---------------------------------------------- Backwards-compatible
  static const Color primaryIndigo = primary;
  static const Color emeraldGreen = success;
  static const Color crimsonRed = error;
  static const Color amber = warning;
  static const Color cardSurface = surface;
}
