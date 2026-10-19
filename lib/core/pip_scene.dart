import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:the_app/core/pip_hats.dart' show orthodoxEaster;
import 'package:the_app/core/theme.dart';
import 'package:the_app/core/weather.dart';

/// Where Pip is shown (Round 35): the menu's strip, or Pip Home's tall
/// scene. Each has its own version of a background.
enum PipPlace { room, home }

/// The part of the day his sky follows.
enum DayPart { night, dawn, day, dusk }

/// The season his field is in (Round 70), by the month: spring from
/// March, summer from June, autumn from September, winter from December.
enum Season {
  spring('Spring'),
  summer('Summer'),
  autumn('Autumn'),
  winter('Winter');

  final String label;

  const Season(this.label);

  static Season of(DateTime day) => switch (day.month) {
        3 || 4 || 5 => spring,
        6 || 7 || 8 => summer,
        9 || 10 || 11 => autumn,
        _ => winter,
      };
}

/// Days his field dresses up for (Round 70).
///
/// - **Halloween**, 24–31 October: jack-o'-lanterns (lit after dark),
///   bats at night.
/// - **New Year's Eve**, all 31 December and on to 1 January 02:00
///   (Round 72: no Christmas weeks before it): a decorated pine, its
///   lights blinking; fireworks after dark.
/// - **Christmas** (Round 72), the Orthodox one on 7 January, as kept
///   where the app's made: a badnjak (an oak branch, its dry leaves on,
///   tied with a red ribbon), straw on the ground, a lit candle.
/// - **Easter**, Orthodox Easter Sunday and Monday: painted eggs in the
///   grass.
enum PipOccasion {
  halloween('Halloween'),
  newYear("New Year's Eve"),
  christmas('Christmas'),
  easter('Easter');

  final String label;

  const PipOccasion(this.label);

  /// [now]'s occasion, if any.
  static PipOccasion? at(DateTime now) {
    final (m, d, h) = (now.month, now.day, now.hour);
    if ((m == 12 && d == 31) || (m == 1 && d == 1 && h < 2)) return newYear;
    if (m == 1 && d == 7) return christmas;
    if (m == 10 && d >= 24) return halloween;
    final sunday = orthodoxEaster(now.year);
    final day = DateTime(now.year, m, d);
    if (day == sunday ||
        day == DateTime(sunday.year, sunday.month, sunday.day + 1)) {
      return PipOccasion.easter;
    }
    return null;
  }
}

/// [now]'s part of the day (Round 59: with the seasons): dawn from 45
/// minutes before sunrise to 20 after, day to 20 minutes before sunset,
/// dusk to 35 after, night otherwise. October evenings get dark before
/// seven, June ones only after nine.
DayPart dayPartAt(DateTime now) {
  final m = now.hour * 60 + now.minute;
  final (rise, set) = sunTimesOn(now);
  if (m < rise - 45) return DayPart.night;
  if (m < rise + 20) return DayPart.dawn;
  if (m < set - 20) return DayPart.day;
  if (m < set + 35) return DayPart.dusk;
  return DayPart.night;
}

/// The latitude his sun follows: the middle of Europe (the app has no
/// location; 45° is within a few minutes of anywhere from Rome to Prague
/// along the same time zone).
const sunLatitude = 45.0;

/// Sunrise and sunset on [day] (Round 59), in minutes into its day, by
/// the phone's clock: worked out for [sunLatitude] on the middle meridian
/// of the phone's time zone (15° an hour), an hour later in summer time.
/// [zone] and [standardZone] (its offset that day, and outside summer
/// time) are the phone's unless given (tests: another time zone).
(double, double) sunTimesOn(
  DateTime day, {
  Duration? zone,
  Duration? standardZone,
}) {
  final local = day.toLocal();
  final dayOfYear = DateTime.utc(local.year, local.month, local.day)
          .difference(DateTime.utc(local.year))
          .inDays +
      1;
  // Summer time: the zone's offset now beyond its smaller one of the year.
  final january = DateTime(local.year).timeZoneOffset;
  final july = DateTime(local.year, 7).timeZoneOffset;
  final standard = standardZone ?? (january < july ? january : july);
  final summer = (zone ?? local.timeZoneOffset) - standard;
  final longitude = standard.inMinutes / 4; // 15° an hour

  // NOAA's approximations, at noon.
  final g = 2 * math.pi / 365 * (dayOfYear - 1);
  final eqTime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(g) -
          0.032077 * math.sin(g) -
          0.014615 * math.cos(2 * g) -
          0.040849 * math.sin(2 * g));
  final decl = 0.006918 -
      0.399912 * math.cos(g) +
      0.070257 * math.sin(g) -
      0.006758 * math.cos(2 * g) +
      0.000907 * math.sin(2 * g) -
      0.002697 * math.cos(3 * g) +
      0.00148 * math.sin(3 * g);
  final lat = sunLatitude * math.pi / 180;
  final cosHa =
      math.cos(90.833 * math.pi / 180) / (math.cos(lat) * math.cos(decl)) -
          math.tan(lat) * math.tan(decl);
  final ha = math.acos(cosHa.clamp(-1.0, 1.0)) * 180 / math.pi;
  // Minutes after midnight UTC, then the phone's clock.
  final shift = standard.inMinutes + summer.inMinutes;
  final rise = 720 - 4 * (longitude + ha) - eqTime + shift;
  final set = 720 - 4 * (longitude - ha) - eqTime + shift;
  return (rise, set);
}

/// The moon's phase (Round 38), as his sky shows it: none (new moon),
/// thin, half or full, growing (lit on the right) or shrinking (left).
enum MoonPhase {
  none,
  thinGrowing,
  halfGrowing,
  full,
  halfShrinking,
  thinShrinking;

  /// Lit on the right (growing), else on the left.
  bool get growing => this == thinGrowing || this == halfGrowing;
}

/// A new moon to count from (6 January 2000, 18:14 UTC), and the length
/// of the moon's month, in days.
final _newMoon = DateTime.utc(2000, 1, 6, 18, 14);
const _moonMonth = 29.530588853;

/// How far through its month the moon is at [now]: 0 new, 0.5 full.
double moonAgeAt(DateTime now) {
  final days = now.toUtc().difference(_newMoon).inMinutes / (24 * 60);
  return (days / _moonMonth) % 1;
}

/// The real moon's phase at [now], to the nearest of the four shapes.
MoonPhase moonPhaseAt(DateTime now) {
  final age = moonAgeAt(now);
  if (age < 0.0625) return MoonPhase.none;
  if (age < 0.1875) return MoonPhase.thinGrowing;
  if (age < 0.375) return MoonPhase.halfGrowing;
  if (age < 0.625) return MoonPhase.full;
  if (age < 0.8125) return MoonPhase.halfShrinking;
  if (age < 0.9375) return MoonPhase.thinShrinking;
  return MoonPhase.none;
}

/// A background for his field (Round 35): a sky for each part of the day.
/// One for now ("Field"); more can come, each saying how it looks.
enum PipBackground {
  field('Field');

  final String label;

  const PipBackground(this.label);

  /// The one stored as [id]; his field if there's none (Round 36).
  static PipBackground byId(String id) =>
      values.where((b) => b.name == id).firstOrNull ?? field;

  /// The sky's top and bottom colours at [part].
  (Color, Color) skyAt(DayPart part) => switch (part) {
        DayPart.night => (PipColours.nightTop, PipColours.nightBottom),
        DayPart.dawn => (PipColours.dawnTop, PipColours.dawnBottom),
        DayPart.day => (PipColours.dayTop, PipColours.dayBottom),
        DayPart.dusk => (PipColours.duskTop, PipColours.duskBottom),
      };

  /// The sky's colours at [part], top to bottom (Round 52: more hues than
  /// its top and bottom, e.g. dusk's indigo to purple, pink, orange, gold).
  List<Color> stopsAt(DayPart part) => switch (part) {
        DayPart.night => PipColours.nightStops,
        DayPart.dawn => PipColours.dawnStops,
        DayPart.day => PipColours.dayStops,
        DayPart.dusk => PipColours.duskStops,
      };
}

/// Things drawn in his sky (Round 35) and field (Round 70). Each says
/// where it may show: in which places, at which parts of the day, on
/// which backgrounds; [PipScene.at] adds the season, the occasion and
/// the weather, so nothing turns up where it doesn't belong.
enum PipProp {
  stars(parts: {DayPart.night}),
  moon(parts: {DayPart.night, DayPart.dusk}),
  sun(parts: {DayPart.day, DayPart.dawn}),
  // In both since the menu's room grew (Round 36); at night too under a
  // grey sky (Round 70).
  clouds(parts: {DayPart.day, DayPart.dawn, DayPart.dusk}),

  // Round 70: his field.
  /// A tree or two in their season's colours, swaying.
  trees,

  /// Autumn's leaves falling, and some on the grass.
  leaves,

  /// Spring's blossom petals drifting down.
  petals,

  /// Halloween's jack-o'-lanterns (lit after dark), and bats at night.
  pumpkins,
  bats(parts: {DayPart.night, DayPart.dusk}),

  /// New Year's Eve's decorated pine, its lights blinking.
  festiveTree,

  /// Christmas's badnjak, straw and candle (Round 72).
  badnjak,

  /// New Year's Eve's fireworks, after dark.
  fireworks(parts: {DayPart.night, DayPart.dusk}),

  /// Easter's painted eggs in the grass.
  eggs,

  /// The weather: rain (drizzle lighter), snow falling, a storm's
  /// lightning, fog.
  rain,
  snowfall,
  lightning,
  fog;

  final Set<DayPart> parts;

  /// All in both places and on his one background, for now.
  Set<PipPlace> get places => const {PipPlace.room, PipPlace.home};
  Set<PipBackground> get backgrounds => const {PipBackground.field};

  const PipProp({
    this.parts = const {
      DayPart.night,
      DayPart.dawn,
      DayPart.day,
      DayPart.dusk,
    },
  });

  bool showsIn(PipPlace place, DayPart part, PipBackground background) =>
      places.contains(place) &&
      parts.contains(part) &&
      backgrounds.contains(background);
}

/// What's tried on his field in Pip Home (Round 70), over what now is:
/// a season, the weather, an occasion, a part of the day. Not kept.
class PipLook {
  final Season? season;
  final WeatherKind? weather;
  final PipOccasion? occasion;
  final DayPart? part;

  const PipLook({this.season, this.weather, this.occasion, this.part});

  static const none = PipLook();

  bool get isNone =>
      season == null && weather == null && occasion == null && part == null;

  /// [key] tried, or untried if it was (one of each kind at a time).
  PipLook toggled(Object key) => switch (key) {
        Season s => PipLook(
            season: season == s ? null : s,
            weather: weather,
            occasion: occasion,
            part: part),
        WeatherKind w => PipLook(
            season: season,
            weather: weather == w ? null : w,
            occasion: occasion,
            part: part),
        PipOccasion o => PipLook(
            season: season,
            weather: weather,
            occasion: occasion == o ? null : o,
            part: part),
        DayPart p => PipLook(
            season: season,
            weather: weather,
            occasion: occasion,
            part: part == p ? null : p),
        _ => this,
      };
}

/// What's showing in one place at one moment: the one place that works it
/// out (Round 35), so the menu and Pip Home can't disagree.
class PipScene {
  final PipPlace place;

  /// Null: no background (turned off): his field on the page's own colour.
  final PipBackground? background;
  final DayPart part;
  final Set<PipProp> props;

  /// The real moon's phase (Round 38); at a new moon there's no moon.
  final MoonPhase moon;

  /// Round 70: the season, the day's occasion, and the weather (null:
  /// none known, a plain sky); how heavy its rain or snow is, 1 to 3.
  final Season season;
  final PipOccasion? occasion;
  final WeatherKind? weather;
  final int strength;

  const PipScene._(
    this.place,
    this.background,
    this.part,
    this.props,
    this.moon, {
    required this.season,
    this.occasion,
    this.weather,
    this.strength = 0,
  });

  /// [weather]: Open-Meteo's code now (Round 70), if it's on; [look]:
  /// what Pip Home is trying on, over all of it.
  factory PipScene.at(
    PipPlace place,
    DateTime now, {
    PipBackground? background = PipBackground.field,
    int? weatherCode,
    PipLook look = PipLook.none,
  }) {
    final part = look.part ?? dayPartAt(now);
    final moon = moonPhaseAt(now);
    final season = look.season ?? Season.of(now);
    final occasion =
        look.occasion ?? (look.isNone ? PipOccasion.at(now) : null);
    final real = weatherCode == null ? null : WeatherKind.fromCode(weatherCode);
    final weather = look.weather ?? real;
    final strength = look.weather != null
        ? 2
        : weatherCode == null
            ? 0
            : weatherStrength(weatherCode);
    final grey = weather?.grey ?? false;
    bool shows(PipProp prop) => switch (prop) {
          // A grey sky hides the sun, the moon and the stars.
          PipProp.stars || PipProp.sun => !grey,
          PipProp.moon => !grey && moon != MoonPhase.none,
          PipProp.clouds => true,
          // The day's own tree instead.
          PipProp.trees => occasion != PipOccasion.newYear &&
              occasion != PipOccasion.christmas,
          PipProp.leaves => season == Season.autumn,
          PipProp.petals => season == Season.spring && !grey,
          PipProp.pumpkins || PipProp.bats => occasion == PipOccasion.halloween,
          PipProp.festiveTree => occasion == PipOccasion.newYear,
          PipProp.badnjak => occasion == PipOccasion.christmas,
          PipProp.fireworks => occasion == PipOccasion.newYear,
          PipProp.eggs => occasion == PipOccasion.easter,
          PipProp.rain => weather?.wet ?? false,
          PipProp.snowfall => weather == WeatherKind.snow,
          PipProp.lightning => weather == WeatherKind.storm,
          PipProp.fog => weather == WeatherKind.fog,
        };
    return PipScene._(
      place,
      background,
      part,
      {
        if (background != null)
          for (final prop in PipProp.values)
            if (shows(prop) &&
                (prop.showsIn(place, part, background) ||
                    // Clouds at night under a grey sky.
                    (prop == PipProp.clouds && grey)))
              prop,
      },
      moon,
      season: season,
      occasion: occasion,
      weather: weather,
      strength: strength,
    );
  }

  /// A grey sky (Round 70): clouds over everything.
  bool get grey => weather?.grey ?? false;

  /// Snow on the ground: while it snows (a ski day's is the brain's).
  bool get snowyGround => weather == WeatherKind.snow;

  /// The sky's top and bottom colours, or null without a background.
  (Color, Color)? get sky {
    final s = skyStops;
    return s == null ? null : (s.first, s.last);
  }

  /// Its colours top to bottom (Round 52), or null without a background;
  /// greyed under a grey sky (Round 70), darker in a storm.
  List<Color>? get skyStops {
    final stops = background?.stopsAt(part);
    if (stops == null || !grey) return stops;
    final storm = weather == WeatherKind.storm;
    return [
      for (final c in stops)
        _greyed(c, storm ? 0.75 : 0.6, darker: storm ? 0.25 : 0),
    ];
  }
}

/// [c] moved [by] toward its own grey (and [darker]).
Color _greyed(Color c, double by, {double darker = 0}) {
  final grey = 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
  double mix(double v) => ((v + (grey - v) * by) * (1 - darker)).clamp(0, 1);
  return Color.from(alpha: c.a, red: mix(c.r), green: mix(c.g), blue: mix(c.b));
}
