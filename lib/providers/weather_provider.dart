import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/weather_api.dart';
import 'package:the_app/models/internet.dart';
import 'package:the_app/providers/preferences_provider.dart';

export 'package:the_app/data/weather_api.dart' show WeatherFailure;

/// The weather service (Round 70); a fake in tests.
final weatherApiProvider = Provider<WeatherApi>((ref) => OpenMeteoApi());

/// The rain radar (Round 106), used with the user's key; a fake in tests.
final radarApiProvider = Provider<RadarApi>((ref) => TomorrowIoApi());

/// Where to get a rain radar key (shown with a copy button).
const radarSignUp = TomorrowIoApi.signUp;

/// The weather's fetching (Round 70): whether it's under way, and why
/// the last try failed (null: it didn't); Round 106: why the rain radar
/// failed, the weather then Open-Meteo's alone.
typedef WeatherFetch = ({bool busy, String? failed, String? radarFailed});

const _idle = (busy: false, failed: null, radarFailed: null);

/// Fetches the weather for Internet Access's place while it's on: when
/// it's turned on or the place changes, then every [every] (a report
/// older than [staleAfter] is fetched again), and on [refresh]. Nothing
/// at all while it's off.
class WeatherNotifier extends StateNotifier<WeatherFetch> {
  WeatherNotifier(this._ref) : super(_idle) {
    _ref.listen(
      preferencesProvider.select((p) => (p.internet.weather, p.internet.place)),
      (_, __) => _follow(),
    );
    // Round 106: a key added or changed: fetched again with it.
    _ref.listen(
      preferencesProvider.select((p) => p.internet.radarKey),
      (_, __) => scheduleMicrotask(() => refresh(force: true)),
    );
    _follow();
  }

  final Ref _ref;
  Timer? _timer;

  static const every = Duration(minutes: 15);
  static const staleAfter = Duration(hours: 1);

  /// Round 106: with the rain radar, its rain now is fetched every time
  /// ([every]): about 100 calls a day, well in its free limit.
  static const radarStaleAfter = Duration(minutes: 14);

  InternetSettings get _settings => _ref.read(preferencesProvider).internet;

  void _follow() {
    final on = _settings.weather && _settings.place != null;
    if (!on) {
      _timer?.cancel();
      _timer = null;
      if (mounted) state = _idle;
      return;
    }
    _timer ??= Timer.periodic(every, (_) => refresh());
    // Scheduled, not at once: never in the middle of a build.
    scheduleMicrotask(refresh);
  }

  /// Fetches the weather if it's on and the last report is stale (or for
  /// another place); [force]: whatever its age.
  Future<void> refresh({bool force = false}) async {
    if (!mounted || state.busy) return;
    final settings = _settings;
    final place = settings.place;
    if (!settings.weather || place == null) return;
    final now = _ref.read(clockProvider)();
    final last = settings.report;
    final key = settings.radarKey;
    if (!force &&
        last != null &&
        last.placeId == place.id &&
        now.difference(last.fetchedAt) <
            (key == null ? staleAfter : radarStaleAfter) &&
        !now.isBefore(last.fetchedAt)) {
      return;
    }
    state = (busy: true, failed: null, radarFailed: null);
    try {
      var report = await _ref.read(weatherApiProvider).now(place, now);
      // Round 106: the rain radar's rain or snow now wins; dry, Open-
      // Meteo's sky stands. Failing, the weather is Open-Meteo's alone.
      String? radarFailed;
      if (key != null) {
        try {
          report = report.withRadar(
              await _ref.read(radarApiProvider).precipitation(place, key));
        } on WeatherFailure catch (e) {
          radarFailed = e.message;
        }
      }
      if (!mounted) return;
      // Still on, and for the same place.
      final current = _settings;
      if (current.weather && current.place?.id == place.id) {
        _ref
            .read(preferencesProvider.notifier)
            .setInternet(current.copyWith(report: () => report));
      }
      state = (busy: false, failed: null, radarFailed: radarFailed);
    } on WeatherFailure catch (e) {
      if (mounted) state = (busy: false, failed: e.message, radarFailed: null);
    }
  }

  /// Round 106: tries [key] on the rain radar once (at the picked place,
  /// or anywhere if there's none yet): null if it works, else why not.
  Future<String?> testRadarKey(String key) async {
    final place = _settings.place ??
        const WeatherPlace(id: 'test', name: 'Test', latitude: 0, longitude: 0);
    try {
      await _ref.read(radarApiProvider).precipitation(place, key);
      return null;
    } on WeatherFailure catch (e) {
      return e.message;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final weatherProvider = StateNotifierProvider<WeatherNotifier, WeatherFetch>(
  (ref) => WeatherNotifier(ref),
);

/// The weather for Pip's sky now (Round 70): Open-Meteo's code, while
/// it's on and the last report is fresh enough; null for a plain sky.
final skyWeatherProvider = Provider<int?>((ref) {
  final internet = ref.watch(preferencesProvider.select((p) => p.internet));
  return internet.reportAt(ref.watch(clockProvider)())?.code;
});

/// The wind for Pip's trees now (Round 79), km/h; null: not known.
final skyWindProvider = Provider<double?>((ref) {
  final internet = ref.watch(preferencesProvider.select((p) => p.internet));
  return internet.reportAt(ref.watch(clockProvider)())?.wind;
});
