/// A place for the weather (Round 70), as Open-Meteo's place search found
/// it: its name, region and country, and where it is.
class WeatherPlace {
  /// Open-Meteo's id for it (a GeoNames id), as text.
  final String id;
  final String name;

  /// Its region (state, province...); empty if none was given.
  final String region;
  final String country;
  final double latitude;
  final double longitude;

  const WeatherPlace({
    required this.id,
    required this.name,
    this.region = '',
    this.country = '',
    required this.latitude,
    required this.longitude,
  });

  /// "Region, Country", what tells two places of one name apart.
  String get where => [region, country].where((s) => s.isNotEmpty).join(', ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (region.isNotEmpty) 'region': region,
        if (country.isNotEmpty) 'country': country,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory WeatherPlace.fromJson(Map<String, dynamic> json) => WeatherPlace(
        id: json['id'] as String,
        name: json['name'] as String,
        region: json['region'] as String? ?? '',
        country: json['country'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is WeatherPlace &&
      other.id == id &&
      other.name == name &&
      other.region == region &&
      other.country == country &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode =>
      Object.hash(id, name, region, country, latitude, longitude);
}

/// The weather at a place, as last fetched (Round 70).
class WeatherReport {
  /// The place's [WeatherPlace.id].
  final String placeId;

  /// Open-Meteo's WMO weather code (core/weather.dart reads it).
  final int code;

  /// In °C.
  final double temperature;

  /// Round 79: the wind, km/h at 10 m (null: a report from before).
  final double? wind;
  final DateTime fetchedAt;

  const WeatherReport({
    required this.placeId,
    required this.code,
    required this.temperature,
    this.wind,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'code': code,
        'temperature': temperature,
        if (wind != null) 'wind': wind,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      };

  factory WeatherReport.fromJson(Map<String, dynamic> json) => WeatherReport(
        placeId: json['placeId'] as String,
        code: (json['code'] as num).toInt(),
        temperature: (json['temperature'] as num).toDouble(),
        wind: (json['wind'] as num?)?.toDouble(),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String).toLocal(),
      );
}

/// What the app may use the internet for (Round 70: the Internet Access
/// page). Nothing unless turned on here; this phone only.
class InternetSettings {
  /// The weather (Open-Meteo) for Pip's sky.
  final bool weather;

  /// The places added, in the order added; the weather is fetched for
  /// [placeId]'s.
  final List<WeatherPlace> places;
  final String? placeId;

  /// The last weather fetched, shown till the next (and after a restart).
  final WeatherReport? report;

  const InternetSettings({
    this.weather = false,
    this.places = const [],
    this.placeId,
    this.report,
  });

  /// The place the weather is for: [placeId]'s, else the first.
  WeatherPlace? get place =>
      places.where((p) => p.id == placeId).firstOrNull ?? places.firstOrNull;

  /// The weather for Pip's sky: the last report, while the weather is on
  /// and it's for [place] and no older than [maxAge] at [now].
  static const maxAge = Duration(hours: 3);
  WeatherReport? reportAt(DateTime now) {
    final r = report;
    if (!weather || r == null || r.placeId != place?.id) return null;
    final age = now.difference(r.fetchedAt);
    return age.isNegative || age > maxAge ? null : r;
  }

  InternetSettings copyWith({
    bool? weather,
    List<WeatherPlace>? places,
    String? Function()? placeId,
    WeatherReport? Function()? report,
  }) =>
      InternetSettings(
        weather: weather ?? this.weather,
        places: places ?? this.places,
        placeId: placeId == null ? this.placeId : placeId(),
        report: report == null ? this.report : report(),
      );

  /// [p] added (once: a place already there is only picked) and picked.
  InternetSettings withPlace(WeatherPlace p) => copyWith(
        places: places.any((q) => q.id == p.id) ? places : [...places, p],
        placeId: () => p.id,
      );

  /// The place [id] removed; the first left picked if it was the one.
  InternetSettings withoutPlace(String id) {
    final left = [
      for (final p in places)
        if (p.id != id) p
    ];
    final picked = place?.id == id ? left.firstOrNull?.id : place?.id;
    return copyWith(
      places: left,
      placeId: () => picked,
      report: () => report?.placeId == id ? null : report,
    );
  }

  bool get isEmpty => !weather && places.isEmpty && report == null;

  Map<String, dynamic> toJson() => {
        if (weather) 'weather': true,
        if (places.isNotEmpty) 'places': [for (final p in places) p.toJson()],
        if (placeId != null) 'placeId': placeId,
        if (report != null) 'report': report!.toJson(),
      };

  factory InternetSettings.fromJson(Map<String, dynamic> json) =>
      InternetSettings(
        weather: json['weather'] as bool? ?? false,
        places: [
          for (final p in json['places'] as List<dynamic>? ?? const [])
            WeatherPlace.fromJson(p as Map<String, dynamic>),
        ],
        placeId: json['placeId'] as String?,
        report: json['report'] == null
            ? null
            : WeatherReport.fromJson(json['report'] as Map<String, dynamic>),
      );
}
