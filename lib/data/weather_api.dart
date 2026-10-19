import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:the_app/models/internet.dart';

/// Why the weather couldn't be had (Round 70): no connection, or an
/// answer that made no sense.
class WeatherFailure implements Exception {
  final String message;

  const WeatherFailure(this.message);

  @override
  String toString() => message;
}

/// The weather service (Round 70): Open-Meteo, free and with no key or
/// account. Only used once the weather is turned on in Internet Access.
abstract class WeatherApi {
  /// Places called [name] (a city, a town), the likeliest first; none if
  /// nothing matched. Throws [WeatherFailure].
  Future<List<WeatherPlace>> search(String name);

  /// The weather now at [place]. Throws [WeatherFailure].
  Future<WeatherReport> now(WeatherPlace place, DateTime at);
}

/// [WeatherApi] over https, with dart:io (no extra package).
class OpenMeteoApi implements WeatherApi {
  static const timeout = Duration(seconds: 12);

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final body =
          await response.transform(utf8.decoder).join().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw WeatherFailure('The weather service said ${response.statusCode}');
      }
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        throw const WeatherFailure('The weather service made no sense');
      }
      return json;
    } on WeatherFailure {
      rethrow;
    } on FormatException {
      throw const WeatherFailure('The weather service made no sense');
    } on Object {
      // SocketException, TimeoutException, HandshakeException...
      throw const WeatherFailure('No connection to the weather service');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<List<WeatherPlace>> search(String name) async {
    final json = await _get(Uri.https('geocoding-api.open-meteo.com',
        '/v1/search', {'name': name.trim(), 'count': '10', 'format': 'json'}));
    return parsePlaces(json);
  }

  @override
  Future<WeatherReport> now(WeatherPlace place, DateTime at) async {
    final json = await _get(Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${place.latitude}',
      'longitude': '${place.longitude}',
      'current': 'weather_code,temperature_2m',
    }));
    return parseReport(json, place, at);
  }
}

/// Open-Meteo's place search answer as places (none for no "results").
List<WeatherPlace> parsePlaces(Map<String, dynamic> json) {
  final results = json['results'];
  if (results is! List) return const [];
  return [
    for (final r in results.whereType<Map<String, dynamic>>())
      if (r['latitude'] is num && r['longitude'] is num && r['name'] is String)
        WeatherPlace(
          id: '${r['id'] ?? '${r['latitude']},${r['longitude']}'}',
          name: r['name'] as String,
          region: r['admin1'] as String? ?? '',
          country: r['country'] as String? ?? '',
          latitude: (r['latitude'] as num).toDouble(),
          longitude: (r['longitude'] as num).toDouble(),
        ),
  ];
}

/// Open-Meteo's current weather answer as a report for [place].
WeatherReport parseReport(
  Map<String, dynamic> json,
  WeatherPlace place,
  DateTime at,
) {
  final current = json['current'];
  if (current is! Map<String, dynamic>) {
    throw const WeatherFailure('The weather service made no sense');
  }
  final code = current['weather_code'];
  final temperature = current['temperature_2m'];
  if (code is! num || temperature is! num) {
    throw const WeatherFailure('The weather service made no sense');
  }
  return WeatherReport(
    placeId: place.id,
    code: code.toInt(),
    temperature: temperature.toDouble(),
    fetchedAt: at,
  );
}
