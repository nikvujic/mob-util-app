import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/power.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/medicine_alerts_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/notification_log_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/recipe_read_provider.dart';

/// Pip, the pet (Round 34): an egg until hatched, then his birthday and
/// name; his energy and batteries (Round 37). Saved to `pip.json`.
class PipLifeNotifier extends StateNotifier<PipLife> {
  final DateTime Function() _clock;

  PipLifeNotifier(
    AppStorage storage, {
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        super(storage.initialPip) {
    state = _started(state);
    addListener(storage.savePip, fireImmediately: false);
  }

  /// A Pip from before Round 37 (or such a backup): full from now on,
  /// his first battery on its way.
  PipLife _started(PipLife pip) {
    if (!pip.hatched || pip.energyAt != null) return pip;
    final now = _clock();
    return pip.copyWith(
      energyAt: () => now,
      nextBatteryAt: () => pip.nextBatteryAt ?? PipEnergy.nextBattery(now),
    );
  }

  /// He's out, at [now]: that's his birthday. Once only. Full of energy,
  /// his first battery on its way.
  void hatch(DateTime now) {
    if (state.hatched) return;
    state = state.copyWith(
      born: now,
      energy: PipLife.fullEnergy,
      energyAt: () => now,
      nextBatteryAt: () => PipEnergy.nextBattery(now),
    );
  }

  /// A new name: trimmed, at most [maxName] letters (Round 35: 6, so
  /// it never overflows); blank keeps his.
  static const maxName = 6;
  void rename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      name: trimmed.length > maxName ? trimmed.substring(0, maxName) : trimmed,
    );
  }

  /// The phone is plugged in (Round 44): he can't lose power meanwhile.
  bool _charging = false;
  bool get charging => _charging;

  /// Whether the phone is plugged in, as known at [now]: his energy is
  /// taken as it is then, and from then on kept (charging) or used
  /// (not).
  void setCharging(bool charging, DateTime now) {
    if (charging == _charging) return;
    if (state.hatched) {
      state = state.copyWith(energy: levelAt(now), energyAt: () => now);
    }
    _charging = charging;
  }

  /// Plugged in when last seen (after a restart): charging since then,
  /// his energy as it was.
  void resumeCharging(bool charging) => _charging = charging;

  /// His battery icon's segments at [now]: plugged in, it doesn't drop
  /// (Round 45: the drop shows once he's unplugged).
  int segmentsAt(DateTime now) => _charging
      ? math.max(
          PipEnergy.segments(levelAt(now)), PipEnergy.segments(state.energy))
      : PipEnergy.segments(levelAt(now));

  /// His energy at [now].
  double levelAt(DateTime now) =>
      (_charging ? PipEnergy.chargingLevelAt : PipEnergy.levelAt)(
        state.energy,
        state.energyAt ?? now,
        now,
      );

  /// The batteries due by [now] (Round 45: every few hours on the clock,
  /// piling up while away, up to 3 held).
  void collect(DateTime now) {
    if (!state.hatched) return;
    final next = state.nextBatteryAt;
    if (next == null) {
      state = state.copyWith(nextBatteryAt: () => PipEnergy.nextBattery(now));
      return;
    }
    final (held, after) = PipEnergy.batteriesAt(state.batteries, next, now);
    if (after != next) {
      state = state.copyWith(batteries: held, nextBatteryAt: () => after);
    }
  }

  /// What to show of him at [now].
  PipShow showAt(DateTime now) => pipShowAt(
        now,
        level: levelAt(now),
        offSeen: state.offSeen,
        sleepSeen: state.sleepSeen,
        wakeSeen: state.wakeSeen,
      );

  /// [show] was shown at [now]: remembered, so it isn't played again.
  void shown(PipShow show, DateTime now) {
    switch (show) {
      case PipShow.powerOff || PipShow.off:
        if (!state.offSeen) {
          // Empty now: kept so, whatever the clock does.
          state = state.copyWith(
            offSeen: true,
            energy: 0,
            energyAt: () => now,
          );
        }
      case PipShow.fallAsleep:
        state = state.copyWith(sleepSeen: () => dayKey(now));
      case PipShow.wakeUp:
        state = state.copyWith(wakeSeen: () => dayKey(now));
      case PipShow.awake || PipShow.asleep:
        break;
    }
  }

  /// Why a battery can't be given at [now], or null if it can: none
  /// held, he's full, or he's asleep (off, he can have one: it turns him
  /// back on).
  PipRefusal? refusalAt(DateTime now) {
    if (!state.hatched) return PipRefusal.egg;
    if (state.batteries == 0) return PipRefusal.noBatteries;
    if (segmentsAt(now) >= 3) return PipRefusal.full;
    final show = showAt(now);
    if (show == PipShow.asleep) return PipRefusal.asleep;
    // Round 44: plugged in (at his station), not now.
    if (_charging && show != PipShow.off) return PipRefusal.charging;
    return null;
  }

  /// Gives him a battery at [now], if he can have one: a segment more
  /// (up to full), and on again if he was off. True if given.
  bool giveBattery(DateTime now) {
    if (refusalAt(now) != null) return false;
    state = state.copyWith(
      batteries: state.batteries - 1,
      energy: math.min(PipLife.fullEnergy, levelAt(now) + 1),
      energyAt: () => now,
      offSeen: false,
    );
    return true;
  }

  /// Replaces him (restoring a backup): one from before Round 37 starts
  /// full from now.
  void replace(PipLife pip) => state = _started(pip);
}

/// Why he can't have a battery now.
enum PipRefusal { egg, noBatteries, full, asleep, charging }

final pipLifeProvider = StateNotifierProvider<PipLifeNotifier, PipLife>(
  (ref) => PipLifeNotifier(
    ref.watch(appStorageProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Pip's life as his room sees it (Round 37): what to show, what was
/// shown, a battery given.
class _Link implements PipLink {
  final Ref _ref;

  _Link(this._ref);

  PipLifeNotifier get _pip => _ref.read(pipLifeProvider.notifier);
  DateTime get _now => _ref.read(clockProvider)();

  @override
  (PipShow, int) look() {
    // Plugged in or not first (Round 44): it decides his energy.
    _ref.read(pipPowerProvider.notifier).refresh();
    final now = _now;
    _pip.collect(now);
    return (_pip.showAt(now), _pip.segmentsAt(now));
  }

  @override
  void shown(PipShow show) => _pip.shown(show, _now);

  @override
  bool giveBattery() => _pip.giveBattery(_now);

  @override
  bool get plugged => _ref.read(pipPowerProvider);

  @override
  DateTime get now => _now;

  @override
  bool get medicineDue {
    final now = _now;
    return !_ref.read(preferencesProvider).medicinePausedOn(dayOf(now)) &&
        doseDue(_ref.read(medicineProvider), now);
  }

  @override
  DateTime? get recipeReadAt => _ref.read(recipeReadProvider);

  @override
  bool notifiedBetween(DateTime from, DateTime to) => _ref
      .read(notificationLogProvider)
      .scheduled
      .any((n) => n.at.isAfter(from) && !n.at.isAfter(to));
}

/// Whether the phone is plugged in (Round 44: Pip's charging station):
/// asked of Android at first and again while he's looked at (every few
/// seconds at most: so also when the app comes back), and told as it
/// changes while the app is open. Kept in his life (he can't lose power
/// meanwhile) and in this phone's preferences (for after a restart).
class PipPowerNotifier extends StateNotifier<bool> {
  final Ref _ref;
  StreamSubscription<bool>? _changes;

  PipPowerNotifier(this._ref)
      : super(_ref.read(preferencesProvider).pipPlugged) {
    _ref.read(pipLifeProvider.notifier).resumeCharging(state);
    final source = _ref.read(powerSourceProvider);
    _changes = source.changes.listen(_set);
    _ask();
  }

  /// Since it was last asked (a real clock, whatever the app's).
  final _sinceAsked = Stopwatch()..start();
  static const askEvery = Duration(seconds: 5);

  /// Asks again if it's been a while (the app may have been away).
  void refresh() {
    if (_sinceAsked.elapsed < askEvery) return;
    _ask();
  }

  Future<void> _ask() async {
    _sinceAsked.reset();
    final plugged = await _ref.read(powerSourceProvider).plugged();
    if (mounted) _set(plugged);
  }

  void _set(bool plugged) {
    final now = _ref.read(clockProvider)();
    _ref.read(pipLifeProvider.notifier).setCharging(plugged, now);
    _ref.read(preferencesProvider.notifier).setPipPlugged(plugged);
    state = plugged;
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }
}

final pipPowerProvider = StateNotifierProvider<PipPowerNotifier, bool>(
  PipPowerNotifier.new,
);

final pipLinkProvider = Provider<PipLink>((ref) => _Link(ref));
