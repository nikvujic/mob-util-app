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
      // Round 141: seen in his house, or walking in from his field's
      // edge: out on his field first.
      if (animate && (atHome || _offEdge)) return;
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
    run.storm = weather == WeatherKind.storm;
    run.snowFoes = weather == WeatherKind.snow;
    run.pace = paceIn(weather);
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

  /// On the bus at night: dozing in his seat, or not.
  void _busDozes(bool asleep) => _out.busAsleep = asleep;
  bool get _busAsleep => _out.busAsleep;

  /// Seconds since his life last said how long he's been out.
  void _tickOutRun(double dt) => _out.outRunSince += dt;

  /// Pip Home's ski day preview (snow, his beanie).
  bool get _skiPreview => _out.previewSki;
}
