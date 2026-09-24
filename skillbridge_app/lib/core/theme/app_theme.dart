import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Material 3 theme for Bano Qabil, light and dark.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final background = isDark ? AppColors.darkBackground : AppColors.background;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final fieldFill = isDark ? AppColors.darkFieldFill : AppColors.fieldFill;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: isDark ? AppColors.primaryBright : AppColors.primary,
      onPrimary: Colors.white,
      secondary: isDark ? AppColors.secondaryBright : AppColors.secondary,
      onSecondary: AppColors.primary,
      error: AppColors.error,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
        displaySmall: TextStyle(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1.2),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.7),
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.2),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
        bodyLarge: TextStyle(color: textPrimary, height: 1.45),
        bodyMedium: TextStyle(color: textSecondary, height: 1.5),
        bodySmall: TextStyle(color: textSecondary, height: 1.35),
        labelLarge: TextStyle(fontWeight: FontWeight.w700, color: textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.4),
        shape: Border(bottom: BorderSide(color: border.withValues(alpha: 0.7))),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusCard), side: BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        prefixIconColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.focused) ? colorScheme.primary : textSecondary),
        labelStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusField), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusField), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusField), borderSide: BorderSide(color: colorScheme.primary, width: 1.8)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusField), borderSide: const BorderSide(color: AppColors.error, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusField), borderSide: const BorderSide(color: AppColors.error, width: 1.6)),
        errorStyle: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusPill)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusPill)), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: colorScheme.primary, side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.28), width: 1.4), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusPill)), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: colorScheme.primary, textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      chipTheme: ChipThemeData(side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusPill)), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: isDark ? AppColors.secondary.withValues(alpha: 0.2) : AppColors.secondary,
        elevation: 12,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontSize: 11, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600, color: states.contains(WidgetState.selected) ? (isDark ? AppColors.secondaryBright : AppColors.primary) : textSecondary)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.primary,
        indicatorColor: AppColors.secondary,
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.62)),
        selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
        unselectedLabelTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.primary, contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusField))),
      dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusCard))),
      listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusField)), iconColor: textSecondary),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: isDark ? AppColors.secondaryBright : AppColors.primary),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
