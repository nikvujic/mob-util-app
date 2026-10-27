import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/weather.dart';
import 'package:the_app/data/weather_api.dart';
import 'package:the_app/models/internet.dart';
import 'package:the_app/models/preferences.dart';

/// The weather (Round 70): Open-Meteo's answers read, the WMO codes as
/// Pip's sky shows them, and what's kept on the phone.
void main() {
  const place = WeatherPlace(
      id: '1', name: 'Novi Sad', latitude: 45.25, longitude: 19.84);

  test('places from a search, as Open-Meteo answers', () {
    final places = parsePlaces({
      'results': [
        {
          'id': 3194360,
          'name': 'Novi Sad',
          'latitude': 45.25167,
          'longitude': 19.83694,
          'country': 'Serbia',
          'admin1': 'Vojvodina',
        },
        {'id': 9, 'name': 'Novi Sad', 'latitude': 1, 'longitude': 2},
        {'name': 'No position'},
      ],
      'generationtime_ms': 0.5,
    });
    expect(places.map((p) => (p.id, p.name, p.where)), [
      ('3194360', 'Novi Sad', 'Vojvodina, Serbia'),
      ('9', 'Novi Sad', ''),
    ]);
    expect(places.first.latitude, 45.25167);
    expect(parsePlaces({'generationtime_ms': 0.5}), isEmpty,
        reason: 'nothing found: no "results"');
  });

  test('the weather now, as Open-Meteo answers', () {
    final at = DateTime(2026, 10, 19, 10);
    final report = parseReport({
      'current': {
        'time': '2026-10-19T08:00',
        'interval': 900,
        'weather_code': 73,
        'temperature_2m': -1.6,
      },
    }, place, at);
    expect((report.code, report.temperature), (73, -1.6));
    expect(WeatherKind.fromCode(report.code), WeatherKind.snow);
    expect((report.placeId, report.fetchedAt), ('1', at));
    expect(() => parseReport({'current': {}}, place, at),
        throwsA(isA<WeatherFailure>()));
    expect(() => parseReport({}, place, at), throwsA(isA<WeatherFailure>()));
  });

  test('WMO codes: what the sky shows', () {
    expect(WeatherKind.fromCode(0), WeatherKind.clear);
    expect(WeatherKind.fromCode(2), WeatherKind.partlyCloudy);
    expect(WeatherKind.fromCode(3), WeatherKind.cloudy);
    expect(WeatherKind.fromCode(45), WeatherKind.fog);
    expect(WeatherKind.fromCode(53), WeatherKind.drizzle);
    expect(WeatherKind.fromCode(81), WeatherKind.rain);
    expect(WeatherKind.fromCode(86), WeatherKind.snow);
    expect(WeatherKind.fromCode(99), WeatherKind.storm);
    expect(WeatherKind.fromCode(42), isNull);
    expect(weatherStrength(61), 1);
    expect(weatherStrength(65), 3);
    expect(weatherStrength(3), 0);
    expect(WeatherKind.storm.wet, isTrue);
    expect(WeatherKind.snow.wet, isFalse);
    expect(WeatherKind.partlyCloudy.grey, isFalse);
  });

  group('kept on the phone (in its settings, not in backups)', () {
    final report = WeatherReport(
      placeId: '1',
      code: 99,
      temperature: 21.5,
      fetchedAt: DateTime(2026, 10, 19, 9),
    );
    final settings = InternetSettings(
      weather: true,
      places: const [
        place,
        WeatherPlace(
            id: '2',
            name: 'Beograd',
            region: 'Central Serbia',
            country: 'Serbia',
            latitude: 44.8,
            longitude: 20.47),
      ],
      placeId: '2',
      report: report,
    );

    test('written as read', () {
      final back =
          Preferences.fromJson(Preferences(internet: settings).toJson())
              .internet;
      expect(back.weather, isTrue);
      expect(back.places, settings.places);
      expect(back.placeId, '2');
      expect(
          (back.report!.code, back.report!.temperature, back.report!.fetchedAt),
          (99, 21.5, report.fetchedAt));
    });

    test('nothing written while unused; older settings have it off', () {
      expect(const Preferences().toJson().containsKey('internet'), isFalse);
      expect(Preferences.fromJson(const {}).internet.weather, isFalse);
    });

    test('the sky\'s weather: on, for the place, and no older than 3 h', () {
      final at = report.fetchedAt;
      final first = settings.copyWith(placeId: () => '1');
      expect(first.reportAt(at)?.code, 99);
      expect(first.reportAt(at.add(const Duration(hours: 3))), isNotNull);
      expect(
          first.reportAt(at.add(const Duration(hours: 3, minutes: 1))), isNull);
      expect(settings.reportAt(at), isNull, reason: 'another place picked');
      expect(first.copyWith(weather: false).reportAt(at), isNull);
    });

    test('a place added once, picked; removed, the first is picked', () {
      final once = settings.withPlace(place);
      expect(once.places, hasLength(2));
      expect(once.placeId, '1');
      final gone = once.withoutPlace('1');
      expect(gone.places.map((p) => p.id), ['2']);
      expect(gone.placeId, '2');
      expect(gone.report, isNull, reason: 'its weather went with it');
      expect(settings.withoutPlace('1').placeId, '2', reason: 'kept');
      expect(settings.withoutPlace('2').report, isNotNull,
          reason: 'the weather of another place stays');
    });
  });

  group("the rain radar's answer (Round 106)", () {
    Map<String, dynamic> realtime(Object? code) => {
          'data': {
            'time': '2026-10-27T12:00:00Z',
            'values': {'weatherCode': code, 'temperature': 9.1},
          },
        };

    test('rain and snow as Open-Meteo codes; dry as null', () {
      expect(parseRadar(realtime(4200)), 61);
      expect(parseRadar(realtime(4001)), 63);
      expect(parseRadar(realtime(5000)), 73);
      expect(parseRadar(realtime(1001)), isNull, reason: 'cloudy');
      expect(parseRadar(realtime(1000)), isNull, reason: 'clear');
    });

    test('every wet code is wet in the app, every dry one none', () {
      const wet = {
        4000: WeatherKind.drizzle,
        6000: WeatherKind.drizzle,
        4200: WeatherKind.rain,
        4001: WeatherKind.rain,
        4201: WeatherKind.rain,
        6200: WeatherKind.rain,
        6001: WeatherKind.rain,
        6201: WeatherKind.rain,
        5100: WeatherKind.snow,
        5001: WeatherKind.snow,
        5000: WeatherKind.snow,
        5101: WeatherKind.snow,
        7000: WeatherKind.snow,
        7101: WeatherKind.snow,
        7102: WeatherKind.snow,
        8000: WeatherKind.storm,
      };
      for (final MapEntry(:key, :value) in wet.entries) {
        expect(WeatherKind.fromCode(wmoFromTomorrow(key)!), value,
            reason: '$key');
      }
      for (final dry in [0, 1000, 1100, 1101, 1102, 1001, 2000, 2100]) {
        expect(wmoFromTomorrow(dry), isNull, reason: '$dry');
      }
    });

    test('heavier is heavier', () {
      expect(weatherStrength(wmoFromTomorrow(4200)!), 1);
      expect(weatherStrength(wmoFromTomorrow(4001)!), 2);
      expect(weatherStrength(wmoFromTomorrow(4201)!), 3);
      expect(weatherStrength(wmoFromTomorrow(5100)!), 1);
      expect(weatherStrength(wmoFromTomorrow(5101)!), 3);
    });

    test('nonsense: a failure, not a guess', () {
      for (final bad in [
        <String, dynamic>{},
        {'data': 'x'},
        {'data': <String, dynamic>{}},
        realtime('rain'),
      ]) {
        expect(() => parseRadar(bad), throwsA(isA<WeatherFailure>()));
      }
    });
  });

  test('the key and the radar mark kept in the settings; old ones without', () {
    final settings = InternetSettings(
      weather: true,
      radarKey: 'k123',
      report: WeatherReport(
        placeId: 'p',
        code: 63,
        temperature: 4,
        fetchedAt: DateTime(2026, 10, 27, 12),
        radar: true,
      ),
    );
    final back =
        InternetSettings.fromJson(jsonDecode(jsonEncode(settings.toJson())));
    expect(back.radarKey, 'k123');
    expect(back.report!.radar, isTrue);
    expect(back.report!.code, 63);
    final old = InternetSettings.fromJson({
      'report': {
        'placeId': 'p',
        'code': 3,
        'temperature': 4,
        'fetchedAt': '2026-10-27T10:00:00Z',
      },
    });
    expect(old.radarKey, isNull);
    expect(old.report!.radar, isFalse);
    expect(const InternetSettings(radarKey: 'k').isEmpty, isFalse);
  });
}
