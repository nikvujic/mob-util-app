import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/weather.dart';
import 'package:the_app/data/weather_api.dart';
import 'package:the_app/models/internet.dart';
import 'package:the_app/widgets/pip_room.dart';

/// Round 79: his trees sway only in the wind.
void main() {
  final at = DateTime(2026, 10, 19, 12);
  const place = WeatherPlace(
    id: '1',
    name: 'Belgrade',
    region: '',
    country: 'Serbia',
    latitude: 44.8,
    longitude: 20.5,
  );

  test('the wind by its speed (km/h); a storm\'s windy; unknown: calm', () {
    expect(PipWind.of(0, WeatherKind.clear), PipWind.calm);
    expect(PipWind.of(11.9, WeatherKind.rain), PipWind.calm);
    expect(PipWind.of(12, WeatherKind.clear), PipWind.breeze);
    expect(PipWind.of(29.9, null), PipWind.breeze);
    expect(PipWind.of(30, WeatherKind.clear), PipWind.windy);
    expect(PipWind.of(3, WeatherKind.storm), PipWind.windy);
    // Round 80: the weather off (not known), still.
    expect(PipWind.of(null, WeatherKind.clear), PipWind.calm);
    expect(PipWind.of(null, null), PipWind.calm);
  });

  test('read from Open-Meteo, kept, and missing from older reports', () {
    final report = parseReport({
      'current': {
        'weather_code': 0,
        'temperature_2m': 14.2,
        'wind_speed_10m': 22.5,
      },
    }, place, at);
    expect(report.wind, 22.5);
    final back = WeatherReport.fromJson(report.toJson());
    expect(back.wind, 22.5);
    final none = parseReport({
      'current': {'weather_code': 0, 'temperature_2m': 14.2},
    }, place, at);
    expect(none.wind, isNull);
    expect(none.toJson().containsKey('wind'), isFalse);
    expect(WeatherReport.fromJson(none.toJson()).wind, isNull);
    // And asked for.
    expect(OpenMeteoApi.currentFields.split(','),
        containsAll(['weather_code', 'temperature_2m', 'wind_speed_10m']));
  });

  test('the scene: the real wind; tried on in Pip Home, wet is windy', () {
    PipWind wind(double? speed, {int? code, PipLook look = PipLook.none}) =>
        PipScene.at(PipPlace.room, at,
                weatherCode: code, windSpeed: speed, look: look)
            .wind;
    expect(wind(4, code: 61), PipWind.calm, reason: 'rain, no wind');
    expect(wind(40, code: 0), PipWind.windy, reason: 'clear, windy');
    expect(wind(null), PipWind.calm, reason: 'the weather off: still');
    expect(wind(4, code: 95), PipWind.windy, reason: 'a storm');
    expect(wind(4, code: 0, look: const PipLook(weather: WeatherKind.rain)),
        PipWind.windy);
    expect(wind(40, code: 0, look: const PipLook(weather: WeatherKind.clear)),
        PipWind.breeze);
  });

  test('his trees: still when calm, a light sway, harder when windy', () {
    Set<double> sways(PipWind wind) => {
          for (var t = 0.0; t < 6; t += 0.05) treeSway(wind, t, 0, 1),
        };
    expect(sways(PipWind.calm), {0.0});
    expect(sways(PipWind.breeze), {-1.0, 0.0, 1.0});
    expect(sways(PipWind.windy), containsAll([-2.0, 2.0]));
    // The trunk (no reach) never moves.
    expect(treeSway(PipWind.windy, 0.6, 0, 0), 0);
  });
}
