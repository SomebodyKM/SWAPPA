import 'package:flutter/material.dart';

/// SWAPPA palette — semantic roles pulled verbatim from the design's
/// `theme.css` color variables (light + dark). Do not hand-pick colors per
/// screen; reference these roles (or the [ColorScheme]) instead.
///
/// Product direction: "Playful Quest" — energetic violet primary + sunny
/// yellow accent, calm neutral surfaces so the accents carry the energy.
class AppColors {
  // ── Light ──────────────────────────────────────────────────────────────
  static const background = Color(0xFFF5F5FA);
  static const foreground = Color(0xFF1A1A2E);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF7C3AED); // violet
  static const primaryForeground = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFEDE9FD); // light violet
  static const secondaryForeground = Color(0xFF3B0764);
  static const muted = Color(0xFFEDEDF5);
  static const mutedForeground = Color(0xFF6B7280);
  static const accent = Color(0xFFFACC15); // sunny yellow
  static const accentForeground = Color(0xFF1A1A2E);
  static const destructive = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A); // grass green (completed/positive)
  static const inputBackground = Color(0xFFEDEDF5);
  static Color border = const Color(0xFF1A1A2E).withValues(alpha: 0.10);

  // ── Dark ───────────────────────────────────────────────────────────────
  static const backgroundDark = Color(0xFF0F0E1A);
  static const foregroundDark = Color(0xFFF0EEFF);
  static const cardDark = Color(0xFF1A1930);
  static const primaryDark = Color(0xFFA78BFA);
  static const primaryForegroundDark = Color(0xFF1A1A2E);
  static const secondaryDark = Color(0xFF2D2A4A);
  static const mutedDark = Color(0xFF2D2A4A);
  static const mutedForegroundDark = Color(0xFF9CA3AF);
  static const destructiveDark = Color(0xFFEF4444);
  static const successDark = Color(0xFF4ADE80);
  static const inputBackgroundDark = Color(0xFF2D2A4A);
  static Color borderDark = const Color(0xFFF0EEFF).withValues(alpha: 0.10);

  // ── Swap semantics (used consistently everywhere) ──────────────────────
  /// "teaches / offer" — green tint chip.
  static const offerBg = Color(0xFFD1FAE5); // emerald-100
  static const offerFg = Color(0xFF047857); // emerald-700
  /// "wants / learn" — violet tint chip (primary @ 12% over primary text).
  static Color wantBg = primary.withValues(alpha: 0.07);
  static const wantFg = primary;

  /// Brand gradient from the logo tile (splash / hero CTAs).
  static const brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF7B5CFF), Color(0xFF5A2EE5)],
  );
}
