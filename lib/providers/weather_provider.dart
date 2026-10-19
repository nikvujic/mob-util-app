import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/weather_api.dart';
import 'package:the_app/models/internet.dart';
import 'package:the_app/providers/preferences_provider.dart';

export 'package:the_app/data/weather_api.dart' show WeatherFailure;

/// The weather service (Round 70); a fake in tests.
final weatherApiProvider = Provider<WeatherApi>((ref) => OpenMeteoApi());

/// The weather's fetching (Round 70): whether it's under way, and why
/// the last try failed (null: it didn't).
typedef WeatherFetch = ({bool busy, String? failed});

/// Fetches the weather for Internet Access's place while it's on: when
/// it's turned on or the place changes, then every [every] (a report
/// older than [staleAfter] is fetched again), and on [refresh]. Nothing
/// at all while it's off.
class WeatherNotifier extends StateNotifier<WeatherFetch> {
  WeatherNotifier(this._ref) : super((busy: false, failed: null)) {
    _ref.listen(
      preferencesProvider.select((p) => (p.internet.weather, p.internet.place)),
      (_, __) => _follow(),
    );
    _follow();
  }

  final Ref _ref;
  Timer? _timer;

  static const every = Duration(minutes: 15);
  static const staleAfter = Duration(hours: 1);

  InternetSettings get _settings => _ref.read(preferencesProvider).internet;

  void _follow() {
    final on = _settings.weather && _settings.place != null;
    if (!on) {
      _timer?.cancel();
      _timer = null;
      if (mounted) state = (busy: false, failed: null);
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
    if (!force &&
        last != null &&
        last.placeId == place.id &&
        now.difference(last.fetchedAt) < staleAfter &&
        !now.isBefore(last.fetchedAt)) {
      return;
    }
    state = (busy: true, failed: null);
    try {
      final report = await _ref.read(weatherApiProvider).now(place, now);
      if (!mounted) return;
      // Still on, and for the same place.
      final current = _settings;
      if (current.weather && current.place?.id == place.id) {
        _ref
            .read(preferencesProvider.notifier)
            .setInternet(current.copyWith(report: () => report));
      }
      state = (busy: false, failed: null);
    } on WeatherFailure catch (e) {
      if (mounted) state = (busy: false, failed: e.message);
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
