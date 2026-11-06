part of 'pip_brain.dart';

/// Round 138 (out of `pip_brain.dart`): his days out: his adventure
/// (Round 63: running, striking bugs, his break at the tavern; Round 67:
/// skiing) and his ski trip's bus (Round 67), and Pip Home's previews of
/// them.
class _PipOutingsState {
  PipBus? bus;
  bool busAsleep = false;
  double? runPreview;
  bool previewBoss = false;
  bool previewSki = false;
  double? busPreview;
  PipRun? run;

  /// Round 73: a boss may come today (his life says).
  bool bossDue = false;
  double? outRun;
  double outRunSince = 0;
  bool outPaused = false;
  double? treeRun;

  /// A level up seen (Round 63): a flash over him for [levelFlashTime],
  /// with a buzz (no sound).
  double? levelFlash;
}

extension PipBrainOutings on PipBrain {
  bool get bossDue => _out.bossDue;
  set bossDue(bool value) => _out.bossDue = value;

  // Round 67: his ski trip's bus.

  /// The bus ride, as it's drawn; null: not on it.
  PipBus? get bus => activity == PipActivity.riding ? _out.bus : null;

  /// On the bus or not, as his life says ([trip]; his room checks every
  /// second). [animate]: seen happening (it pulls in and he boards; it
  /// stops and he steps out), else he's simply on it, or off.
  void ride(PipTripNow trip, {required bool animate}) {
    final bus = _out.bus;
    if (_out.busPreview != null) return;
    if (trip.leg == null) {
      if (bus == null || activity != PipActivity.riding) return;
      if (animate) {
        bus.arrive();
      } else {
        _endBus();
      }
      return;
    }
    if (activity == PipActivity.riding) return;
    if (activity == PipActivity.adventuring) _endRun();
    if (!_canBoard) return;
    _out.bus = PipBus(roomWidth: roomWidth, pipX: x)..start(animate: animate);
    x = _out.bus!.pipX;
    _start(PipActivity.riding);
  }

  /// Whether he can get on now: up and about (or just made, or asleep or
  /// off: he's simply on it).
  bool get _canBoard =>
      _canGoOut ||
      activity == PipActivity.asleep ||
      activity == PipActivity.off;

  void _stepBus(double dt) {
    final bus = _out.bus;
    if (bus == null) {
      _stand();
      return;
    }
    final preview = _out.busPreview;
    if (preview != null && bus.phase == BusPhase.riding) {
      _out.busPreview = preview + dt;
      if (_out.busPreview! >= PipBrain.busPreviewRide) bus.arrive();
    }
    bus.roomWidth = roomWidth;
    bus.step(dt);
    x = bus.pipX;
    facingRight = bus.inside || bus.facingRight;
    if (bus.phase == BusPhase.done) _endBus();
  }

  void _endBus() {
    final bus = _out.bus;
    _out.bus = null;
    _out.busPreview = null;
    if (bus != null) x = bus.pipX.clamp(0, _maxX).toDouble();
    _stand();
  }

  /// Played from Pip Home's Adventures (Round 67): a short day out (a
  /// bug, one that gets him, a beetle), a ski run ([ski]: snowing, his
  /// gear, a fall), or a boss fight ([boss], Round 73), with no XP; it
  /// ends by itself, or with [stopPreviews]. True if he could (up and
  /// about).
  bool previewAdventure({bool ski = false, bool boss = false}) {
    if (!_canGoOut) return false;
    _out.run = PipRun(random, x: x, roomWidth: roomWidth, skiing: ski);
    _start(PipActivity.adventuring);
    _out.run!
      ..start(animate: true)
      ..spawns = !boss;
    _out.runPreview = 0;
    _out.previewSki = ski;
    _out.previewBoss = boss;
    return true;
  }

  /// Snowing: a ski day, or a ski preview.
  bool get snowing => snowy || _out.previewSki;

  /// Rain, drizzle, snow or a storm out (Round 128).
  bool get wetOut =>
      snowing ||
      switch (_wx.weather) {
        WeatherKind.drizzle ||
        WeatherKind.rain ||
        WeatherKind.snow ||
        WeatherKind.storm =>
          true,
        _ => false,
      };

  /// Back on his info card (or leaving): a preview going on stops.
  void stopPreviews() {
    if (_out.runPreview != null && activity == PipActivity.adventuring) {
      _endRun();
    }
    if (_out.busPreview != null && activity == PipActivity.riding) _endBus();
  }

  /// Played from Pip Home's Adventures (Round 67): the bus pulls in, he
  /// boards, it drives a while, stops and he steps out. True if it could.
  bool previewBus() {
    if (!_canGoOut) return false;
    _out.bus = PipBus(roomWidth: roomWidth, pipX: x)..start(animate: true);
    _start(PipActivity.riding);
    _out.busPreview = 0;
    return true;
  }

  // Round 63: his adventures.

  /// His day out, as it's drawn (the room's painter); null: not out.
  PipRun? get run => activity == PipActivity.adventuring ? _out.run : null;

  /// Whether he can set off now: up and about, or just made (opened
  /// while he's out: he's simply there, out).
  bool get _canGoOut =>
      activity == PipActivity.standing ||
      activity == PipActivity.walking ||
      activity == PipActivity.showing ||
      freshSpawn;

  /// Out on his adventure, or not, as his life says ([out]; his room
  /// checks every second): he sets off, takes his break, comes back.
  /// [animate]: seen happening (he walks to the middle and draws his
  /// sword; at 18:00 he slows to a stop); else he's simply out or back.
  void adventure(PipOut? out, {required bool animate}) {
    final run = _out.run;
    // A preview (Pip Home's Adventures) runs its course.
    if (_out.runPreview != null) return;
    if (out == null) {
      if (run == null || activity != PipActivity.adventuring) return;
      if (animate) {
        run.want(onBreak: false, end: true);
      } else {
        _endRun();
      }
      return;
    }
    if (activity != PipActivity.adventuring) {
      if (!_canGoOut) return;
      _setOut();
      // Round 66: opened as his break starts: seen starting (he runs up
      // to the tavern); later in it, simply at the table.
      if (out.onBreak &&
          !animate &&
          out.breakDone >= PipBrain.breakJustStarted) {
        _out.run!.seated();
      } else {
        _out.run!.start(animate: animate);
      }
    }
    _out.run!.want(onBreak: out.onBreak, done: out.breakDone);
  }

  /// Round 132: his room opened again on him out a while after it was
  /// left: what he was doing out there then is long past, so his run is
  /// taken up afresh from his life (at the table on his break, else
  /// simply running), not carried on from where it was left.
  void freshOut() {
    if (activity != PipActivity.adventuring || _out.runPreview != null) return;
    _endRun();
  }

  /// Just registered as an adventurer (Pip Home): his sword held up high,
  /// then off he goes. True if he could (up and about).
  bool cheer() {
    if (!_canGoOut || !spawned && !freshSpawn) return false;
    _setOut();
    _out.run!.start(cheer: true, animate: true);
    return true;
  }

  /// Cheering just now (his fanfare plays with it).
  bool get cheering => run?.phase == RunPhase.cheer;

  /// His gear in the snowbank (not on him, not on a bus).
  bool get gearInBank =>
      snowing &&
      !(run?.geared ?? false) &&
      activity != PipActivity.egg &&
      activity != PipActivity.riding;

  void _setOut() {
    _out.run = PipRun(random, x: x, roomWidth: roomWidth, skiing: skiing);
    _start(PipActivity.adventuring);
  }

  void _stepRun(double dt) {
    final run = _out.run;
    if (run == null) {
      _stand();
      return;
    }
    // Round 67: a preview's moments, then home.
    final preview = _out.runPreview;
    if (preview != null) {
      final next = preview + dt;
      _out.runPreview = next;
      bool at(double s) => preview < s && next >= s;
      if (run.skiing) {
        if (at(PipBrain.previewEventAt)) run.fallNow();
      } else if (_out.previewBoss) {
        if (at(PipBrain.previewEventAt - 3)) {
          run.bugComing(hits: false, foe: PipFoe.boss);
        }
      } else {
        if (at(PipBrain.previewEventAt - 4)) run.bugComing(hits: false);
        if (at(PipBrain.previewEventAt + 1.5)) run.bugComing(hits: true);
        // Round 73: a beetle, two strikes.
        if (at(PipBrain.previewEventAt + 5.5)) {
          run.bugComing(hits: false, foe: PipFoe.beetle);
        }
      }
      if (at(PipBrain.previewLength)) run.want(onBreak: false, end: true);
    } else {
      run.bossDue = bossDue;
    }
    // Round 75: the weather out: a storm (his tent), snowmen, fog.
    // (On skis he skis on: no tent.)
    run.storm = _wx.weather == WeatherKind.storm;
    run.snowFoes = _wx.weather == WeatherKind.snow;
    run.pace = paceIn(_wx.weather);
    run.roomWidth = roomWidth;
    run.step(dt);
    // Struck down in a preview: no XP.
    if (preview != null) run.defeats.clear();
    x = run.x;
    facingRight = run.facingRight;
    _buzzes.addAll(run.buzzes);
    run.buzzes.clear();
    if (run.phase == RunPhase.done) _endRun();
  }

  void _endRun() {
    final run = _out.run;
    _out.run = null;
    _out.runPreview = null;
    _out.previewBoss = false;
    _out.previewSki = false;
    if (run != null) x = run.x;
    _stand();
  }

  /// Steps while out: quicker running.
  PipFrame get _runFrame {
    final run = _out.run;
    if (run == null) return PipFrame.idle;
    if (run.stepping) {
      return const [
        PipFrame.step1,
        PipFrame.step2,
        PipFrame.step3,
        PipFrame.step4,
      ][(run.clock / (PipBrain.stepTime / run.stepRate)).floor() % 4];
    }
    return switch (run.phase) {
      RunPhase.knocked => PipFrame.oh,
      RunPhase.down => PipFrame.tuck,
      // Round 74: sitting still (it was "oh" and tucked in turn: up and
      // down, like squats), chewing as he eats.
      RunPhase.sitting => run.chewing && (run.clock / 0.15).floor().isEven
          ? PipFrame.chew
          : PipFrame.sit,
      _ => PipFrame.idle,
    };
  }

  /// Round 74: how long he's been running on his day out, as his life
  /// says ([syncOutRun], every second), going on between ([paused]: on
  /// his break, it stands); null: not out. His field's trees go by with
  /// it, alike in every room.
  double? get outRun {
    final base = _out.outRun;
    return base == null ? null : base + (_out.outPaused ? 0 : _out.outRunSince);
  }

  void syncOutRun(double? seconds, {required bool paused}) {
    _out.outRun = seconds;
    _out.outRunSince = 0;
    _out.outPaused = paused;
  }

  /// Round 76: how far his field's trees have gone by (seconds of his
  /// running): they move with the ground (still while he's knocked over,
  /// fetching his sword, at his break), catching up with [outRun] a little
  /// as he runs on (a little quicker or slower), so every room keeps to
  /// it; a long way off (just opened), they're simply there.
  double? get treeRun => _out.treeRun;

  void _stepTrees(double dt) {
    final target = outRun;
    final run = _out.run;
    final trees = _out.treeRun;
    if (target == null || run == null) {
      _out.treeRun = null;
      return;
    }
    if (trees == null || (target - trees).abs() > PipBrain.treeJump) {
      _out.treeRun = target;
      return;
    }
    // Moving as the ground does (at his pace: 1 running, 0 stopped).
    final moving = run.speed / (PipRun.runSpeed * run.pace);
    final catchUp = ((target - trees) / 4)
        .clamp(-PipBrain.treeCatchUp, PipBrain.treeCatchUp);
    _out.treeRun = trees + dt * moving * (1 + catchUp);
  }

  /// Out fighting, as he really is (not a preview, not skiing, not on
  /// his break or setting off or back): watched, his XP shown goes up as
  /// he strikes bugs.
  bool get fighting {
    final run = _out.run;
    return activity == PipActivity.adventuring &&
        run != null &&
        _out.runPreview == null &&
        !run.skiing &&
        const {
          RunPhase.running,
          RunPhase.knocked,
          RunPhase.down,
          RunPhase.toSword,
          RunPhase.pickUp,
          RunPhase.back,
        }.contains(run.phase);
  }

  /// What he's struck down since last asked (none in a preview).
  List<PipFoe> takeDefeats() {
    final run = _out.run;
    if (run == null) return const [];
    final taken = [...run.defeats];
    run.defeats.clear();
    return taken;
  }

  /// [xp] gained, rising over the last foe he struck down.
  void showXp(int xp) => _out.run?.popXp(xp);

  void levelUp() {
    _out.levelFlash = 0;
    _buzzes.add(PipBuzz.medium);
  }

  /// The level-up flash, 0 → 1; null: none.
  double? get levelFlash {
    final f = _out.levelFlash;
    return f == null ? null : f / PipBrain.levelFlashTime;
  }

  void _stepLevelFlash(double dt) {
    final f = _out.levelFlash;
    if (f == null) return;
    final next = f + dt;
    // A second buzz a moment after the first.
    if (f < 0.25 && next >= 0.25) _buzzes.add(PipBuzz.light);
    _out.levelFlash = next >= PipBrain.levelFlashTime ? null : next;
  }

  void _stand() {
    _pl.pastEdge = false;
    activity = PipActivity.standing;
    _t = 0;
    _standFor = 1.5 + random.nextDouble() * 3.5;
    // Now and then he looks round the other way for a bit.
    _turnAt = random.nextDouble() < 0.4
        ? _standFor * (0.3 + 0.4 * random.nextDouble())
        : null;
  }

  void _walk() {
    _pl.visit = null;
    // Somewhere at least a few steps away, inside the room.
    final max = _maxX;
    if (max - _minX < 8) {
      _stand();
      return;
    }
    // Round 44: not into his station, if it's up.
    var low = _minX, high = max;
    if (_st.x != null) {
      if (_st.right) {
        high = math.min(high, _plugX);
      } else {
        low = math.max(low, _plugX);
      }
    }
    var target = x;
    for (var i = 0; i < 10 && (target - x).abs() < 6; i++) {
      target = low + random.nextDouble() * math.max(0, high - low);
    }
    if ((target - x).abs() < 6) {
      _stand();
      return;
    }
    _target = target;
    facingRight = target > x;
    activity = PipActivity.walking;
    _t = 0;
  }

  /// The frame to draw now.
  PipFrame get frame => switch (activity) {
        PipActivity.egg => PipFrame.idle,
        PipActivity.hatching => _t < PipBrain.jumpEnd
            ? PipFrame.oh
            : (_t < PipBrain.hatchLandEnd ? PipFrame.tuck : PipFrame.idle),
        PipActivity.spawning =>
          _t < PipBrain.hopEnd ? PipFrame.oh : PipFrame.tuck,
        PipActivity.standing => _blinking > 0 ? PipFrame.blink : PipFrame.idle,
        PipActivity.walking => _stepFrame,
        PipActivity.fallingAsleep =>
          _t < PipBrain.settleAt ? PipFrame.idle : PipFrame.tuck,
        PipActivity.asleep || PipActivity.stirring => PipFrame.tuck,
        PipActivity.wakingUp => _t < PipBrain.legsOutAt
            ? PipFrame.tuck
            // Eyes still shut, before the yawn and after it.
            : _t < PipBrain.yawnAt ||
                    (_t >= PipBrain.yawnEnd && _t < PipBrain.eyesOpenAt)
                ? PipFrame.blink
                : PipFrame.idle,
        PipActivity.poweringOff ||
        PipActivity.off ||
        PipActivity.poweringOn =>
          PipFrame.idle,
        PipActivity.fetching => _picking == null
            ? (_atTarget ? PipFrame.idle : _stepFrame)
            : PipFrame.idle, // Round 53: a crouch ([stretch]), not tucked
        PipActivity.toStation => _stepFrame,
        PipActivity.plugging ||
        PipActivity.charging ||
        PipActivity.unplugging =>
          PipFrame.idle,
        // Round 52.
        PipActivity.falling || PipActivity.thrown => PipFrame.oh,
        PipActivity.angry || PipActivity.showing => PipFrame.idle,
        PipActivity.bugHunt => _bugWalking ? _stepFrame : PipFrame.idle,
        PipActivity.flower => _ev.flowerPhase == 1 ? _stepFrame : PipFrame.idle,
        PipActivity.butterfly => _butterflyClose ? PipFrame.oh : PipFrame.idle,
        PipActivity.stargazing => PipFrame.oh,
        PipActivity.dancing => (_t / PipBrain.beatTime * 2).floor().isEven
            ? PipFrame.step1
            : PipFrame.step3,
        PipActivity.ball => switch (_ev.ballPhase) {
            1 => _stepFrame,
            2 => PipFrame.step1,
            _ => PipFrame.idle,
          },
        // Round 53: his mouth open for each bite.
        PipActivity.eating =>
          PipBrain.bites.any((b) => _t >= b && _t < b + PipBrain.biteTime)
              ? PipFrame.oh
              : PipFrame.idle,
        PipActivity.adventuring => _runFrame,
        PipActivity.riding => _out.bus?.walking == true
            ? const [
                PipFrame.step1,
                PipFrame.step2,
                PipFrame.step3,
                PipFrame.step4,
              ][(_t / PipBrain.stepTime).floor() % 4]
            : PipFrame.idle,
        PipActivity.sheltering ||
        PipActivity.weatherEvent ||
        PipActivity.lookingUp =>
          _weatherFrame,
        PipActivity.questing => _questFrame,
      };

  /// Hurrying, his steps come quicker too (Round 44).
  PipFrame get _stepFrame => const [
        PipFrame.step1,
        PipFrame.step2,
        PipFrame.step3,
        PipFrame.step4,
      ][(_t /
                  (_hurrying
                      ? PipBrain.stepTime * PipBrain.speed / PipBrain.hurry
                      : PipBrain.stepTime))
              .floor() %
          4];

  bool get _hurrying =>
      activity == PipActivity.toStation ||
      activity == PipActivity.fetching ||
      activity == PipActivity.bugHunt;

  bool get _atTarget => (_target - x).abs() < 0.01;

  /// How far below the ground he still is (0: fully up), in pixels.
  double get sunk {
    if (activity != PipActivity.spawning) return 0;
    if (_t < PipBrain.crackEnd) return PipBrain.height.toDouble();
    if (_t < PipBrain.riseEnd) {
      final p =
          (_t - PipBrain.crackEnd) / (PipBrain.riseEnd - PipBrain.crackEnd);
      return PipBrain.height * (1 - PipBrain._easeOut(p));
    }
    return 0;
  }

  /// How high above the ground (a hop, or a step's bob), in pixels.
  /// Round 134: down at his work (off, back on), where he fell: up on
  /// the floor or the scaffold.
  double get lift {
    final own = _ownLift;
    if (_pl.downView case final view?
        when PipBrain._downActs.contains(activity)) {
      return view.lift + own;
    }
    return own;
  }

  double get _ownLift {
    // Round 67: in his seat on the bus, his feet hidden.
    if (_out.bus case final bus? when activity == PipActivity.riding) {
      return bus.inside ? PipBus.seatLift : 0;
    }
    // Round 63: out, as his run says (a knock, his seat), and a bob.
    if (_out.run case final run? when activity == PipActivity.adventuring) {
      final bob =
          run.stepping && (frame == PipFrame.step1 || frame == PipFrame.step3)
              ? 1.0
              : 0.0;
      final tucked = frame == PipFrame.tuck ||
          frame == PipFrame.sit ||
          frame == PipFrame.chew;
      return run.lift + bob - (tucked ? 2 : 0);
    }
    // Round 75: a puddle jump, hops in the snow.
    if (_weatherLift case final weather?) return weather;
    // Round 127: at his quest's work: the floor, the scaffold, a bob.
    if (questView case final view? when activity == PipActivity.questing) {
      final bob = view.pose == QuestPose.walking &&
              (frame == PipFrame.step1 || frame == PipFrame.step3)
          ? 1.0
          : 0.0;
      return view.lift + bob;
    }
    // Round 52: dropping from the sky, or thrown in on an arc.
    if (activity == PipActivity.falling && _t < _fallTime) {
      final left = _fallTime - _t;
      return 0.5 * PipBrain.gravity * left * left;
    }
    if (activity == PipActivity.thrown && _t < PipBrain.throwTime) {
      return _throwHigh * math.sin(math.pi * _t / PipBrain.throwTime);
    }
    if (activity == PipActivity.dancing) {
      // A hop on every beat.
      return 3 * math.sin(math.pi * ((_t / PipBrain.beatTime) % 1)).abs();
    }
    if (activity == PipActivity.showing &&
        _lk.screenShow.hops &&
        _t < PipBrain.showHop) {
      return 3 *
          math.sin(math.pi * _t / PipBrain.showHop); // a hop: something came
    }
    // Round 53: the pill twice (a second hop).
    if (activity == PipActivity.showing &&
        _lk.screenShow == PipScreen.pill &&
        _t >= 0.5 &&
        _t < 0.9) {
      return 3 * math.sin(math.pi * (_t - 0.5) / 0.4);
    }
    if (activity == PipActivity.hatching &&
        _t >= PipBrain.popEnd &&
        _t < PipBrain.jumpEnd) {
      final p = (_t - PipBrain.popEnd) / (PipBrain.jumpEnd - PipBrain.popEnd);
      // A little higher than the spawn's hop, still in the room.
      return 7 * math.sin(math.pi * p);
    }
    if (activity == PipActivity.spawning &&
        _t >= PipBrain.riseEnd &&
        _t < PipBrain.hopEnd) {
      final p = (_t - PipBrain.riseEnd) / (PipBrain.hopEnd - PipBrain.riseEnd);
      return 6 * math.sin(math.pi * p);
    }
    // Round 37: up from sleep, back on, or a battery picked up: a hop.
    double hop(double from, double to, double high) {
      if (_t < from || _t >= to) return 0;
      return high * math.sin(math.pi * (_t - from) / (to - from));
    }

    // Settled down asleep (legs tucked): down on the ground.
    if (frame == PipFrame.tuck &&
        (activity == PipActivity.asleep ||
            activity == PipActivity.fallingAsleep ||
            activity == PipActivity.stirring ||
            activity == PipActivity.wakingUp)) {
      return -2;
    }
    switch (activity) {
      case PipActivity.wakingUp:
        return hop(PipBrain.wakeHopStart, PipBrain.wakeHopEnd, 3);
      case PipActivity.poweringOn:
        return hop(PipBrain.riseUpEnd, PipBrain.onEnd, 3);
      case PipActivity.fetching when _picking != null:
        final p = _picking!;
        if (p < PipBrain.shakeEnd || p >= PipBrain.pickEnd) return 0;
        // Round 97: after his shake, a hop.
        return 4 *
            math.sin(math.pi *
                (p - PipBrain.shakeEnd) /
                (PipBrain.pickEnd - PipBrain.shakeEnd));
      default:
    }
    if (frame == PipFrame.step1 || frame == PipFrame.step3) return 1;
    return 0;
  }

  /// Squash and stretch: (width, height) scale.
  (double, double) get stretch {
    // Round 53: waking, a stretch up; picking something up, a crouch (his
    // feet stay on the ground, his legs don't float).
    if (activity == PipActivity.wakingUp &&
        _t >= PipBrain.yawnAt &&
        _t < PipBrain.yawnEnd) {
      final s = 0.12 *
          math.sin(math.pi *
              (_t - PipBrain.yawnAt) /
              (PipBrain.yawnEnd - PipBrain.yawnAt));
      return (1 - s / 2, 1 + s);
    }
    // Round 97: a happy little shake once the new battery's in.
    if (activity == PipActivity.fetching &&
        _picking != null &&
        _picking! >= PipBrain.handOut &&
        _picking! < PipBrain.shakeEnd) {
      final s = 0.07 *
          math.sin(math.pi *
              8 *
              (_picking! - PipBrain.handOut) /
              (PipBrain.shakeEnd - PipBrain.handOut));
      return (1 + s, 1 - s);
    }
    final crouch = switch (activity) {
      PipActivity.adventuring => _out.run?.crouch,
      PipActivity.flower when _ev.flowerPhase == 2 => _t / PipBrain.flowerPick,
      // Round 54: down for the new battery, and up again with it.
      PipActivity.fetching
          when _picking != null &&
              _picking! >= PipBrain.throwAt &&
              _picking! < PipBrain.atSlotAgain =>
        (_picking! - PipBrain.throwAt) /
            (PipBrain.atSlotAgain - PipBrain.throwAt),
      _ => null,
    };
    if (crouch != null) {
      final s = 0.18 * math.sin(math.pi * crouch.clamp(0.0, 1.0));
      return (1 + s / 2, 1 - s);
    }
    // Round 52: landing from the sky or a throw, squashed and springing
    // back.
    final landed = switch (activity) {
      PipActivity.falling => _t - _fallTime,
      PipActivity.thrown => _t - PipBrain.throwTime,
      _ => null,
    };
    if (landed != null) {
      if (landed < 0) {
        return activity == PipActivity.falling ? (0.9, 1.15) : (1, 1);
      }
      if (landed < PipBrain.landHold) {
        final s = 0.28 * math.sin(math.pi * landed / PipBrain.landHold);
        return (1 + s / 2, 1 - s);
      }
      return (1, 1);
    }
    if (activity == PipActivity.hatching) {
      if (_t >= PipBrain.popEnd && _t < PipBrain.jumpEnd) {
        final p = (_t - PipBrain.popEnd) / (PipBrain.jumpEnd - PipBrain.popEnd);
        final s = 0.18 * math.cos(math.pi * p).clamp(0, 1);
        return (1 - s / 2, 1 + s);
      }
      if (_t >= PipBrain.jumpEnd && _t < PipBrain.hatchLandEnd) {
        final p = (_t - PipBrain.jumpEnd) /
            (PipBrain.hatchLandEnd - PipBrain.jumpEnd);
        final s = 0.2 * math.sin(math.pi * p);
        return (1 + s / 2, 1 - s);
      }
      return (1, 1);
    }
    if (activity != PipActivity.spawning) return (1, 1);
    if (_t >= PipBrain.riseEnd && _t < PipBrain.hopEnd) {
      // Stretched going up, back to size at the top.
      final p = (_t - PipBrain.riseEnd) / (PipBrain.hopEnd - PipBrain.riseEnd);
      final s = 0.18 * math.cos(math.pi * p).clamp(0, 1);
      return (1 - s / 2, 1 + s);
    }
    if (_t >= PipBrain.hopEnd && _t < PipBrain.landEnd) {
      // Squashed on landing, springing back.
      final p = (_t - PipBrain.hopEnd) / (PipBrain.landEnd - PipBrain.hopEnd);
      final s = 0.2 * math.sin(math.pi * p);
      return (1 + s / 2, 1 - s);
    }
    return (1, 1);
  }

  /// The cracked ground's dirt, flying up while he comes out: 0 none,
  /// then 0 → 1 over the crack and the rise.
  double get dirt {
    if (activity != PipActivity.spawning || _t >= PipBrain.riseEnd) return 0;
    return _t / PipBrain.riseEnd;
  }
}
