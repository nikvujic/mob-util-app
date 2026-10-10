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

  /// Icons on [accent] (e.g. the + button).
  final Color onAccent;

  /// Text on [accent] (filled buttons), if the generated one isn't
  /// readable enough on it.
  final Color? accentText;
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
    this.accentText,
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

  /// True black (pixels off on OLED screens), with the green accent.
  static const black = AppPalette(
    background: Colors.black,
    surface: Colors.black,
    card: Color(0xFF161616),
    cardSelected: Color(0xFF10301A),
    menu: Color(0xFF1E1E1E),
    accent: Colors.green,
    onAccent: Colors.white,
    danger: Color(0xFFE57373),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFBDBDBD),
    textMuted: Colors.white54,
    textHint: Colors.white38,
    inactive: Colors.grey,
    divider: Color(0x24FFFFFF),
  );

  /// Near-black warm greys with Claude's orange, like the Claude app.
  static const clay = AppPalette(
    // Anthropic's brand colours, as in the Claude app's dark look.
    background: Color(0xFF141413),
    surface: Color(0xFF1C1B19),
    card: Color(0xFF262624),
    cardSelected: Color(0xFF3B2A22),
    menu: Color(0xFF30302E),
    accent: Color(0xFFC96442),
    onAccent: Colors.white,
    accentText: Color(0xFF141413),
    danger: Color(0xFFF28B82),
    textPrimary: Color(0xFFFAF9F5),
    textSecondary: Color(0xFFB0AEA5),
    textMuted: Color(0xFF8E8C84),
    textHint: Color(0xFF75736C),
    inactive: Color(0xFF8E8C84),
    divider: Color(0xFF2E2D2A),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) => t < 0.5 ? this : other!;
}

/// The themes to choose from (G12). Their [name] is what's stored.
enum AppThemeChoice {
  green('Green', AppPalette.green),
  black('Black', AppPalette.black),
  clay('Clay', AppPalette.clay);

  const AppThemeChoice(this.label, this.palette);

  final String label;
  final AppPalette palette;

  /// The theme stored as [id]; the default one if unknown.
  static AppThemeChoice fromId(String id) =>
      values.where((t) => t.name == id).firstOrNull ?? green;
}

/// The active palette: `context.colors.accent`. Outside the app's theme
/// (e.g. a widget shown on its own in a test) it's the original green one.
extension AppColorsOf on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.green;
}

/// Shapes used across the app.
/// Colours for planner blocks (P9): a muted fill, so the text on it stays
/// readable, and a bright stripe along the block's edge. The same in every
/// theme (all are dark).
enum BlockColor {
  red('Red', Color(0xFF4A2427), Color(0xFFE57373)),
  orange('Orange', Color(0xFF4A3121), Color(0xFFFFB74D)),
  yellow('Yellow', Color(0xFF433D1F), Color(0xFFFFE082)),
  green('Green', Color(0xFF213F27), Color(0xFF81C784)),
  blue('Blue', Color(0xFF1F3449), Color(0xFF64B5F6)),
  purple('Purple', Color(0xFF382A4B), Color(0xFFB39DDB));

  final String label;
  final Color fill;
  final Color stripe;

  const BlockColor(this.label, this.fill, this.stripe);

  /// The colour stored as [name], or null (none, or unknown).
  static BlockColor? fromName(String? name) =>
      values.where((c) => c.name == name).firstOrNull;
}

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
      onPrimary: palette.accentText,
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
      // Chips (e.g. the planner's quick times and repeat days): the app's
      // own colours, so every theme keeps readable labels.
      chipTheme: ChipThemeData(
        backgroundColor: palette.card,
        selectedColor: palette.cardSelected,
        disabledColor: palette.surface,
        checkmarkColor: palette.accent,
        side: BorderSide(color: palette.divider),
        labelStyle: TextStyle(color: palette.textPrimary),
        secondaryLabelStyle: TextStyle(color: palette.textPrimary),
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
