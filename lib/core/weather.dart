/// The weather as Pip's sky shows it (Round 70), from Open-Meteo's WMO
/// weather codes (https://open-meteo.com/en/docs: "weather_code").
enum WeatherKind {
  clear('Clear'),
  partlyCloudy('Partly cloudy'),
  cloudy('Cloudy'),
  fog('Fog'),
  drizzle('Drizzle'),
  rain('Rain'),
  snow('Snow'),
  storm('Thunderstorm');

  final String label;

  const WeatherKind(this.label);

  /// The kind for WMO [code]; null for a code it doesn't know.
  static WeatherKind? fromCode(int code) => switch (code) {
        0 || 1 => clear,
        2 => partlyCloudy,
        3 => cloudy,
        45 || 48 => fog,
        51 || 53 || 55 || 56 || 57 => drizzle,
        61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => rain,
        71 || 73 || 75 || 77 || 85 || 86 => snow,
        95 || 96 || 99 => storm,
        _ => null,
      };

  /// Rain, drizzle or a storm: drops falling.
  bool get wet => this == drizzle || this == rain || this == storm;

  /// A grey sky (clouds over the sun, or the stars).
  bool get grey => this == cloudy || this == fog || wet || this == snow;

  /// The id it's stored by.
  static WeatherKind? byName(String? name) =>
      values.where((k) => k.name == name).firstOrNull;
}

/// How windy it is (Round 79, Nikola: trees sway only in the wind).
enum PipWind {
  /// Still: the trees don't sway.
  calm,

  /// A light sway (also when the wind isn't known: the weather off).
  breeze,

  /// Swaying hard.
  windy;

  /// Below this (km/h, at 10 m) it's calm; from [windyFrom] windy.
  static const breezeFrom = 12.0;
  static const windyFrom = 30.0;

  /// The wind for [speed] km/h (null: not known, a breeze) in [weather]
  /// (a storm's windy whatever it says).
  static PipWind of(double? speed, WeatherKind? weather) {
    if (weather == WeatherKind.storm) return windy;
    if (speed == null) return breeze;
    if (speed >= windyFrom) return windy;
    return speed >= breezeFrom ? breeze : calm;
  }
}

/// How heavy a WMO [code]'s rain or snow is, 1 (light) to 3 (heavy); 0
/// for neither.
int weatherStrength(int code) => switch (code) {
      51 || 56 || 61 || 66 || 71 || 77 || 80 || 85 => 1,
      53 || 63 || 73 || 81 || 95 => 2,
      55 || 57 || 65 || 67 || 75 || 82 || 86 || 96 || 99 => 3,
      _ => 0,
    };
