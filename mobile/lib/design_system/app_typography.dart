import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Two-tier type system (DESIGN_INTENT §4):
///  - **Fredoka** — expressive, chunky display face for titles & headings.
///  - **Nunito Sans** — neutral, legible body face for lists, chat, forms.
///  - **DM Sans** (tabular) — for credit/number displays so digits align.
///
/// Encoded once as a [TextTheme]; screens must not scatter inline TextStyles.
class AppTypography {
  static TextTheme textTheme(Color onColor) {
    final muted = onColor;
    TextStyle display(double size, [FontWeight w = FontWeight.w700]) =>
        GoogleFonts.fredoka(fontSize: size, fontWeight: w, color: onColor, height: 1.15);
    TextStyle body(double size, [FontWeight w = FontWeight.w400]) =>
        GoogleFonts.nunitoSans(fontSize: size, fontWeight: w, color: muted, height: 1.4);

    return TextTheme(
      // Display / headings — Fredoka
      displaySmall: display(28),
      headlineMedium: display(24), // h1
      headlineSmall: display(20, FontWeight.w600), // h2
      titleLarge: display(18, FontWeight.w600), // h3 / card titles
      // Titles / body — Nunito Sans
      titleMedium: body(16, FontWeight.w700),
      titleSmall: body(14, FontWeight.w600),
      bodyLarge: body(16),
      bodyMedium: body(14),
      bodySmall: body(12),
      labelLarge: body(14, FontWeight.w700), // buttons
      labelMedium: body(12, FontWeight.w600),
      labelSmall: body(11, FontWeight.w600),
    );
  }

  /// Tabular-figure numeral style for credits, balances, ratings, counts.
  static TextStyle tabular({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
