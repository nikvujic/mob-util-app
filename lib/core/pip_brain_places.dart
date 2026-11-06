part of 'pip_brain.dart';

/// Round 138 (out of `pip_brain.dart`): his places: his quest's work
/// (Round 127), his finished house (Round 128), and getting between them
/// and his field without a cut while he's watched (Round 133–136).
class _PipPlacesState {
  /// His quest's work, as his life last said (the room asks every
  /// second), and the seconds since.
  PipQuestNow? questNow;
  double questT = 0;

  /// Seconds at his quest's work since he started this time (his
  /// screen's pill runs on it, Round 132).
  double questClock = 0;

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
    return QuestView.of(now.at, now.seconds + _pl.questT);
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

  /// Back on where he ran out at his work: at it again.
  void _backToWork() {
    _pl.downView = null;
    _start(PipActivity.questing);
    _pl.questClock = 0;
    _pl.joinFrom = null;
    _placeQuest();
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
        _pl.questNow = null;
        _pl.joinFrom = null;
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
      return;
    }
    _pl.downView = null;
    final before = _pl.questNow;
    if (activity != PipActivity.questing) {
      if (!_canGoOut) return;
      final from = x;
      _start(PipActivity.questing);
      _pl.questClock = 0;
      _pl.joinFrom = animate && !freshSpawn ? from : null;
      _pl.joinT = 0;
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
    _pl.questClock += dt;
    if (_pl.joinFrom case final from?) {
      _pl.joinT += dt;
      // Off his field: at his work.
      if (from + QuestView.walkSpeed * _pl.joinT > roomWidth + 2) {
        _pl.joinFrom = null;
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
      x = centre - questCamera - PipBrain.width / 2;
    } else {
      questCamera = 0;
      x = centre - PipBrain.width / 2;
    }
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
      _wx.tent = null;
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
    _wx.tent = null;
    _wx.flyFrom = null;
    _wx.snowman = null;
    if (activity != PipActivity.showing) _stand();
    x = wanted
        ? PipBrain.homeLeft +
            random.nextDouble() *
                (PipBrain.homeRight - PipBrain.width - PipBrain.homeLeft)
        : x.clamp(_minX, _maxX).toDouble();
    // His station where he is now.
    if (_st.x != null) _placeStation();
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
}
