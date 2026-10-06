import 'package:flutter/material.dart';

/// Colors used across the app. Pages should reference these instead of
/// hard-coding values so the look stays consistent.
abstract final class AppColors {
  static const background = Colors.black;
  static const surface = Color(0xFF212121); // grey[900]
  static const card = Color(0xFF303030); // grey[850]
  static const cardSelected = Color(0xFF1E3A24);
  static const accent = Colors.green;
  static const danger = Color(0xFFE57373); // red[300]
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFBDBDBD); // grey[400]
  static const textMuted = Colors.white54;
  static const textHint = Colors.white38;
  static const divider = Colors.white12;
}

abstract final class AppTheme {
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      popupMenuTheme: const PopupMenuThemeData(color: Color(0xFF424242)),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
