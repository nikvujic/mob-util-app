import 'package:flutter/material.dart';

/// The colours of one theme. Widgets read the active palette with
/// `context.colors` instead of hard-coding values, so the look stays
/// consistent and can be switched (G12).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color card;
  final Color cardSelected;
  final Color menu;
  final Color accent;

  /// Icons and text on [accent] (e.g. the + button).
  final Color onAccent;
  final Color danger;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textHint;

  /// Unselected items in the bottom bar.
  final Color inactive;
  final Color divider;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardSelected,
    required this.menu,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textHint,
    required this.inactive,
    required this.divider,
  });

  /// Dark with a green accent: the app's original look.
  static const green = AppPalette(
    background: Colors.black,
    surface: Color(0xFF212121), // grey[900]
    card: Color(0xFF303030), // grey[850]
    cardSelected: Color(0xFF1E3A24),
    menu: Color(0xFF424242),
    accent: Colors.green,
    onAccent: Colors.white,
    danger: Color(0xFFE57373), // red[300]
    textPrimary: Colors.white,
    textSecondary: Color(0xFFBDBDBD), // grey[400]
    textMuted: Colors.white54,
    textHint: Colors.white38,
    inactive: Colors.grey,
    divider: Colors.white12,
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) => t < 0.5 ? this : other!;
}

/// The active palette: `context.colors.accent`. Outside the app's theme
/// (e.g. a widget shown on its own in a test) it's the original green one.
extension AppColorsOf on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.green;
}

/// Shapes used across the app.
abstract final class AppShapes {
  /// Dialogs: squarer than Material's default (28 dp) corners.
  static const dialog = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  /// Buttons inside dialogs, matching the dialog's squarer look.
  static const button = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
}

abstract final class AppTheme {
  /// The app's look with the colours of [palette].
  static ThemeData of(AppPalette palette) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: palette.accent,
      surface: palette.surface,
      error: palette.danger,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      extensions: [palette],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // No touch ripples anywhere (Nikola: they get in the way). Buttons
      // keep their brief flat pressed shade.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        shape: const CircleBorder(),
      ),
      popupMenuTheme: PopupMenuThemeData(color: palette.menu),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : Colors.transparent,
        ),
        side: BorderSide(color: palette.textSecondary, width: 1.5),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.accent,
        unselectedItemColor: palette.inactive,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  /// The original dark green look.
  static ThemeData get dark => of(AppPalette.green);
}
