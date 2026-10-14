import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/pip_life.dart';

/// Pip, the pet (Round 34): an egg until hatched, then his birthday and
/// name; his energy and batteries (Round 37). Saved to `pip.json`.
class PipLifeNotifier extends StateNotifier<PipLife> {
  final DateTime Function() _clock;
  final math.Random _random;

  PipLifeNotifier(
    AppStorage storage, {
    DateTime Function()? clock,
    math.Random? random,
  })  : _clock = clock ?? DateTime.now,
        _random = random ?? math.Random(),
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
      nextBatteryAt: () =>
          pip.nextBatteryAt ?? PipEnergy.nextBattery(now, _random),
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
      nextBatteryAt: () => PipEnergy.nextBattery(now, _random),
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

  /// His energy at [now].
  double levelAt(DateTime now) => PipEnergy.levelAt(
        state.energy,
        state.energyAt ?? now,
        now,
      );

  /// The battery due by [now], if any: held (up to 3), and the next one
  /// timed from now, so they can't pile up while the app is closed.
  void collect(DateTime now) {
    if (!state.hatched) return;
    final next = state.nextBatteryAt;
    if (next == null) {
      state = state.copyWith(
        nextBatteryAt: () => PipEnergy.nextBattery(now, _random),
      );
    } else if (!now.isBefore(next)) {
      state = state.copyWith(
        batteries: math.min(PipEnergy.maxBatteries, state.batteries + 1),
        nextBatteryAt: () => PipEnergy.nextBattery(now, _random),
      );
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
    final level = levelAt(now);
    if (PipEnergy.segments(level) >= 3) return PipRefusal.full;
    final show = showAt(now);
    if (show == PipShow.asleep) return PipRefusal.asleep;
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
enum PipRefusal { egg, noBatteries, full, asleep }

/// Picks battery times; tests give their own.
final pipRandomProvider = Provider<math.Random>((ref) => math.Random());

final pipLifeProvider = StateNotifierProvider<PipLifeNotifier, PipLife>(
  (ref) => PipLifeNotifier(
    ref.watch(appStorageProvider),
    clock: ref.watch(clockProvider),
    random: ref.watch(pipRandomProvider),
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
    final now = _now;
    _pip.collect(now);
    return (_pip.showAt(now), PipEnergy.segments(_pip.levelAt(now)));
  }

  @override
  void shown(PipShow show) => _pip.shown(show, _now);

  @override
  bool giveBattery() => _pip.giveBattery(_now);
}

final pipLinkProvider = Provider<PipLink>((ref) => _Link(ref));
