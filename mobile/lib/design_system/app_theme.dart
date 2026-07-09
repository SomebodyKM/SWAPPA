import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'tokens.dart';

/// Assembles the SWAPPA [ThemeData] from the design tokens. Every screen
/// inherits from this — colors, type, radius, and shadows come from here.
class AppTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.primaryForeground,
          secondary: AppColors.secondary,
          onSecondary: AppColors.secondaryForeground,
          surface: AppColors.card,
          onSurface: AppColors.foreground,
          surfaceContainerLowest: AppColors.background,
          error: AppColors.destructive,
          outlineVariant: AppColors.border,
        );
    return _build(scheme, AppColors.background, AppColors.mutedForeground);
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryDark,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primaryDark,
          onPrimary: AppColors.primaryForegroundDark,
          secondary: AppColors.secondaryDark,
          surface: AppColors.cardDark,
          onSurface: AppColors.foregroundDark,
          surfaceContainerLowest: AppColors.backgroundDark,
          error: AppColors.destructiveDark,
          outlineVariant: AppColors.borderDark,
        );
    return _build(
      scheme,
      AppColors.backgroundDark,
      AppColors.mutedForegroundDark,
    );
  }

  static ThemeData _build(ColorScheme scheme, Color background, Color muted) {
    final text = AppTypography.textTheme(scheme.onSurface);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: text.bodyMedium?.copyWith(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelMedium,
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
    );
  }
}

/// Soft, layered card shadow (DESIGN_INTENT §5) — Material cards are flat, so
/// wrap elevated surfaces with this for the tactile "Playful Quest" feel.
List<BoxShadow> softShadow(BuildContext context) => [
  BoxShadow(
    color: Colors.black.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.06,
    ),
    blurRadius: 16,
    offset: const Offset(0, 6),
  ),
];
