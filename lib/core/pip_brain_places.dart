part of 'pip_brain.dart';

/// Round 138 (out of `pip_brain.dart`): his places: his quest's work
/// (Round 127), his finished house (Round 128), and getting between them
/// and his field without a cut while he's watched (Round 133–136).
class _PipPlacesState {
  /// His quest's work, as his life last said (the room asks every
  /// second), and the seconds since.
  PipQuestNow? questNow;
  double questT = 0;

  /// How far the house area's moved left to keep him in view (a room
  /// narrower than it, e.g. the menu's).
  double questCamera = 0;

  /// What his work looked like when he ran out at it: he lies there
  /// (falling over, off, back on), then carries on from there.
  QuestView? downView;

  /// Walking past his room's edge (off it, or in from it): not held in
  /// it meanwhile.
  bool pastEdge = false;

  /// Seen setting off to his work (back on, a battery given; his field's
  /// time over), where he started walking off his field from, and for
  /// how long; null: simply at it.
  double? joinFrom;
  double joinT = 0;

  /// Round 141: seen, his work over while he's at one of its places (the
  /// mine, the house area...): how it looked as it ended, how long he's
  /// been walking off it since, and whether he goes into his house next
  /// (else onto his field); null: not leaving.
  ({QuestView from, double t, bool toHome})? leaving;

  /// Round 141: seen joining his work under way (off his field, or back
  /// on where he fell): where he's got to walking to where it's at now
  /// (his middle, as [QuestView.pipCentre] measures), for how long;
  /// null: simply at it.
  ({double at, double t})? arriving;

  /// In his finished house (his room says, from his life: not his
  /// field's times, not out, on his trip or at work): he idles on its
  /// floor, sleeps there, his station comes up there.
  bool atHome = false;

  /// Going into (true) or out of (false) his house, seen: walking to his
  /// door, or off his field's right edge, first.
  bool? homeTo;

  /// Where he's going in his house to look (a window, the fire), and
  /// which way he faces there; null: just a walk.
  (double, bool)? visit;
}

extension PipBrainPlaces on PipBrain {
  /// In his finished house ([_PipPlacesState.atHome]).
  bool get atHome => _pl.atHome;
  set atHome(bool value) => _pl.atHome = value;

  /// How far the house area's moved left to keep him in view.
  double get questCamera => _pl.questCamera;
  set questCamera(double value) => _pl.questCamera = value;

  // Round 127: his quests.

  /// What his quest's work looks like now (the room draws it); null when
  /// he isn't at it.
  QuestView? get questView {
    // Round 134: run out at his work, he lies there (and gets up there).
    if (_pl.downView case final view?
        when PipBrain._downActs.contains(activity)) {
      return view;
    }
    final now = _pl.questNow;
    if (activity != PipActivity.questing || now == null) return null;
    // Round 141: his work over, walking off where he was.
    if (_pl.leaving case final leaving?) return _leaveView(leaving);
    // Round 133: seen going to his work, first off his field's right
    // edge.
    if (_pl.joinFrom case final from?) {
      return QuestView(
        place: QuestScenePlace.field,
        house: PipHouse.of(now.at),
        offset: from + PipBrain.width / 2 + QuestView.walkSpeed * _pl.joinT,
        pose: QuestPose.walking,
        t: _pl.joinT,
      );
    }
    final view = _scriptView(now);
    if (_pl.arriving case final arriving?) {
      return _arriveView(view, arriving.at, arriving.t);
    }
    return view;
  }

  /// Round 141: walking to [view] (where his work's at now) from [at]
  /// (his middle), [t] seconds since he set off: up onto what he works on
  /// as he gets there.
  QuestView _arriveView(QuestView view, double at, double t) {
    final end = view.pipCentre(roomWidth);
    final left = (end - at).abs();
    const climb = 6.0;
    return QuestView(
      place: view.place,
      house: view.house,
      offset: at,
      lift: left >= climb ? 0 : view.lift * (1 - left / climb),
      facingRight: end > at,
      pose: QuestPose.walking,
      fall: view.fall,
      dug: view.dug,
      rock: view.rock,
      t: t,
    );
  }

  /// His work as his own clock has it: Round 141: past the end of the
  /// step his life last said (it says so once a second), on into the
  /// next, not held at its end and then jumped on.
  QuestView _scriptView(PipQuestNow now) {
    var at = now.at;
    var seconds = now.seconds + _pl.questT;
    for (var i = 0; i < 3 && !at.done; i++) {
      final length = at.current.minutes * 60.0;
      if (seconds < length) break;
      at = at.script.at(at.script.startOf(at.step) + at.current.minutes);
      seconds -= length;
    }
    return QuestView.of(at, seconds, width: roomWidth);
  }

  /// Where his work's at now ([QuestView.of]), not as he walks to it.
  QuestView? get _workView {
    final now = _pl.questNow;
    return now == null ? null : _scriptView(now);
  }

  /// Round 141: walking in to his work: from the place's edge (its left;
  /// the house area's right, as the way from his field goes), or [from].
  void _arriveFrom(double? from) {
    final view = _workView;
    if (view == null || view.place == QuestScenePlace.field) return;
    final at =
        from ?? (view.place == QuestScenePlace.house ? QuestView.edge : -12.0);
    if ((view.pipCentre(roomWidth) - at).abs() < 0.5) return;
    _pl.arriving = (at: at, t: 0);
  }

  // Round 134: no cuts between his places while he's watched.

  /// Down where he ran out at his work (his room keeps his station away:
  /// he's not on his field).
  bool get downAtWork =>
      _pl.downView != null && PipBrain._downActs.contains(activity);

  /// [view] held still: no swing, nothing flying.
  static QuestView? _still(QuestView? view) => view == null
      ? null
      : QuestView(
          place: view.place,
          house: view.house,
          anchor: view.anchor,
          offset: view.offset,
          lift: view.lift,
          facingRight: view.facingRight,
          pose: QuestPose.standing,
          scroll: view.scroll,
          fall: view.fall,
          dug: view.dug,
          rock: view.rock,
          t: view.t,
        );

  /// His work over: off it (onto his field, or in at his house's door).
  void _leftWork({required bool animate, required bool toHome}) {
    _pl.questNow = null;
    _pl.joinFrom = null;
    _pl.arriving = null;
    _pl.leaving = null;
    // Round 134: seen, his work over, he walks back onto his field
    // (from its right edge, as he went); Round 136: or, his house
    // next ([toHome]), in at its door (not onto his field, then
    // round and off it again).
    if (animate && toHome) {
      _switchHome(true);
      _inAtDoor();
    } else if (animate) {
      _walkIn();
    } else {
      x = x.clamp(_minX, _maxX).toDouble();
      _stand();
    }
  }

  /// Round 141: walking off where his work ended: off a place's left
  /// edge (the way home); in the house area, down off what he stood on
  /// and off its right edge, or to the foot of its stairs (his house
  /// next). Null once he's off it.
  QuestView? _leaveView(({QuestView from, double t, bool toHome}) leaving) {
    final from = leaving.from;
    final t = leaving.t;
    final start = from.pipCentre(roomWidth);
    final house = from.place == QuestScenePlace.house;
    final end = from.place == QuestScenePlace.field
        ? (from.facingRight ? roomWidth + 12.0 : -12.0)
        : !house
            ? -12.0
            : leaving.toHome
                ? QuestView.home
                : QuestView.edge;
    final way = (end - start).sign;
    // A moment to get down off the floor or the scaffold first.
    const down = 0.5;
    final walked = math.max(0.0, t - down) * QuestView.walkSpeed;
    if (walked >= (end - start).abs()) return null;
    return QuestView(
      place: from.place,
      house: from.house,
      offset: start + way * walked,
      lift: from.lift * (1 - (t / down).clamp(0.0, 1.0)),
      facingRight: way > 0,
      pose: t < down ? QuestPose.standing : QuestPose.walking,
      scroll: from.scroll,
      fall: from.fall,
      dug: from.dug,
      rock: from.rock,
      t: t,
    );
  }

  /// Back on where he ran out at his work: at it again.
  void _backToWork() {
    final down = _pl.downView;
    _pl.downView = null;
    _start(PipActivity.questing);
    _pl.joinFrom = null;
    _pl.arriving = null;
    // Round 141: run out on his field on his way (or off to it): on his
    // way again, off its edge, then in to his work.
    if (down?.place == QuestScenePlace.field && _pl.leaving == null) {
      _pl.joinFrom = x;
      _pl.joinT = 0;
    } else if (down != null &&
        _pl.leaving == null &&
        down.place == _workView?.place) {
      // Where he fell, to where his work's got to.
      _arriveFrom(down.pipCentre(roomWidth));
    }
    _placeQuest();
  }

  /// Round 141: on his field where he is (walking in if he's past its
  /// edge), his work over.
  void _onFieldAgain() {
    final inside = x.clamp(_minX, _maxX).toDouble();
    _stand();
    if ((inside - x).abs() < 0.5) return;
    _pl.pastEdge = true;
    _target = inside;
    facingRight = inside > x;
    activity = PipActivity.walking;
  }

  /// In from his field's right edge, to a little left of its middle.
  void _walkIn() {
    _stand();
    x = roomWidth + 2.0;
    _pl.pastEdge = true;
    facingRight = false;
    _target =
        (roomWidth * 0.6 - PipBrain.width / 2).clamp(_minX, _maxX).toDouble();
    activity = PipActivity.walking;
  }

  /// In at his house's door, walking in to somewhere on its floor.
  void _inAtDoor() {
    x = PipBrain.homeRight - PipBrain.width;
    facingRight = false;
    _target = PipBrain.homeLeft +
        random.nextDouble() *
            (PipBrain.homeRight - PipBrain.width - PipBrain.homeLeft - 12);
    activity = PipActivity.walking;
    _t = 0;
  }

  /// Round 134: his room opened again: a walk between his places that
  /// was under way when it was left is done by now.
  void freshScenes() {
    _pl.joinFrom = null;
    _pl.arriving = null;
    // Round 141: a walk off his work's place done by now.
    if (_pl.leaving case final leaving?) {
      _leftWork(animate: false, toHome: leaving.toHome);
      if (leaving.toHome) _switchHome(true);
    }
    if (_pl.homeTo case final going?) {
      _pl.homeTo = null;
      _switchHome(going);
    }
    if (_pl.pastEdge) {
      _pl.pastEdge = false;
      x = x.clamp(_minX, _maxX).toDouble();
      if (activity == PipActivity.walking) _stand();
    }
  }

  /// At his quest's work, or not, as his life says ([now]; his room
  /// checks every second): he's simply there, at the step and the moment
  /// it's at. Round 133: [animate] (seen happening, e.g. back on after a
  /// battery): he walks off his field to it first.
  void quest(PipQuestNow? now,
      {bool animate = false, bool down = false, bool toHome = false}) {
    if (now == null) {
      if (activity == PipActivity.questing) {
        // Round 134: run out at it ([down]): he falls there, as he is.
        if (down) {
          _pl.downView = _still(questView);
          return;
        }
        // Round 141: seen, off where he is first (the mine, the house
        // area...), not cut away from it.
        if (_pl.leaving case final leaving?) {
          // Not watched any more: simply off it.
          if (!animate) _leftWork(animate: false, toHome: leaving.toHome);
          return;
        }
        final view = questView;
        _pl.arriving = null;
        // On his field (walking between his places, or off to them):
        // off its edge first only if his house is next (else he's simply
        // back on his field, walking).
        if (animate &&
            view != null &&
            (view.place != QuestScenePlace.field || toHome)) {
          _pl.joinFrom = null;
          _pl.leaving = (from: _still(view)!, t: 0, toHome: toHome);
          return;
        }
        // Round 141: seen on his field: simply carries on from there.
        if (animate && view?.place == QuestScenePlace.field) {
          _pl.questNow = null;
          _pl.joinFrom = null;
          _onFieldAgain();
          return;
        }
        _leftWork(animate: animate, toHome: toHome);
      }
      return;
    }
    // Round 141: down where he ran out at it (off, back on): he gets up
    // there (his work as it is now, once he's up), not on his field.
    if (downAtWork) {
      _pl.questNow = now;
      _pl.questT = 0;
      return;
    }
    // Round 141: seen walking off a place, or through his door: that
    // first (then he sets off from his field).
    if (animate && (_pl.leaving != null || _pl.homeTo != null)) return;
    _pl.downView = null;
    _pl.leaving = null;
    final before = _pl.questNow;
    if (activity != PipActivity.questing) {
      if (!_canGoOut) return;
      final from = x;
      _start(PipActivity.questing);
      _pl.joinFrom = animate && !freshSpawn ? from : null;
      _pl.joinT = 0;
      _pl.arriving = null;
    }
    _pl.questNow = now;
    // Round 132: in the same step, his own smooth clock carries on (the
    // room's check every second only says where he is): loops (a swing,
    // a scoop, his screen) don't hitch. Off by more than a moment, he's
    // put right.
    final went = before == null ? null : before.seconds + _pl.questT;
    final drift = went == null ? double.infinity : went - now.seconds;
    _pl.questT = before != null &&
            before.at.script == now.at.script &&
            before.at.step == now.at.step &&
            drift.abs() < 1.5
        ? drift
        : 0;
    _placeQuest();
  }

  void _stepQuest(double dt) {
    _pl.questT += dt;
    if (_pl.leaving case final leaving?) {
      final on =
          (from: leaving.from, t: leaving.t + dt, toHome: leaving.toHome);
      _pl.leaving = on;
      if (_leaveView(on) == null) {
        _pl.leaving = null;
        _leftWork(animate: true, toHome: on.toHome);
        return;
      }
    }
    if (_pl.joinFrom case final from?) {
      _pl.joinT += dt;
      // Off his field: at his work (Round 141: walking in to it, unless
      // it's on his field too).
      if (from + QuestView.walkSpeed * _pl.joinT > roomWidth + 2) {
        _pl.joinFrom = null;
        _arriveFrom(null);
      }
    } else if (_pl.arriving case final arriving?) {
      final view = _workView;
      final end = view?.pipCentre(roomWidth);
      final step = QuestView.walkSpeed * 1.5 * dt;
      if (end == null || (end - arriving.at).abs() <= step) {
        _pl.arriving = null;
      } else {
        _pl.arriving = (
          at: arriving.at + step * (end - arriving.at).sign,
          t: arriving.t + dt,
        );
      }
    }
    _placeQuest();
  }

  /// Where he is in his room for what his quest's work looks like now:
  /// in the house area, as far along as its camera lets the room show.
  void _placeQuest() {
    final view = questView;
    if (view == null) return;
    facingRight = view.facingRight;
    final centre = view.pipCentre(roomWidth);
    if (view.place == QuestScenePlace.house) {
      final most = math.max(0, PipHouse.areaWidth - roomWidth).toDouble();
      questCamera = (centre - roomWidth / 2).clamp(0, most).toDouble();
      x = _pastHouseArea(centre) - questCamera - PipBrain.width / 2;
    } else {
      questCamera = 0;
      x = centre - PipBrain.width / 2;
    }
  }

  /// Round 141: in a room wider than the house area, past its right end
  /// (going to or from his field, [QuestView.edge]) stretched to reach off
  /// the room's edge: never vanishing in view.
  double _pastHouseArea(double centre) {
    const area = PipHouse.areaWidth;
    if (centre <= area || roomWidth + 12 <= QuestView.edge) return centre;
    final reach = (roomWidth + 12 - area) / (QuestView.edge - area);
    return area + (centre - area) * reach;
  }

  // Round 128: his house, once it's built (spec section 10).

  /// In his house or on his field, as his life says ([wanted]; his room
  /// checks every second). He goes when he's free to (not in the middle
  /// of something: asleep or off where he is, he stays till he's up);
  /// he's simply there.
  void home(bool wanted, {bool animate = false}) {
    if (wanted == atHome) {
      _pl.homeTo = null;
      return;
    }
    final free = _canGoOut ||
        activity == PipActivity.lookingUp ||
        activity == PipActivity.dancing ||
        activity == PipActivity.sheltering;
    if (!free) return;
    // Round 134: seen, he walks out first: to his door, or off his field.
    if (animate) {
      if (_pl.homeTo == wanted && activity == PipActivity.walking) return;
      _pl.homeTo = wanted;
      _pl.visit = null;
      _packTent();
      final to = atHome ? PipBrain.homeRight - PipBrain.width : roomWidth + 2.0;
      _stand();
      _pl.pastEdge = !atHome;
      _target = to;
      facingRight = to > x;
      activity = PipActivity.walking;
      return;
    }
    _switchHome(wanted);
  }

  void _switchHome(bool wanted) {
    atHome = wanted;
    questCamera = 0;
    _pl.visit = null;
    // His tent's not needed in (or taken along).
    _packWeatherAway();
    if (activity != PipActivity.showing) _stand();
    x = wanted
        ? PipBrain.homeLeft +
            random.nextDouble() *
                (PipBrain.homeRight - PipBrain.width - PipBrain.homeLeft)
        : x.clamp(_minX, _maxX).toDouble();
    // His station where he is now.
    if (_stationUp) _placeStation();
  }

  /// His house drawn round him at home (the house area, as at work).
  QuestView? get homeView {
    if (!atHome || PipBrain._awayFromHome.contains(activity)) return null;
    return QuestView(
      place: QuestScenePlace.house,
      house: PipHouse.finished,
      offset: x + PipBrain.width / 2,
      pose: QuestPose.standing,
      t: sceneClock,
    );
  }

  /// At home now and then: a little dance, a look out of a window at the
  /// weather, a warm by the fire.
  bool _maybeHomeEvent() {
    switch (random.nextInt(3)) {
      case 0:
        _start(PipActivity.dancing);
      case 1:
        final (wx, _) = PipHouse.windows[random.nextInt(2)];
        _goVisit(wx + 9 - PipBrain.width / 2, true);
      default:
        _goVisit(PipHouse.fireplaceRight + 2.0, false);
    }
    return true;
  }

  void _goVisit(double at, bool faceRight) {
    final to = at.clamp(_minX, _maxX).toDouble();
    if ((to - x).abs() < 2) {
      _pl.visit = (to, faceRight);
      _arrive();
      return;
    }
    _pl.visit = (to, faceRight);
    _target = to;
    facingRight = to > x;
    _start(PipActivity.walking);
  }

  /// Arrived somewhere ([_stand] just done): at a window he looks out,
  /// at the fire he stands warming a while.
  void _arrive() {
    // Round 134: out of one place, in through the other.
    if (_pl.homeTo case final going?) {
      _pl.homeTo = null;
      _switchHome(going);
      if (going) {
        _inAtDoor();
      } else {
        _walkIn();
      }
      return;
    }
    final visit = _pl.visit;
    _pl.visit = null;
    if (visit == null || !atHome) return;
    final (_, faceRight) = visit;
    facingRight = faceRight;
    if (faceRight) {
      _start(PipActivity.lookingUp);
    } else {
      _standFor = 5 + random.nextDouble() * 3;
      _turnAt = null;
    }
  }

  /// His frame at his quest's work: walking, or a beat of effort.
  PipFrame get _questFrame {
    final view = questView;
    if (view == null) return PipFrame.idle;
    return switch (view.pose) {
      QuestPose.walking => const [
          PipFrame.step1,
          PipFrame.step2,
          PipFrame.step3,
          PipFrame.step4,
        ][(view.t / PipBrain.stepTime).floor() % 4],
      QuestPose.working when view.swing == null =>
        (view.t / 0.6).floor().isEven ? PipFrame.idle : PipFrame.oh,
      _ => PipFrame.idle,
    };
  }

  /// Walking past his room's edge now (not held in it).
  bool get _offEdge => _pl.pastEdge;

  /// Held in his room again (a walk past its edge over, or cut short).
  void _holdIn() => _pl.pastEdge = false;

  /// No visit in his house under way (a plain walk now).
  void _forgetVisit() => _pl.visit = null;

  /// Down where he ran out at his work: how high that was; null: not.
  double? get _downLift => downAtWork ? _pl.downView!.lift : null;
}
