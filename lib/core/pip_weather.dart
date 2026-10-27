import 'dart:math' as math;

import 'package:the_app/core/weather.dart';

/// Round 75: what the weather makes of Pip's days ("a bunch of
/// events that can entertain"). This is the one place that says what
/// each weather does while he's doing what; his brain follows it.
///
/// | Weather | Up and about | Asleep, off | Busy (an event, an entrance, his station, his battery) | Out (his adventure) |
/// |---|---|---|---|---|
/// | Storm | his **tent** goes up round him; inside he can't move, nothing happens, a battery flies into it | the tent goes up over him | when it's done, the tent | a tent by the path; he waits it out |
/// | Rain | his **umbrella**, open; puddle jumps, a twirl | put away | put away | splashes at his feet |
/// | Drizzle | now and then a hand held out | | | |
/// | Snow | a **snowman**, flakes on his tongue, a snowball at you | | | snowmen among the bugs |
/// | Fog | walks slowly; now and then lost | | | runs slower; foes loom out of it |
///
/// A change of weather is seen: rain and snow come in (and go) over a
/// few seconds, and he stops to look up.
enum PipCover {
  /// Nothing over him.
  none,

  /// His umbrella, open over his head (rain).
  umbrella,

  /// His tent, him inside (a storm).
  tent,
}

/// What [weather] puts over him.
PipCover coverFor(WeatherKind? weather) => switch (weather) {
      WeatherKind.storm => PipCover.tent,
      WeatherKind.rain => PipCover.umbrella,
      _ => PipCover.none,
    };

/// How fast he walks (or runs out) in [weather]: slower in fog.
double paceIn(WeatherKind? weather) => weather == WeatherKind.fog ? 0.55 : 1;

/// The weather's events (Round 75), each in its own weather.
enum PipWeatherEvent {
  /// Rain: he jumps in a puddle, a splash.
  puddle,

  /// Rain: a twirl under his umbrella.
  twirl,

  /// Drizzle: a hand held out, palm up, to feel it.
  handOut,

  /// Snow: flakes caught on his tongue.
  flakes,

  /// Snow: he builds a snowman; it stays while the snow lasts.
  snowman,

  /// Snow: a snowball thrown at you; it splats on the glass.
  snowball,

  /// Fog: lost, a question mark, looking this way and that.
  lost,
}

/// The weather [event] happens in (Pip Home's list tries it on).
WeatherKind weatherFor(PipWeatherEvent event) => switch (event) {
      PipWeatherEvent.puddle || PipWeatherEvent.twirl => WeatherKind.rain,
      PipWeatherEvent.handOut => WeatherKind.drizzle,
      PipWeatherEvent.flakes ||
      PipWeatherEvent.snowman ||
      PipWeatherEvent.snowball =>
        WeatherKind.snow,
      PipWeatherEvent.lost => WeatherKind.fog,
    };

/// The events that can happen in [weather] (none in a storm: he's in his
/// tent), and in [snowy] fields (a ski day's snow).
List<PipWeatherEvent> weatherEventsIn(WeatherKind? weather,
        {bool snowy = false}) =>
    switch (weather) {
      WeatherKind.rain => const [PipWeatherEvent.puddle, PipWeatherEvent.twirl],
      WeatherKind.drizzle => const [PipWeatherEvent.handOut],
      WeatherKind.snow => const [
          PipWeatherEvent.snowman,
          PipWeatherEvent.flakes,
          PipWeatherEvent.snowball,
        ],
      WeatherKind.fog => const [PipWeatherEvent.lost],
      _ => snowy
          ? const [PipWeatherEvent.snowman, PipWeatherEvent.snowball]
          : const [],
    };

/// The chance a moment free for an event goes to the weather's: most of
/// them while it's doing something.
const weatherEventShare = 0.6;

/// His tent (a storm): going up round him, up (him inside), coming down.
enum TentPhase { pitching, up, packing }

class PipTent {
  PipTent(this.left);

  /// Its left edge in the room, and its size.
  final double left;
  static const width = 30;
  static const height = 19;

  TentPhase phase = TentPhase.pitching;
  double _t = 0;

  static const pitchTime = 1.6;
  static const packTime = 1.2;

  /// How far up it is, 0 (flat) to 1.
  double get up => switch (phase) {
        TentPhase.pitching => math.min(1, _t / pitchTime),
        TentPhase.up => 1,
        TentPhase.packing => math.max(0, 1 - _t / packTime),
      };

  /// Down and folded away: gone.
  bool get gone => phase == TentPhase.packing && _t >= packTime;

  /// Up enough to hide him.
  bool get hides => up >= 0.6;

  void step(double dt) {
    _t += dt;
    if (phase == TentPhase.pitching && _t >= pitchTime) {
      phase = TentPhase.up;
      _t = 0;
    }
  }

  /// The storm's over: it comes down (from as far up as it got).
  void pack() {
    if (phase == TentPhase.packing) return;
    final from = up;
    phase = TentPhase.packing;
    _t = (1 - from) * packTime;
  }

  /// Back up (the storm's back while it came down).
  void repitch() {
    if (phase != TentPhase.packing) return;
    final from = up;
    phase = TentPhase.pitching;
    _t = from * pitchTime;
  }
}

/// His umbrella (rain): opening over his head, open, closing.
class PipUmbrella {
  /// How open it is, 0 (shut, gone) to 1.
  double open = 0;

  static const openTime = 0.5;

  /// Opens while [wanted], shuts otherwise.
  void step(double dt, {required bool wanted}) {
    final by = dt / openTime;
    open = (wanted ? open + by : open - by).clamp(0.0, 1.0);
  }

  bool get shown => open > 0;
}

/// A snowman he built: where, how far built (0 to 1), and how far melted
/// (0 to 1; gone at 1).
class PipSnowman {
  PipSnowman(this.left);

  final double left;
  static const width = 12;

  double built = 0;
  double melted = 0;

  static const meltTime = 12.0;

  bool get gone => melted >= 1;

  /// Its parts, by how far built: the base, the body, the head, his face
  /// and arms.
  static const baseUntil = 0.4;
  static const bodyUntil = 0.7;
  static const headUntil = 0.85;
}

/// A snowball thrown at you (snow): flying out of the room towards you,
/// then splatted on the glass where it hit, sliding a little and fading.
class PipSplat {
  PipSplat(
      {required this.fromX,
      required this.fromUp,
      required this.x,
      required this.y});

  /// Where it was thrown from (room pixels: x, height above the ground)
  /// and where it hits the glass (room pixels from the top left).
  final double fromX, fromUp, x, y;

  double t = 0;
  static const flyTime = 0.45;
  static const stayTime = 3.0;

  bool get flying => t < flyTime;
  bool get gone => t >= flyTime + stayTime;

  /// How far it's flown (0 to 1), and, splatted, how far faded.
  double get flight => math.min(1, t / flyTime);
  double get fade => flying ? 0 : (t - flyTime) / stayTime;
}

/// How far a new weather has come in (Round 75: rain and snow thicken over
/// [comeIn] seconds; 1: all there).
const comeIn = 4.0;
