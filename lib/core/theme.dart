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
/// stored; the first is the default (Clay, picked).
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
      // No touch ripples anywhere (they get in the way). Buttons
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
      // Round 81 (the tick was hard to see, on a coloured dot
      // worst): no tick; the one picked is plainly marked instead, filled
      // with a wash of the accent and edged in it (checked in every
      // theme).
      chipTheme: ChipThemeData(
        backgroundColor: palette.card,
        selectedColor: Color.alphaBlend(
            palette.accent.withValues(alpha: 0.24), palette.card),
        disabledColor: palette.surface,
        showCheckmark: false,
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(
                  color: palette.accentForeground ?? palette.accent, width: 1.5)
              : BorderSide(color: palette.divider),
        ),
        labelStyle: TextStyle(color: palette.textPrimary),
        secondaryLabelStyle: TextStyle(color: palette.textPrimary),
      ),
      // No button fades between states (U8): turning on, the label took
      // its colour over 200 ms while the fill changed at once, so it showed
      // grey on the new fill first, a flash. Every button kind,
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

/// Each kind of date's colour (Round 57), whatever the theme: its dots on
/// the calendar and its icon's circle.
abstract final class DateColours {
  static const birthday = Color(0xFFEC6FA0);
  static const anniversary = Color(0xFFE0503E);
  static const holiday = Color(0xFF4CAF7A);
  static const event = Color(0xFF4F8FE0);
  static const other = Color(0xFF9A8F86);
  static const ink = Color(0xFFFFFFFF); // its icon, on the colour
  static const seen = Color(0xFF4CAF50); // the green dot (a birthday)
}

/// Subscriptions' states (Round 79), whatever the theme: a card's tint
/// and edge.
abstract final class SubscriptionColours {
  static const active = Color(0xFF4CAF7A);
  static const toCancel = Color(0xFFE8913A);
  static const cancelled = Color(0xFF4F8FE0);
  static const inactive = Color(0xFF9A8F86);
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
  // Round 64: the tavern on his day out.
  static const roof = Color(0xFFA2463A);
  static const roofDark = Color(0xFF7A3129);
  // Round 74: the tavern's plaster walls, stone base, lighter planks.
  static const plaster = Color(0xFFEADFC4);
  static const stone = Color(0xFF9C948A);
  static const stoneDark = Color(0xFF6F6860);
  static const woodLight = Color(0xFFC99563);
  static const wood = Color(0xFFB07A4A);
  static const woodDark = Color(0xFF85552F);
  static const door = Color(0xFF6B4423);
  static const doorDark = Color(0xFF4E301A);
  static const windowGlow = Color(0xFFFFD98A);
  static const windowFrame = Color(0xFF5A3A20);
  static const chimney = Color(0xFF8C8C88);
  static const chimneyTop = Color(0xFF5A5A58);
  static const sign = Color(0xFFE8C48A);
  static const mug = Color(0xFFE8963A);
  // Round 67: his ski days.
  static const snow = Color(0xFFF2F5FA);
  static const snowShade = Color(0xFFCBD6E6);
  static const snowDark = Color(0xFFA9B8CF);
  static const flake = Color(0xFFFFFFFF);
  static const pine = Color(0xFF2E6040);
  static const pineDark = Color(0xFF1F4430);
  // Round 75: his tent, his umbrella, rain's puddles, a snowman's
  // carrot and coal.
  static const tent = Color(0xFFE07B39);
  static const tentDark = Color(0xFFB4562A);
  static const tentSeam = Color(0xFF8E4020);
  static const tentDoor = Color(0xFF3A2A22);
  static const umbrella = Color(0xFFD9423A);
  static const umbrellaLight = Color(0xFFF2EDE4);
  static const umbrellaHandle = Color(0xFF5A3A28);
  static const puddle = Color(0xFF5B7EA8);
  static const puddleLight = Color(0xFFA9C4E2);
  static const carrot = Color(0xFFF08A2C);
  static const coal = Color(0xFF2B2826);
  // Round 74: a pine's lit side; a birch's white bark and its marks.
  static const pineLight = Color(0xFF4A8A5A);
  static const birch = Color(0xFFEDE8DC);
  static const birchShade = Color(0xFFC9C2B2);
  static const birchMark = Color(0xFF3A3530);
  static const flagRed = Color(0xFFDC3C32);
  static const flagBlue = Color(0xFF3C64DC);
  static const pole = Color(0xFF5A5A58);
  static const ski = Color(0xFFE8963A);
  static const hotMug = Color(0xFFC0392B);
  static const cocoa = Color(0xFF6B3E26);
  static const steam = Color(0xFFE8E8E8);
  static const busYellow = Color(0xFFF2B632);
  static const busShade = Color(0xFFC88A1E);
  static const busGlass = Color(0xFF9CC7E0);
  // Round 72: the bigger bus's seats, trim and inside.
  static const busSeat = Color(0xFF4F6E8C);
  static const busTrim = Color(0xFF3A3632);
  static const busStripeShade = Color(0xFFA8382F);
  static const busInside = Color(0xFF5C6B78);
  static const road = Color(0xFF5A5A5E);
  static const roadDark = Color(0xFF45454A);
  static const roadLine = Color(0xFFF5F0E8);
  // Round 63: LEVEL UP, over him.
  static const levelUp = Color(0xFFFFD36E);
  static const levelUpShade = Color(0xFFB0702A);
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
  // Round 73: a beetle's blue shell, a spider's purple.
  static const beetle = Color(0xFF5B8FD6);
  static const beetleDark = Color(0xFF35609E);
  static const beetleBelly = Color(0xFF243F6B);
  static const spider = Color(0xFF9A6BC8);
  static const spiderDark = Color(0xFF6A3F94);
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
  // Round 57: his hats.
  static const hatPink = Color(0xFFF07AA8);
  static const hatYellow = Color(0xFFFFD36E);
  static const hatGold = Color(0xFFE8B23A);
  static const hatRuby = Color(0xFFE0503E);
  static const hatRubyDark = Color(0xFFA8382F);
  static const hatWhiteShade = Color(0xFFCFC8BA);
  static const hatSapphire = Color(0xFF4F8FE0);
  static const hatBlack = Color(0xFF2B2826);
  static const hatPurple = Color(0xFF6A4FB5);
  static const hatGreen = Color(0xFF3F9E6A);
  static const hatWhite = Color(0xFFF5F2EA);
  // Round 53: his plate and meal.
  static const plate = Color(0xFFF5F2EA);
  static const plateShade = Color(0xFFB9B4AA);
  static const meal = Color(0xFFD98A3A);
  static const mealDark = Color(0xFFA8642A);

  // Pip Home's card (Round 35): a game's panel, whatever the theme.
  static const panel = Color(0xFF231F1D);
  static const panelEdge = Color(0xFF4A3F38);
  static const key = Color(0xFF36302C);
  static const dim = Color(0xFF9A8F86); // quieter words on the panel

  // Round 72: the mountains at the ski slope's horizon.
  static const mountain = Color(0xFF8FA4C2);
  static const mountainShade = Color(0xFF7489AA);

  // Round 70: the seasons, occasions and weather in his field.
  static const leafSpring = Color(0xFF8CC65A);
  static const leafSpringDark = Color(0xFF5E9A3C);
  static const leafSpringLight = Color(0xFFB6E07E);
  static const blossom = Color(0xFFF7B8CC);
  static const blossomLight = Color(0xFFFCE0EA);
  static const leafSummer = Color(0xFF4F8E35);
  static const leafSummerDark = Color(0xFF356A26);
  static const leafAutumn = Color(0xFFE08A2E);
  static const leafAutumnDark = Color(0xFFB8521F);
  static const leafAutumnLight = Color(0xFFF2C14E);
  static const bark = Color(0xFF6E4A2E);
  static const barkDark = Color(0xFF4F3420);
  static const grassAutumn = Color(0xFF7D8A3A);
  static const grassAutumnLight = Color(0xFFA3A64C);
  static const grassWinter = Color(0xFF5F7A55);
  static const frost = Color(0xFFD8E4EA);
  static const pumpkin = Color(0xFFE5782A);
  static const pumpkinDark = Color(0xFFB4561A);
  static const pumpkinStem = Color(0xFF4F6B2A);
  static const pumpkinGlow = Color(0xFFFFD45A);
  static const bat = Color(0xFF15111C);
  static const lightRed = Color(0xFFE8463C);
  static const lightGold = Color(0xFFFFD45A);
  static const lightBlue = Color(0xFF5AB4F0);
  static const lightGreen = Color(0xFF7FE07A);
  static const starGold = Color(0xFFFFE07A);

  // Round 72: Christmas's badnjak (dry oak leaves), straw and candle.
  static const oakLeaf = Color(0xFFA8642A);
  static const oakLeafDark = Color(0xFF7A4520);
  static const straw = Color(0xFFE8C468);
  static const strawDark = Color(0xFFBF9A40);
  static const candle = Color(0xFFF2E2B0);
  static const candleShade = Color(0xFFD4BE80);
  static const eggPink = Color(0xFFF2A0C0);
  static const eggBlue = Color(0xFF8FC4F0);
  static const eggYellow = Color(0xFFF6DA6A);
  static const eggRed = Color(0xFFE0574A);
  static const raindrop = Color(0xFFB8CDE6);
  static const fog = Color(0xFFDCE2E8);
  static const lightning = Color(0xFFFFF6C8);
  static const cloudGrey = Color(0xFFB4BCC6);
  static const cloudGreyShade = Color(0xFF8E98A4);
  static const cloudGreyLight = Color(0xFFD2D8DE);
  static const cloudNight = Color(0xFF3A4150);
  static const cloudNightShade = Color(0xFF2C3240);
  static const cloudNightLight = Color(0xFF4A5262);
}

/// People's avatars and boxes (Round 108), whatever the theme: the
/// drafts' colours (`docs/people_avatar_drafts.png`).
abstract final class PeopleColours {
  static const male = Color(0xFF3F7BC8); // a highlighted box's border
  static const female = Color(0xFFD05A8C);
  static const maleBack = Color(0xFFA9CDF0); // behind the face
  static const femaleBack = Color(0xFFF5B8CF);
  static const greyBack = Color(0xFFD7D7D7); // deceased
  static const maleShirt = Color(0xFF2F5D9E);
  static const femaleShirt = Color(0xFFB84A72);
  static const outline = Color(0xFF2B2630);
  static const skin = Color(0xFFF2C9A0);
  static const skinShade = Color(0xFFD6A078);
  static const eye = Color(0xFF221E28);
  static const mouth = Color(0xFFB5525C);
  static const cheek = Color(0xFFF29696);
  static const freckle = Color(0xFFC47850);
  static const glasses = Color(0xFFB08C5C);
  static const beard = Color(0xFF7A583C);
  static const pacifier = Color(0xFF6EBEE1);
  static const ribbon = Color(0xFFE05478);
  static const grey = Color(0xFFAAAAB0);
  static const greyDark = Color(0xFF808088);
  static const white = Color(0xFFF0F0F0);
  static const whiteShade = Color(0xFFCDCDD2);
  static const blonde = Color(0xFFE8BE54);
  static const blondeShade = Color(0xFFC49634);
  static const brown = Color(0xFF6E4626);
  static const brownLight = Color(0xFF96643A);
  static const dark = Color(0xFF342620);
  static const darkLight = Color(0xFF5A4236);
  static const auburn = Color(0xFF964828);
  static const auburnLight = Color(0xFFBE6E46);
}

/// Round 109: the main person's family, highlighted on the People board.
abstract final class PeopleFamilyColours {
  static const ring = Color(0xFFE2A93B);
  static const starShadow = Color(0x55000000);
}

/// Round 126: Pip's house (his quest, `docs/QUESTS_SPEC.md`) and the
/// places he gathers in: the forest, the mine, the beach.
abstract final class PipHouseColours {
  // Stone: four shades, mortar, a lit edge.
  static const stone = [
    Color(0xFF84827C),
    Color(0xFF94928C),
    Color(0xFFA2A098),
    Color(0xFF76746E),
  ];
  static const mortar = Color(0xFF5C5A56);
  static const stoneLight = Color(0xFFBEBCB4);

  // Planks, their dark edge and grain; the back wall's darker boards.
  static const plank = [
    Color(0xFFB8824E),
    Color(0xFFC48E58),
    Color(0xFFAC7846)
  ];
  static const plankDark = Color(0xFF8C5C34);
  static const grain = Color(0xFFA06C3E);
  static const backWall = [
    Color(0xFF7A5230),
    Color(0xFF704A2A),
    Color(0xFF845A36),
  ];
  static const backWallDark = Color(0xFF5C3C22);

  // Log beams.
  static const beam = Color(0xFF563820);
  static const beamLight = Color(0xFF6E4A2C);
  static const beamDark = Color(0xFF3E2818);

  // Roof shingles and the trim along the eaves.
  static const roof = [Color(0xFF9C3A2E), Color(0xFFAA4636), Color(0xFF8E3228)];
  static const roofLight = Color(0xFFC66048);
  static const roofDark = Color(0xFF68261E);
  static const trim = Color(0xFFDECEB4);
  static const trimDark = Color(0xFFB4A48C);

  // Glass and the window frames.
  static const glass = Color(0xFFA0D2EC);
  static const glassLight = Color(0xFFE8F8FF);
  static const glassDark = Color(0xFF78B0D2);
  // Round 128: the night through them.
  static const nightGlass = Color(0xFF2C3C62);
  static const nightGlassLight = Color(0xFF52648E);
  static const nightGlassDark = Color(0xFF1E2A48);
  static const frame = Color(0xFFF0E8D6);
  static const frameDark = Color(0xFFBEB4A0);

  static const iron = Color(0xFF46464C);
  static const handle = Color(0xFFE2BA5A);

  // The fireplace's fire, its dark box, smoke.
  static const fire = Color(0xFFFF8C3C);
  static const fireLight = Color(0xFFFFDE82);
  static const firebox = Color(0xFF281E1A);
  static const ember = Color(0xFF784828);
  static const smoke = Color(0xFFD6D6DA);
  static const smokeDark = Color(0xFFB4B4BA);

  // His rain hat and lantern; the lantern's warm light.
  static const hat = Color(0xFFF4C634);
  static const hatDark = Color(0xFFC6941C);
  static const hatLight = Color(0xFFFFE278);
  static const lantern = Color(0xFFFFE082);

  // Rain inside an unfinished house, snow on it.
  static const drip = Color(0xFF82AAE2);
  static const snow = Color(0xFFFAFCFF);

  static const flowers = [
    Color(0xFFEC6060),
    Color(0xFFFAD650),
    Color(0xFFB48CE6)
  ];

  // The mine: its dark mouth, rails, cart, ore glints; far peaks.
  static const tunnel = Color(0xFF181414);
  static const tunnelEdge = Color(0xFF28221E);
  static const rail = Color(0xFF82828A);
  static const cart = Color(0xFF606068);
  static const cartLight = Color(0xFF8C8C96);
  static const wheel = Color(0xFF323238);
  static const ore = Color(0xFFCEA054);
  static const farPeak = Color(0xFF96A6B8);
  static const farPeakEdge = Color(0xFFB0BECE);
  static const gravel = Color(0xFF6E6052);
  static const gravelDark = Color(0xFF5A4E40);

  // The beach: sand, wet sand, the sea, foam; a shell, a starfish, the
  // bucket.
  static const sand = [Color(0xFFE2C886), Color(0xFFD6BA76), Color(0xFFECD69A)];
  static const sandDark = Color(0xFFB4965C);
  static const wetSand = Color(0xFFC4B080);
  static const seaDeep = Color(0xFF24649F);
  static const seaShallow = Color(0xFF6AB4D2);
  static const seaGlint = Color(0xFFDCF0FA);
  static const seaLine = Color(0xFF96C8E6);
  static const foam = Color(0xFFF4FAFC);
  static const foamShade = Color(0xFFD2EAF4);
  static const shell = Color(0xFFFAE6DC);
  static const shellShade = Color(0xFFE6B4AA);
  static const starfish = Color(0xFFF08C5A);
  static const bucket = Color(0xFFDC5A46);
  static const bucketRim = Color(0xFFF0785A);

  // The forest's haze over far trees.
  static const haze = Color(0xFFC4D6E2);
  static const mushroom = Color(0xFFC83C32);
  static const mushroomStalk = Color(0xFFE6E0D2);
}
