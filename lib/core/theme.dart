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

  /// The accent as text on the app's surfaces (text buttons), if [accent]
  /// itself is too dark to read there.
  final Color? accentForeground;
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
    this.accentForeground,
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
    // The orange as text on the dark surfaces: a touch lighter to read.
    accentForeground: Color(0xFFD97757),
    danger: Color(0xFFF28B82),
    textPrimary: Color(0xFFFAF9F5),
    textSecondary: Color(0xFFB0AEA5),
    textMuted: Color(0xFF8E8C84),
    textHint: Color(0xFF75736C),
    inactive: Color(0xFF8E8C84),
    divider: Color(0xFF2E2D2A),
  );

  /// Deep blue, with a sky-blue accent.
  static const ocean = AppPalette(
    background: Color(0xFF0B141D),
    surface: Color(0xFF101C28),
    card: Color(0xFF172736),
    cardSelected: Color(0xFF16384A),
    menu: Color(0xFF1E3245),
    accent: Color(0xFF4FC3F7),
    onAccent: Color(0xFF0B141D),
    accentText: Color(0xFF0B141D),
    danger: Color(0xFFF28B82),
    textPrimary: Color(0xFFEAF2F8),
    textSecondary: Color(0xFFAFC2D2),
    textMuted: Color(0xFF8DA3B5),
    textHint: Color(0xFF6E8598),
    inactive: Color(0xFF8DA3B5),
    divider: Color(0xFF223446),
  );

  /// Cool grey-blue, like a frosty night (after the Nord colours).
  static const frost = AppPalette(
    background: Color(0xFF242933),
    surface: Color(0xFF2E3440),
    card: Color(0xFF3B4252),
    cardSelected: Color(0xFF3A5160),
    menu: Color(0xFF434C5E),
    accent: Color(0xFF88C0D0),
    onAccent: Color(0xFF242933),
    accentText: Color(0xFF242933),
    danger: Color(0xFFF2A0A6),
    textPrimary: Color(0xFFECEFF4),
    textSecondary: Color(0xFFD0D6E0),
    textMuted: Color(0xFFB4BCCA),
    textHint: Color(0xFF8D96A6),
    inactive: Color(0xFFB4BCCA),
    divider: Color(0xFF3F4757),
  );

  /// Dark violet, with a lavender accent.
  static const grape = AppPalette(
    background: Color(0xFF14111B),
    surface: Color(0xFF1B1724),
    card: Color(0xFF251F31),
    cardSelected: Color(0xFF392A52),
    menu: Color(0xFF2D263B),
    accent: Color(0xFFB39DDB),
    onAccent: Color(0xFF14111B),
    accentText: Color(0xFF14111B),
    danger: Color(0xFFF28B82),
    textPrimary: Color(0xFFF1ECF8),
    textSecondary: Color(0xFFC3B8D4),
    textMuted: Color(0xFF9F93B3),
    textHint: Color(0xFF7F7394),
    inactive: Color(0xFF9F93B3),
    divider: Color(0xFF2E273B),
  );

  /// Warm dark with a pink accent.
  static const rose = AppPalette(
    background: Color(0xFF181013),
    surface: Color(0xFF20161A),
    card: Color(0xFF2B1E24),
    cardSelected: Color(0xFF4A2433),
    menu: Color(0xFF34252C),
    accent: Color(0xFFF48FB1),
    onAccent: Color(0xFF181013),
    accentText: Color(0xFF181013),
    danger: Color(0xFFFFAB91),
    textPrimary: Color(0xFFF8EEF1),
    textSecondary: Color(0xFFD3BCC4),
    textMuted: Color(0xFFAF98A1),
    textHint: Color(0xFF8C7680),
    inactive: Color(0xFFAF98A1),
    divider: Color(0xFF33242A),
  );

  /// Greys only, with white as the accent.
  static const mono = AppPalette(
    background: Color(0xFF101010),
    surface: Color(0xFF181818),
    card: Color(0xFF232323),
    cardSelected: Color(0xFF3A3A3A),
    menu: Color(0xFF2C2C2C),
    accent: Color(0xFFE6E6E6),
    onAccent: Color(0xFF101010),
    accentText: Color(0xFF101010),
    danger: Color(0xFFF28B82),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFFBDBDBD),
    textMuted: Color(0xFF9E9E9E),
    textHint: Color(0xFF7A7A7A),
    inactive: Color(0xFF9E9E9E),
    divider: Color(0xFF2A2A2A),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) => t < 0.5 ? this : other!;
}

/// The themes to choose from (G12), all dark. Their [name] is what's
/// stored; the first is the default (Clay, Nikola's pick).
enum AppThemeChoice {
  clay('Clay', AppPalette.clay),
  green('Green', AppPalette.green),
  black('Black', AppPalette.black),
  ocean('Ocean', AppPalette.ocean),
  frost('Frost', AppPalette.frost),
  grape('Grape', AppPalette.grape),
  rose('Rose', AppPalette.rose),
  mono('Mono', AppPalette.mono);

  const AppThemeChoice(this.label, this.palette);

  final String label;
  final AppPalette palette;

  /// The theme stored as [id]; the default one if unknown.
  static AppThemeChoice fromId(String id) =>
      values.where((t) => t.name == id).firstOrNull ?? values.first;
}

/// The active palette: `context.colors.accent`. Outside the app's theme
/// (e.g. a widget shown on its own in a test) it's the default, Clay.
extension AppColorsOf on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.clay;
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
  teal('Teal', Color(0xFF1C3D3A), Color(0xFF4DB6AC)),
  blue('Blue', Color(0xFF1F3449), Color(0xFF64B5F6)),
  purple('Purple', Color(0xFF382A4B), Color(0xFFB39DDB)),
  pink('Pink', Color(0xFF4A2338), Color(0xFFF48FB1)),
  brown('Brown', Color(0xFF3D3029), Color(0xFFBCAAA4)),
  grey('Grey', Color(0xFF2F3337), Color(0xFFB0BEC5));

  final String label;
  final Color fill;
  final Color stripe;

  const BlockColor(this.label, this.fill, this.stripe);

  /// New tasks and routines start with these (P19).
  static const taskDefault = blue;
  static const routineDefault = purple;

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
      // No tooltip pops up on a long press (Round 15: seen holding − in
      // the shop). The message still names the button for screen readers.
      tooltipTheme: const TooltipThemeData(
        triggerMode: TooltipTriggerMode.manual,
      ),
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
      // A selected row's text in the accent, readable on the surfaces.
      listTileTheme: ListTileThemeData(
        selectedColor: palette.accentForeground ?? palette.accent,
      ),
      // Messages at the bottom (e.g. "… deleted · Undo", U7): a rounded
      // card in the app's colours, floating above the bottom buttons,
      // with the action in the accent.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // The card colour (the menu's is too light for the accent action
        // to read in some themes), with a thin edge to stand out.
        backgroundColor: palette.card,
        contentTextStyle: TextStyle(color: palette.textPrimary, fontSize: 15),
        actionTextColor: palette.accentForeground ?? palette.accent,
        elevation: 4,
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: palette.textHint.withValues(alpha: 0.5)),
        ),
      ),
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
      // No button fades between states (U8): turning on, the label took
      // its colour over 200 ms while the fill changed at once, so it showed
      // grey on the new fill first, a flash (Nikola). Every button kind,
      // so new ones can't bring it back.
      filledButtonTheme: const FilledButtonThemeData(style: _noFade),
      elevatedButtonTheme: const ElevatedButtonThemeData(style: _noFade),
      outlinedButtonTheme: const OutlinedButtonThemeData(style: _noFade),
      textButtonTheme: TextButtonThemeData(
        style: _noFade.merge(
          TextButton.styleFrom(
            foregroundColor: palette.accentForeground ?? palette.accent,
          ),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(style: _noFade),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.accent,
        unselectedItemColor: palette.inactive,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  /// Buttons change state at once (U8).
  static const _noFade = ButtonStyle(animationDuration: Duration.zero);

  /// The default look (Clay).
  static ThemeData get dark => of(AppPalette.clay);
}

/// How a dose went, in the same colours whatever the theme (Round 18):
/// green taken, red missed, amber not sure. Bright enough to read as text
/// on every (dark) theme, and dark text reads on them.
abstract final class DoseColours {
  static const taken = Color(0xFF4CAF50);
  static const missed = Color(0xFFEF5350);
  static const unsure = Color(0xFFFFB300);
}

/// How a meal went (Round 46), green to red like a dose's, whatever the
/// theme; [ink] (a face, a day's number) reads on each of them.
abstract final class RatingColours {
  static const great = DoseColours.taken;
  static const good = Color(0xFF9CCC65);
  static const ok = DoseColours.unsure;
  static const bad = Color(0xFFFF7043);
  static const awful = DoseColours.missed;
  static const ink = Color(0xFF000000);
}

/// Pip's own colours (Round 25), the launcher icon's, whatever the theme.
abstract final class PipColours {
  static const casing = Color(0xFFD97757); // head casing, antenna
  static const body = Color(0xFFC96442); // body, feet
  static const screen = Color(0xFFF5F0E8);
  static const face = Color(0xFF141413); // eyes, mouth
  static const shade = Color(0xFFA84F33); // under the body, feet
  static const light = Color(0xFFF2C07A); // the antenna's light
  static const eggShade = Color(0xFFD8D0C2); // his egg's shade (Round 34)

  // His sky (Round 35), top and bottom of each part of the day; Round 52:
  // more hues between them (the stops, top to bottom).
  static const nightTop = Color(0xFF0B1022);
  static const nightBottom = Color(0xFF3A3F72);
  static const nightStops = [
    nightTop,
    Color(0xFF131C3C),
    Color(0xFF1E2A55),
    Color(0xFF2C3566),
    nightBottom,
  ];
  static const dawnTop = Color(0xFF2E3A6B);
  static const dawnBottom = Color(0xFFF7D49A);
  static const dawnStops = [
    dawnTop,
    Color(0xFF5A5490),
    Color(0xFF9C6DA0),
    Color(0xFFD9849A),
    Color(0xFFF2A880),
    dawnBottom,
  ];
  static const dayTop = Color(0xFF3F78C0);
  static const dayBottom = Color(0xFFDDEFF5);
  static const dayStops = [
    dayTop,
    Color(0xFF5590D0),
    Color(0xFF79AEDF),
    Color(0xFFA2CBEC),
    Color(0xFFC6E2F2),
    dayBottom,
  ];
  static const duskTop = Color(0xFF221D4C);
  static const duskBottom = Color(0xFFF7C46C);
  static const duskStops = [
    duskTop,
    Color(0xFF412C6E),
    Color(0xFF6E3878),
    Color(0xFFA6447A),
    Color(0xFFD65A66),
    Color(0xFFEE8452),
    duskBottom,
  ];
  // Round 52: clouds with light and shade (tinted at dawn and dusk), the
  // sun's glow and highlight, the moon's halo and craters, coloured stars.
  static const cloudLight = Color(0xFFFFFFFF);
  static const cloudShade = Color(0xFFC9D7E8);
  static const cloudWarm = Color(0xFFFBE3E3);
  static const cloudWarmShade = Color(0xFFD99AA8);
  static const sunCore = Color(0xFFFFF0B8);
  static const sunLow = Color(0xFFFFA65A); // at dawn
  static const moonDark = Color(0xFF9C9D96);
  static const starWarm = Color(0xFFFFE2A8);
  static const starCool = Color(0xFFA8C8FF);
  static const star = Color(0xFFF5F0E8);
  static const starDim = Color(0xFF7D88AA); // most stars (Round 38)
  static const moon = Color(0xFFE4E4DC); // pale grey, not the sun's yellow
  static const moonShade = Color(0xFFB9BAB3); // its seas
  static const sun = Color(0xFFFFD36E);
  static const cloud = Color(0xFFF2F4F8);

  // His room (Round 26): grass on dirt.
  static const grass = Color(0xFF5E8C3A);
  static const grassLight = Color(0xFF86B85A);
  static const dirt = Color(0xFF6B4423);
  static const dirtDark = Color(0xFF4E301A);

  // Round 37: his screen asleep and off; batteries and energy.
  static const screenAsleep = Color(0xFFD9D2C4);
  static const screenOff = Color(0xFF2E2C2A);
  static const screenGlint = Color(0xFF45423F);
  static const batteryCase = Color(0xFF8C8C88);
  static const batteryCap = Color(0xFF5A5A58);
  static const energyFull = Color(0xFF5FBF4A); // green
  static const energyHalf = Color(0xFFE8963A); // orange
  static const energyLow = Color(0xFFE0503E); // red
  static const energyEmpty = Color(0xFF4A4744);
  // Round 42: a battery's charge is blue (his energy stays green to red).
  static const batteryCharge = Color(0xFF4A9BE8);

  // Round 44: his charging station, its cable and plug.
  static const stationEdge = Color(0xFF3A3B40);
  static const stationBody = Color(0xFF9A9CA0);
  static const stationLight = Color(0xFFB8BBC0);
  static const stationDark = Color(0xFF5E6066);
  static const stationPanel = Color(0xFF1E1F22);
  static const stationBolt = Color(0xFFFFD36E);
  static const lampOn = Color(0xFF7FE06A);
  static const lampOff = Color(0xFF3E7A33);
  static const cable = Color(0xFF2E2C2A);
  static const staticLight = Color(0xFFC8C4BC);
  static const staticDark = Color(0xFF9A958C);

  // Round 52: things in his field, and his sword.
  static const bug = Color(0xFF6CC24A); // a computer bug: green
  static const bugDark = Color(0xFF3E7A2C);
  static const bugEye = Color(0xFFE0503E);
  static const blade = Color(0xFFDDE3EA);
  static const bladeEdge = Color(0xFF9AA4B0);
  static const bladeShine = Color(0xFFFFFFFF);
  static const guard = Color(0xFFE0B040);
  static const hilt = Color(0xFF7A4A2A);
  static const petal = Color(0xFFF07AA8);
  static const petalDark = Color(0xFFC9537F);
  static const flowerHeart = Color(0xFFFFD36E);
  static const stem = Color(0xFF4F8A34);
  static const wing = Color(0xFFF5A23A);
  static const wingDark = Color(0xFF8A4A16);
  static const ball = Color(0xFFE0503E);
  static const ballStripe = Color(0xFFF5F0E8);
  static const cross = Color(0xFFE0503E); // his cross words (#!)
  static const heart = Color(0xFFE0503E);
  static const puff = Color(0xFFF2F4F8);

  // Pip Home's card (Round 35): a game's panel, whatever the theme.
  static const panel = Color(0xFF231F1D);
  static const panelEdge = Color(0xFF4A3F38);
  static const key = Color(0xFF36302C);
  static const dim = Color(0xFF9A8F86); // quieter words on the panel
}
