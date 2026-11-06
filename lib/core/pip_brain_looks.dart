part of 'pip_brain.dart';

/// Round 138 (out of `pip_brain.dart`): how he looks and what his screen
/// says: his hats (Round 57, 61), his medicine reminder (Round 53), a
/// meal after a recipe (Round 53), and something on his screen now and
/// then.
class _PipLooksState {
  /// Someone's birthday today, or his own (the room says): the party hat.
  bool birthday = false;

  /// Today's hat otherwise (Round 61, the room says): a day of the year's
  /// (a Santa hat at New Year...) or a random day's; null: none.
  PipHat? dayHat;

  /// A hat tried on (Pip Home's Hats; null: none, even on a birthday),
  /// while [_tryingOn].
  PipHat? triedOn;
  bool tryingOn = false;

  /// A medicine due and not marked (the room says, from the red dot).
  bool medicineDue = false;

  /// The reminder played from Pip Home's list, not for real: once.
  bool previewing = false;

  /// The recipe reading he last ate for (the room: once for each).
  DateTime? ateFor;

  // His screen showing something.
  PipScreen screenShow = PipScreen.happy;
  double showFor = 3;
}

extension PipBrainLooks on PipBrain {
  bool get birthday => _lk.birthday;
  set birthday(bool value) => _lk.birthday = value;

  PipHat? get dayHat => _lk.dayHat;
  set dayHat(PipHat? value) => _lk.dayHat = value;

  bool get medicineDue => _lk.medicineDue;
  set medicineDue(bool value) => _lk.medicineDue = value;

  DateTime? get ateFor => _lk.ateFor;
  set ateFor(DateTime? value) => _lk.ateFor = value;

  // Round 57: his hats.

  /// Tries [hat] on (none: null), instead of what he'd wear.
  void tryOn(PipHat? hat) {
    _lk.tryingOn = true;
    _lk.triedOn = hat;
  }

  /// Back to what he wears himself (a party hat on a birthday).
  void stopTryingOn() {
    _lk.tryingOn = false;
    _lk.triedOn = null;
  }

  /// The hat he has: tried on, or the party hat on a birthday; none in
  /// his egg or while he hatches.
  PipHat? get hat {
    if (activity == PipActivity.egg || activity == PipActivity.hatching) {
      return null;
    }
    if (_lk.tryingOn) return _lk.triedOn;
    // Round 67: no hat on the bus.
    if (activity == PipActivity.riding) return null;
    if (birthday) return PipHat.party;
    // Round 128: working his quest in the wet, his rain hat.
    if (activity == PipActivity.questing && wetOut) return PipHat.rainHat;
    // Round 67: a ski beanie all his ski days.
    return snowing ? PipHat.skiBeanie : dayHat;
  }

  /// Asleep (settled, legs tucked): his hat on the ground beside him.
  bool get hatBeside =>
      hat != null &&
      frame == PipFrame.tuck &&
      (activity == PipActivity.asleep ||
          activity == PipActivity.fallingAsleep ||
          activity == PipActivity.stirring ||
          activity == PipActivity.wakingUp);

  // Round 53: his medicine reminder.

  /// Round 55: due, the first thing he does whenever he's up and about
  /// (before going to charge, or a battery), and he keeps at it.
  void _stepMedicine() {
    if (!medicineDue) return;
    if (activity != PipActivity.standing && activity != PipActivity.walking) {
      return;
    }
    _lk.previewing = false;
    _startShowing(PipScreen.pill);
  }

  // Round 53: eating, after a recipe was looked at a while.

  /// Eating, if he's up and about: true if he started.
  bool eat() {
    if (activity != PipActivity.standing && activity != PipActivity.walking) {
      return false;
    }
    _start(PipActivity.eating);
    return true;
  }

  /// The plate: (its left, height above the ground, bites taken 0–3,
  /// size 0–1 popping in and away); null when he isn't eating. Held up
  /// to his face for each bite.
  (double, double, int, double)? get plate {
    if (activity != PipActivity.eating) return null;
    final taken =
        PipBrain.bites.where((b) => _t >= b + PipBrain.biteTime / 2).length;
    final double size = _t < PipBrain.plateIn
        ? _t / PipBrain.plateIn
        : _t > PipBrain.eatTime - PipBrain.plateIn
            ? ((PipBrain.eatTime - _t) / PipBrain.plateIn).clamp(0.0, 1.0)
            : 1;
    var up = 0.0;
    for (final b in PipBrain.bites) {
      if (_t >= b && _t < b + PipBrain.biteTime) {
        up = 3 * math.sin(math.pi * (_t - b) / PipBrain.biteTime);
      }
    }
    final left = x + (PipBrain.width - PipBrain.plateWidth) / 2;
    return (left, PipBrain.plateRest + up, taken, size);
  }

  /// Crumbs falling from the plate after each bite: (x, height).
  List<(double, double)> get crumbs {
    if (activity != PipActivity.eating) return const [];
    final out = <(double, double)>[];
    for (final (i, b) in PipBrain.bites.indexed) {
      final since = _t - b - PipBrain.biteTime / 2;
      if (since < 0 || since >= 0.6) continue;
      final fall = 0.5 * 40 * since * since;
      for (final dx in const [-2.0, 3.0]) {
        final h = PipBrain.plateRest + 2 - fall;
        if (h > 0) out.add((x + PipBrain.width / 2 + dx + i, h));
      }
    }
    return out;
  }

  /// A notification came (his room heard): his screen shows one, with a
  /// hop, if he's up and about; else nothing (asleep, busy, charging).
  bool notify() {
    if (activity != PipActivity.standing && activity != PipActivity.walking) {
      return false;
    }
    _startShowing(PipBrain
        ._notifyScreens[random.nextInt(PipBrain._notifyScreens.length)]);
    return true;
  }

  void _startShowing(PipScreen screen) {
    _lk.screenShow = screen;
    _lk.showFor = screen.hops ? 4.0 : 3.2;
    _start(PipActivity.showing);
  }

  /// What his screen shows and how far into it: while [PipActivity.
  /// showing], and after a bug fight (proud) or holding a flower (happy).
  (PipScreen, double)? get screenShow => switch (activity) {
        PipActivity.showing => (_lk.screenShow, _t),
        PipActivity.dancing => (PipScreen.music, _t),
        PipActivity.eating when _t >= PipBrain.eatenAt => (
            PipScreen.happy,
            _t - PipBrain.eatenAt
          ),
        PipActivity.bugHunt when _bugsAllGone => (PipScreen.happy, _bugPhaseT),
        // Round 127: at his quest's work, his medicine on his screen.
        PipActivity.questing when medicineDue => (
            PipScreen.pill,
            _questClockNow
          ),
        PipActivity.flower when _flowerStage == 3 => (PipScreen.happy, _t),
        _ => null,
      };

  /// Shows [screen] now (for tests and pictures).
  @visibleForTesting
  void debugShow(PipScreen screen) => _startShowing(screen);

  /// What his screen shows now (while [PipActivity.showing]).
  PipScreen get _shownNow => _lk.screenShow;

  /// Pip Home's Medicine: the pill shown, as if one were due.
  void _previewPill() {
    _startShowing(PipScreen.pill);
    _lk.previewing = !medicineDue;
  }

  /// Something on his screen, each step: a hop's landing; his medicine
  /// marked, or its time up, it's done.
  void _stepShowing(double dt) {
    // Round 98: down from his hop.
    if (_lk.screenShow.hops) _buzzOn(PipBrain.showHop, dt, PipBuzz.light);
    if (_lk.screenShow == PipScreen.pill) _buzzOn(0.9, dt, PipBuzz.light);
    // Round 55: his medicine reminder, marked, stops at once; still
    // due, it starts over ([_stepMedicine]), a hop each time.
    if ((_lk.screenShow == PipScreen.pill && !medicineDue && !_lk.previewing) ||
        _t >= _lk.showFor) {
      _stand();
    }
  }
}
