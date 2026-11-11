import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_adventure.dart';
import 'package:the_app/core/pip_bus.dart';
import 'package:the_app/core/pip_run.dart';
import 'package:the_app/core/pip_weather.dart';
import 'package:the_app/core/pip_house.dart';
import 'package:the_app/core/pip_quest_scene.dart';
import 'package:the_app/core/weather.dart';

part 'pip_brain_places.dart';
part 'pip_brain_battery.dart';
part 'pip_brain_outings.dart';
part 'pip_brain_events.dart';
part 'pip_brain_looks.dart';
part 'pip_brain_station.dart';
part 'pip_brain_types.dart';
part 'pip_brain_weather.dart';

/// Pip in his room (Round 26): where he is, which way he faces, what he's
/// doing and how he looks this moment. Advanced by [step] with the time
/// gone by; [random] picks how long he stands and where he walks, so
/// tests can make him predictable. Measured in the room's pixels (one
/// pixel of Pip's grid).
class PipBrain {
  final math.Random random;

  /// [hatched]: false, and he's still an egg (Round 34).
  PipBrain({int roomWidth = 0, math.Random? random, bool hatched = true})
      : random = random ?? math.Random(),
        activity = hatched ? PipActivity.spawning : PipActivity.egg {
    this.roomWidth = roomWidth;
  }

  int _roomWidth = 0;

  /// How wide the room is, in pixels; Pip is [width] wide. He starts in
  /// the middle once it's known, and stays inside it.
  int get roomWidth => _roomWidth;
  set roomWidth(int pixels) {
    if (pixels == _roomWidth) return;
    final first = _roomWidth == 0;
    _roomWidth = pixels;
    x = first ? _maxX / 2 : (_placed ? x : x.clamp(_minX, _maxX));
  }

  /// Round 141: where he is is his work's place's to say (at it, or down
  /// at it), not held in his room.
  bool get _placed => activity == PipActivity.questing || downAtWork;

  /// Pip's size, in pixels (Round 27: 19 tall, his screen a row taller).
  static const width = 20;
  static const height = 19;

  /// His casing's sides, in from his box's (Round 54: hands go by these).
  static const bodyInset = 2;

  /// A hand's middle beside him, a pixel off his casing: on his right or
  /// his left. Its two pixels are [handX] - 1 and [handX].
  double handBeside({required bool right}) =>
      right ? x + width - bodyInset + 2 : x + bodyInset - 2;

  /// The same for him at [x], facing [right].
  static double handBesideOf(double x, bool right) =>
      right ? x + width - bodyInset + 2 : x + bodyInset - 2;

  /// Round 75: the weather in his field and what it makes of his day
  /// (`pip_brain_weather.dart`).
  // Round 138: what he does is in parts of this library, each with its
  // state here and its doings in an extension on him:
  // `pip_brain_weather.dart` (the weather as he lives it),
  // `pip_brain_battery.dart` (a battery given him, changed),
  // `pip_brain_station.dart` (his charging station and its drone),
  // `pip_brain_events.dart` (bugs, a flower, a butterfly, a ball, a
  // shooting star), `pip_brain_looks.dart` (hats, his medicine reminder,
  // meals, his screen), `pip_brain_outings.dart` (adventures, the ski
  // bus, Pip Home's previews), `pip_brain_places.dart` (his quests' work,
  // his house, the walks between); `pip_brain_types.dart` holds the
  // types and the one table of what may start when ([mayStart]).
  final _wx = _PipWeatherState();
  final _st = _PipStationState();
  final _ev = _PipEventsState();
  final _lk = _PipLooksState();
  final _out = _PipOutingsState();
  final _pl = _PipPlacesState();
  final _bt = _PipBatteryState();

  /// Walking speed, in pixels a second.
  static const speed = 14.0;

  /// The spawn's parts, in seconds from its start.
  static const crackEnd = 0.45;
  static const riseEnd = 1.05;
  static const hopEnd = 1.45;
  static const landEnd = 1.7;

  /// How long one walking frame shows.
  static const stepTime = 0.14;

  /// Where his left edge is (0 to [roomWidth] − [width]).
  double x = 0;
  bool facingRight = true;
  PipActivity activity;

  /// Seconds into what he's doing now.
  double _t = 0;

  /// How long he stands this time; where he walks to.
  double _standFor = 0;
  double _target = 0;

  /// Seconds to the next blink.
  double _blinkIn = 2;
  double _blinking = 0;

  /// Standing, when he turns to look the other way (Round 27), if he
  /// does this time.
  double? _turnAt;

  /// Whether he has come out of the ground (only once), or out of his egg.
  bool get spawned =>
      activity != PipActivity.spawning &&
      activity != PipActivity.egg &&
      activity != PipActivity.hatching;

  /// Taps on the egg so far, and how many hatch him (Round 34): the first
  /// starts the crack, then every two widen it, and two more pop him out.
  int taps = 0;
  static const hatchTaps = 7;

  /// How far the egg is cracked: 0 (whole) to 3.
  int get crack => taps >= 5
      ? 3
      : taps >= 3
          ? 2
          : taps >= 1
              ? 1
              : 0;

  /// The hatching's parts, in seconds from the last tap: the top pops off,
  /// he jumps out, lands, and the shell fades.
  static const popEnd = 0.15;
  static const jumpEnd = 0.65;
  static const hatchLandEnd = 0.9;
  static const fadeEnd = 1.8;

  // Pip Home's Animations: one played now ([play]); every activity
  // starts through [_start].

  /// Plays [animation] now, if [mayStart] lets it (false if not). A
  /// [demo] (Pip Home's list) of falling asleep or running out comes
  /// back on its own.
  bool play(PipAnimation animation, {bool demo = false}) {
    if (!mayStart(activity, animation)) return false;
    // Round 128: his field's things don't happen in his house.
    if (atHome && fieldOnly.contains(animation)) return false;
    switch (animation) {
      case PipAnimation.spawn:
        activity = PipActivity.spawning;
        _t = 0;
      case PipAnimation.hatch:
        taps = hatchTaps;
        activity = PipActivity.hatching;
        _t = 0;
        _eggX = x;
        facingRight = false;
      case PipAnimation.walk:
        _walk();
      case PipAnimation.blink:
        _stand();
        _blinking = 0.15;
      case PipAnimation.turn:
        _stand();
        facingRight = !facingRight;
      case PipAnimation.fallAsleep:
        _start(PipActivity.fallingAsleep);
        _demo = demo;
      case PipAnimation.wakeUp:
        _start(PipActivity.wakingUp);
      case PipAnimation.nightWake:
        // Asleep: stirring. Up (Pip Home's list): asleep first, then so.
        if (activity == PipActivity.asleep) {
          _start(PipActivity.stirring);
        } else {
          _start(PipActivity.fallingAsleep);
          _demo = true;
          _demoStir = true;
        }
      case PipAnimation.powerOff:
        _fallRight = x + width + height <= roomWidth;
        _start(PipActivity.poweringOff);
        _demo = demo;
      case PipAnimation.powerOn:
        _start(PipActivity.poweringOn);
        // No battery given (a demo): straight to the screen coming on.
        if (!_hasBattery) _t = flyEnd;
      case PipAnimation.fetch:
        // Round 54: a preview (no battery used): one dropped near him.
        return takeBattery(_batterySpot);
      case PipAnimation.charge:
        // Only where there's room for the station. The phone plugged in
        // and him not at it (full, say): it plays all the same (Round 45).
        if (!_stationFits) return false;
        _startDemoCharge();
      case PipAnimation.fromSky:
        enter(PipEntrance.sky);
      case PipAnimation.fromSide:
        enter(PipEntrance.side);
      case PipAnimation.bugs:
        if (!_eventRoom) return false;
        _startBugs();
      case PipAnimation.notified:
        _startShowing(_notifyScreens[random.nextInt(_notifyScreens.length)]);
      case PipAnimation.flower:
        if (!_eventRoom) return false;
        _startFlower();
      case PipAnimation.butterfly:
        _startButterfly();
      case PipAnimation.ball:
        if (!_eventRoom) return false;
        _startBall();
      case PipAnimation.shootingStar:
        _startStar();
      case PipAnimation.dance:
        _start(PipActivity.dancing);
      case PipAnimation.medicine:
        _previewPill();
      case PipAnimation.eat:
        _start(PipActivity.eating);
      case PipAnimation.puddle ||
            PipAnimation.twirl ||
            PipAnimation.handOut ||
            PipAnimation.flakes ||
            PipAnimation.snowman ||
            PipAnimation.snowball ||
            PipAnimation.lost:
        if (!_eventRoom) return false;
        _startWeatherEvent(_weatherAnimations[animation]!);
    }
    return true;
  }

  void _start(PipActivity next) {
    _holdIn();
    // Round 128: out, on his trip, at work: not in his house then.
    if (_awayFromHome.contains(next)) atHome = false;
    activity = next;
    _t = 0;
    _demo = false;
  }

  /// Played from Pip Home's list: asleep or off, he comes back after a
  /// moment ([demoHold]).
  bool _demo = false;
  static const demoHold = 1.5;

  /// Round 77: the list's night wake: after his demo sleep, stirring.
  bool _demoStir = false;

  // His energy (Round 37): drowsy, his segments, his pace.

  /// Round 77: woken at night (his life says): drowsy, his face and pace
  /// as at one segment.
  bool drowsy = false;

  /// His energy's segments (0 to 3), from his life: his face, and how
  /// fast he walks.
  int segments = 3;

  /// Walking speed now: slower the less energy he has (Round 37).
  double get pace =>
      speed *
      switch (drowsy ? 1 : segments) { 3 => 1.0, 2 => 0.7, _ => 0.45 } *
      // Round 75: slower in the fog.
      paceIn(weather);

  /// Hurrying (Round 44: to a battery, or his station), whatever his
  /// energy: quicker than his best walk.
  static const hurry = speed * 1.6;

  // Round 37–97: a battery's measures and timings (what it does:
  // `pip_brain_battery.dart`).

  /// How far off his casing he stands from a new battery (Round 97).
  static const batteryGap = 4;

  /// Its bounce on landing: how long, how high.
  static const bounceTime = 0.3;

  static const bounceHeight = 2.0;

  /// The battery's size, how high it's dropped from, how fast it falls.
  static const batteryWidth = 4;

  static const batteryHeight = 7;

  static const dropHeight = 24.0;

  static const fallSpeed = 60.0;

  /// How often it glints, and for how long.
  static const glintEvery = 0.8;

  static const glintFor = 0.2;

  /// Changing his battery (Round 54), seconds once he's beside it: a
  /// hand pops in, goes to the slot in his side and pulls the old one
  /// out, lifts it and throws it away; he crouches, the hand takes the
  /// new one, carries it to the slot and pushes it in, pops away; a hop
  /// of joy.
  static const handIn = 0.25;

  static const atSlot = 0.5;

  static const pulledOut = 0.85;

  static const throwAt = 1.1;

  static const throwFlight = 0.9;

  static const atBattery = 1.5;

  static const grabbed = 1.65;

  static const atSlotAgain = 2.05;

  static const pushedIn = 2.4;

  static const handOut = 2.6;

  /// Round 97: a happy little shake, then a hop with sparkles.
  static const shakeEnd = 3.0;

  static const pickEnd = 3.45;

  /// Round 97: the old one thrown over his head, landing on his other
  /// side (a clunk, a puff of dust), lying there a moment, fading.
  static const landedLies = 0.5;

  static const landedFades = 0.4;

  static const sparkFor = 0.35;

  /// The slot's bottom (height above the ground) and its height.
  static const slotUp = 6.0;

  static const slotRows = 7;

  /// Which way he fell (off): to the right, or the left (no room there).
  bool _fallRight = true;
  bool get fallRight => _fallRight;

  // His life shown (Round 37): awake, asleep, off; and how long each
  // takes.

  /// What to show, from his life (Round 37), made so: straight away if
  /// he's just appeared (instead of coming out of the ground), or with
  /// its animation. False if he's busy now (try again later).
  bool show(PipShow show) {
    // Round 67: on the bus, he dozes in his seat at night; nothing else.
    if (activity == PipActivity.riding) {
      _busDozes(show == PipShow.asleep || show == PipShow.fallAsleep);
      return true;
    }
    // Round 44: plugged in at bedtime, he unplugs first (then sleeps;
    // the station stays, unused, while the phone's plugged in).
    _bedtime = show == PipShow.asleep || show == PipShow.fallAsleep;
    if (activity == PipActivity.charging && _bedtime) {
      _startUnplugging();
      return false;
    }
    // Round 141: walking in from (or off) his room's edge: in first.
    if (_offEdge && show != PipShow.awake) return false;
    final fresh = activity == PipActivity.spawning && _t == 0;
    if (fresh && show != PipShow.awake) _stand();
    switch (show) {
      case PipShow.awake:
        if (activity == PipActivity.adventuring ||
            activity == PipActivity.questing) {
          return true;
        }
        return switch (activity) {
          PipActivity.asleep => play(PipAnimation.wakeUp),
          PipActivity.off => play(PipAnimation.powerOn),
          _ => !_busy,
        };
      case PipShow.asleep:
        if (fresh) {
          _start(PipActivity.asleep);
          return true;
        }
        // Round 141: at his work still (walking off it): asleep after.
        if (activity == PipActivity.questing) return false;
        if (activity == PipActivity.asleep) return true;
        return play(PipAnimation.fallAsleep);
      case PipShow.fallAsleep:
        if (activity == PipActivity.asleep) return true;
        if (activity == PipActivity.questing) return false;
        return play(PipAnimation.fallAsleep);
      case PipShow.wakeUp:
        if (fresh) _start(PipActivity.asleep);
        if (activity != PipActivity.asleep) return !_busy;
        return play(PipAnimation.wakeUp);
      case PipShow.off:
        if (activity == PipActivity.off) return true;
        if (_busy &&
            activity != PipActivity.asleep &&
            activity != PipActivity.questing) {
          return false;
        }
        _fallRight = x + width + height <= roomWidth;
        _start(PipActivity.off);
        return true;
      case PipShow.powerOff:
        if (activity == PipActivity.off ||
            activity == PipActivity.poweringOff) {
          return true;
        }
        return play(PipAnimation.powerOff);
    }
  }

  /// In the middle of something that nothing interrupts.
  bool get _busy =>
      !mayStart(activity, PipAnimation.walk) &&
      activity != PipActivity.asleep &&
      activity != PipActivity.off &&
      !reminding;

  /// Reminding of his medicine (Round 55): he keeps at it, but it's no
  /// reason to put off what his life says (asleep, off).
  bool get reminding =>
      activity == PipActivity.showing && _shownNow == PipScreen.pill;

  /// Falling asleep's parts: eyes closing, then settling down.
  static const eyesCloseAt = 0.8;
  static const settleAt = 1.4;
  static const asleepEnd = 1.9;

  /// Waking's parts (Round 53: slower; Round 57: slower still, with a
  /// yawn): eyes shut a while, legs out (eyes still shut), a big yawn as
  /// he stretches up, a blink, eyes open, then up with a hop.
  static const legsOutAt = 1.2;
  static const yawnAt = 1.6;
  static const yawnEnd = 3.0;
  static const eyesOpenAt = 3.3;
  static const wakeHopStart = 3.6;
  static const wakeHopEnd = 4.3;

  /// Round 77: stirring's parts: still a moment, one eye open, shut again,
  /// then waking.
  static const stirOpenAt = 0.6;
  static const stirShutAt = 2.0;
  static const stirEnd = 2.4;

  /// Turning off: the screen flickers out, he falls over, bounces.
  static const flickerEnd = 0.9;
  static const fallEnd = 1.3;
  static const offEnd = 1.6;

  /// Coming back on: the battery flies to him, the screen flickers on, he
  /// gets up and hops.
  static const flyEnd = 0.7;
  static const flickerOnEnd = 1.2;
  static const riseUpEnd = 1.6;
  static const onEnd = 1.9;

  // How he looks this moment: over on his side, his face, the z's.

  /// How far over he is (0 standing, 1 lying on his side).
  double get tilt {
    switch (activity) {
      case PipActivity.off:
        return 1;
      case PipActivity.poweringOff:
        if (_t < flickerEnd) return 0;
        final p = ((_t - flickerEnd) / (fallEnd - flickerEnd)).clamp(0.0, 1.0);
        return p * p; // falling faster as he goes
      case PipActivity.poweringOn:
        if (_t < flickerOnEnd) return 1;
        final p =
            ((_t - flickerOnEnd) / (riseUpEnd - flickerOnEnd)).clamp(0.0, 1.0);
        return 1 - p;
      default:
        return 0;
    }
  }

  /// His face now.
  PipFace get face {
    PipFace byEnergy() => switch (drowsy ? 1 : segments) {
          3 => PipFace.normal,
          2 => PipFace.tired,
          _ => PipFace.veryTired,
        };
    // A flicker: on and off a few times, the gaps longer each time.
    bool flickerOn(double p) => (math.sqrt(p) * 7).floor().isEven;
    switch (activity) {
      case PipActivity.asleep:
        return PipFace.asleep;
      case PipActivity.riding when _busAsleep:
        return PipFace.asleep;
      case PipActivity.angry:
        return PipFace.angry;
      case PipActivity.fallingAsleep:
        return _t < eyesCloseAt ? PipFace.tired : PipFace.asleep;
      case PipActivity.stirring:
        return _t >= stirOpenAt && _t < stirShutAt
            ? PipFace.peek
            : PipFace.asleep;
      case PipActivity.wakingUp:
        if (_t < legsOutAt) return PipFace.asleep;
        if (_t >= yawnAt && _t < yawnEnd) return PipFace.yawn;
        return byEnergy();
      case PipActivity.off:
        return PipFace.off;
      case PipActivity.poweringOff:
        if (_t >= flickerEnd) return PipFace.off;
        return flickerOn(_t / flickerEnd) ? PipFace.veryTired : PipFace.off;
      case PipActivity.poweringOn:
        if (_t < flyEnd) return PipFace.off;
        if (_t >= flickerOnEnd) return byEnergy();
        return flickerOn(1 - (_t - flyEnd) / (flickerOnEnd - flyEnd))
            ? byEnergy()
            : PipFace.off;
      default:
        return byEnergy();
    }
  }

  /// The little z's rising while he sleeps: each (x from his middle, y
  /// above his head, how faded 0–1), in room pixels.
  List<(double, double, double)> get zs {
    if (activity != PipActivity.asleep &&
        !(activity == PipActivity.riding && _busAsleep && bus!.inside)) {
      return const [];
    }
    return [
      for (var i = 0; i < 3; i++)
        if (((_t / 2.4 + i / 3) % 1) case final p)
          (4 + 5 * p + i, 2 + 12 * p, p),
    ];
  }

  // His egg (Round 34): taps, hatching.

  /// A tap on the egg: one more crack. True when it's the one that hatches
  /// him (the hatching starts).
  bool tapEgg() {
    if (activity != PipActivity.egg) return false;
    taps++;
    if (taps < hatchTaps) return false;
    activity = PipActivity.hatching;
    _t = 0;
    _eggX = x;
    // He jumps out to the left (the top flies off to the right).
    facingRight = false;
    return true;
  }

  /// Where his egg was (its left edge as his would be), while hatching.
  double _eggX = 0;
  double get eggX => activity == PipActivity.hatching ? _eggX : x;

  /// How far to the left of his egg he lands, in pixels.
  static const hatchJump = 14.0;

  /// While hatching: how far the egg's top has flown (0 → 1), and how
  /// faded the shell is (0: there, 1: gone).
  double get capFlight =>
      activity == PipActivity.hatching ? (_t / jumpEnd).clamp(0.0, 1.0) : 0;
  double get shellFade => activity == PipActivity.hatching
      ? ((_t - hatchLandEnd) / (fadeEnd - hatchLandEnd)).clamp(0.0, 1.0)
      : 0;

  /// Whether he shows yet while hatching (from the pop on).
  bool get visible =>
      activity != PipActivity.egg &&
      !(activity == PipActivity.hatching && _t < popEnd);

  // How far he goes: his room, or (Round 128) his house's floor.

  /// How far left and right he goes: his room, or (Round 128) his
  /// house's floor between its walls.
  double get _minX => atHome ? homeLeft : 0;
  double get _maxX =>
      atHome ? homeRight - width : math.max(0, roomWidth - width).toDouble();

  /// His house's floor, inside its walls (the house area's x, from its
  /// left, as his room's at home: [questCamera] is 0 then).
  static const homeLeft = PipHouse.left + 6.0;
  static const homeRight = PipHouse.right - 6.0;

  // Each step: the time gone by, whatever he's doing carried on.

  /// Moves on by [dt] seconds.
  void step(double dt) {
    _tickOutRun(dt);
    _stepTrees(dt);
    _t += dt;
    _stepStation(dt);
    _stepDrone(dt);
    switch (activity) {
      case PipActivity.egg:
        break;
      case PipActivity.hatching:
        // Round 98: a buzz as he lands from his jump out.
        _buzzOn(hatchLandEnd, dt, PipBuzz.light);
        if (_t >= popEnd) {
          final p = ((_t - popEnd) / (jumpEnd - popEnd)).clamp(0.0, 1.0);
          x = _eggX - hatchJump * p;
        }
        // Landed: he turns to look at his shell.
        if (_t >= hatchLandEnd) facingRight = true;
        if (_t >= fadeEnd) _stand();
      case PipActivity.spawning:
        _buzzOn(crackEnd, dt, PipBuzz.light); // the ground cracks
        _buzzOn(hopEnd, dt, PipBuzz.light); // down from his hop
        if (_t >= landEnd) _stand();
      case PipActivity.standing:
        _blinkIn -= dt;
        if (_blinking > 0) _blinking -= dt;
        if (_blinkIn <= 0) {
          _blinking = 0.15;
          _blinkIn = 2 + random.nextDouble() * 3;
        }
        if (_turnAt != null && _t >= _turnAt!) {
          facingRight = !facingRight;
          _turnAt = null;
        }
        if (_t >= _standFor && !_maybeEvent()) _walk();
      case PipActivity.walking:
        final distance = pace * dt;
        if ((_target - x).abs() <= distance) {
          x = _target;
          _stand();
          _arrive();
        } else {
          x += _target > x ? distance : -distance;
        }
      case PipActivity.fallingAsleep:
        _buzzOn(settleAt, dt, PipBuzz.light); // settling down
        if (_t >= asleepEnd) {
          final demo = _demo;
          _start(PipActivity.asleep);
          _demo = demo;
        }
      case PipActivity.asleep:
        if (_demo && _t >= demoHold) {
          final stir = _demoStir;
          _demoStir = false;
          play(stir ? PipAnimation.nightWake : PipAnimation.wakeUp);
        }
      case PipActivity.stirring:
        if (_t >= stirEnd) _start(PipActivity.wakingUp);
      case PipActivity.wakingUp:
        _buzzOn(wakeHopEnd, dt, PipBuzz.light); // down from his hop
        if (_t >= wakeHopEnd) _stand();
      case PipActivity.poweringOff:
        _buzzOn(fallEnd, dt, PipBuzz.medium); // falling over
        if (_t >= offEnd) {
          final demo = _demo;
          _start(PipActivity.off);
          _demo = demo;
        }
      case PipActivity.off:
        if (_demo && _t >= demoHold) {
          _dropBattery();
          play(PipAnimation.powerOn);
        }
      case PipActivity.poweringOn:
        _buzzOn(flyEnd, dt, PipBuzz.medium); // the battery reaches him
        _buzzOn(onEnd, dt, PipBuzz.light); // down from his hop
        if (_t >= flyEnd) _dropBattery();
        if (_t >= onEnd) {
          // Round 134: back on at his work: at it again.
          downAtWork ? _backToWork() : _stand();
        }
      case PipActivity.fetching:
        _stepFetching(dt);
      case PipActivity.toStation:
        final distance = hurry * dt;
        if ((_target - x).abs() <= distance) {
          x = _target;
          facingRight = stationOnRight;
          _start(PipActivity.plugging);
        } else {
          x += _target > x ? distance : -distance;
        }
      case PipActivity.plugging:
        _buzzOn(grabEnd, dt, PipBuzz.light); // the cable taken
        _buzzOn(pushEnd, dt, PipBuzz.medium); // plugged in
        if (_t >= plugEnd) {
          _start(PipActivity.charging);
          _nextScreen();
        }
      case PipActivity.charging:
        _stepCharging(dt);
      case PipActivity.unplugging:
        _buzzOn(pullEnd, dt, PipBuzz.medium); // pulled out
        if (_t >= unplugEnd) {
          _stand();
          // The phone unplugged: the station goes too.
          if (!_wantsStation) _sinkStation();
        }
      case PipActivity.falling:
        if (!_landed && _t >= _fallTime) {
          _landed = true;
          _buzzes.add(PipBuzz.medium);
        }
        if (_t >= _fallTime + landHold) _stand();
      case PipActivity.thrown:
        final p = (_t / throwTime).clamp(0.0, 1.0);
        x = _throwFrom + (_target - _throwFrom) * p;
        if (!_landed && _t >= throwTime) {
          _landed = true;
          _buzzes.add(PipBuzz.heavy);
        }
        if (_t >= throwTime + landHold) _start(PipActivity.angry);
      case PipActivity.angry:
        if (_t >= angryTime) _stand();
      case PipActivity.bugHunt:
        _stepBugs(dt);
      case PipActivity.showing:
        _stepShowing(dt);
      case PipActivity.flower:
        _stepFlower(dt);
      case PipActivity.butterfly:
        _stepButterfly(dt);
      case PipActivity.ball:
        _stepBall(dt);
      case PipActivity.stargazing:
        // He turns to follow it across.
        if (shootingStar case (final sx, _, _)) {
          facingRight = sx > x + width / 2;
        }
        if (_t >= starTime + 1.2) _stand();
      case PipActivity.dancing:
        // Turning on each beat (Round 98: a buzz on each).
        final beat = (_t / beatTime).floor();
        if (beat > ((_t - dt) / beatTime).floor() && _t < danceTime) {
          _buzzes.add(PipBuzz.light);
        }
        facingRight = beat.isEven;
        if (_t >= danceTime) _stand();
      case PipActivity.eating:
        // Round 98: a buzz on each bite.
        for (final b in bites) {
          _buzzOn(b + biteTime / 2, dt, PipBuzz.light);
        }
        if (_t >= eatTime) _stand();
      case PipActivity.adventuring:
        _stepRun(dt);
      case PipActivity.riding:
        _stepBus(dt);
      case PipActivity.questing:
        _stepQuest(dt);
      case PipActivity.sheltering:
        break;
      case PipActivity.weatherEvent:
        _stepWeatherEvent(dt);
      case PipActivity.lookingUp:
        if (_t >= PipBrainWeather._lookUpTime) _stand();
    }
    _stepWeather(dt);
    _stepLevelFlash(dt);
    if (snowing) snowClock += dt;
    sceneClock += dt;
    // Round 55: his medicine before charging (or anything else).
    _stepMedicine();
    if (activity == PipActivity.standing) _maybeCharge();
    // Thrown in, he's still coming in from beyond the edge. Round 141:
    // nor at his work's places (they put him where he is: walking off an
    // edge, or in from one, not stopped at it).
    if (activity != PipActivity.thrown && !_offEdge && !_placed) {
      x = x.clamp(_minX, _maxX);
    }
  }

  // Standing about and walking; how he looks each moment: his frame,
  // how high, how stretched (Round 26–98).

  /// Snowing: a ski day, or a ski preview.
  bool get snowing => snowy || _skiPreview;

  /// Rain, drizzle, snow or a storm out (Round 128).
  bool get wetOut =>
      snowing ||
      switch (weather) {
        WeatherKind.drizzle ||
        WeatherKind.rain ||
        WeatherKind.snow ||
        WeatherKind.storm =>
          true,
        _ => false,
      };

  /// Whether he can set off now: up and about, or just made (opened
  /// while he's out: he's simply there, out).
  bool get _canGoOut =>
      activity == PipActivity.standing ||
      activity == PipActivity.walking ||
      activity == PipActivity.showing ||
      freshSpawn;

  void _stand() {
    _holdIn();
    activity = PipActivity.standing;
    _t = 0;
    _standFor = 1.5 + random.nextDouble() * 3.5;
    // Now and then he looks round the other way for a bit.
    _turnAt = random.nextDouble() < 0.4
        ? _standFor * (0.3 + 0.4 * random.nextDouble())
        : null;
  }

  void _walk() {
    _forgetVisit();
    // Somewhere at least a few steps away, inside the room.
    final max = _maxX;
    if (max - _minX < 8) {
      _stand();
      return;
    }
    // Round 44: not into his station, if it's up.
    final (low, high) = _clearOfStation(_minX, max);
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
        PipActivity.hatching => _t < jumpEnd
            ? PipFrame.oh
            : (_t < hatchLandEnd ? PipFrame.tuck : PipFrame.idle),
        PipActivity.spawning => _t < hopEnd ? PipFrame.oh : PipFrame.tuck,
        PipActivity.standing => _blinking > 0 ? PipFrame.blink : PipFrame.idle,
        PipActivity.walking => _stepFrame,
        PipActivity.fallingAsleep =>
          _t < settleAt ? PipFrame.idle : PipFrame.tuck,
        PipActivity.asleep || PipActivity.stirring => PipFrame.tuck,
        PipActivity.wakingUp => _t < legsOutAt
            ? PipFrame.tuck
            // Eyes still shut, before the yawn and after it.
            : _t < yawnAt || (_t >= yawnEnd && _t < eyesOpenAt)
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
        PipActivity.flower => _flowerStage == 1 ? _stepFrame : PipFrame.idle,
        PipActivity.butterfly => _butterflyClose ? PipFrame.oh : PipFrame.idle,
        PipActivity.stargazing => PipFrame.oh,
        PipActivity.dancing =>
          (_t / beatTime * 2).floor().isEven ? PipFrame.step1 : PipFrame.step3,
        PipActivity.ball => switch (_ballStage) {
            1 => _stepFrame,
            2 => PipFrame.step1,
            _ => PipFrame.idle,
          },
        // Round 53: his mouth open for each bite.
        PipActivity.eating => bites.any((b) => _t >= b && _t < b + biteTime)
            ? PipFrame.oh
            : PipFrame.idle,
        PipActivity.adventuring => _runFrame,
        PipActivity.riding => bus?.walking == true
            ? const [
                PipFrame.step1,
                PipFrame.step2,
                PipFrame.step3,
                PipFrame.step4,
              ][(_t / stepTime).floor() % 4]
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
      ][(_t / (_hurrying ? stepTime * speed / hurry : stepTime)).floor() % 4];

  bool get _hurrying =>
      activity == PipActivity.toStation ||
      activity == PipActivity.fetching ||
      activity == PipActivity.bugHunt;

  bool get _atTarget => (_target - x).abs() < 0.01;

  /// How far below the ground he still is (0: fully up), in pixels.
  double get sunk {
    if (activity != PipActivity.spawning) return 0;
    if (_t < crackEnd) return height.toDouble();
    if (_t < riseEnd) {
      final p = (_t - crackEnd) / (riseEnd - crackEnd);
      return height * (1 - _easeOut(p));
    }
    return 0;
  }

  /// How high above the ground (a hop, or a step's bob), in pixels.
  /// Round 134: down at his work (off, back on), where he fell: up on
  /// the floor or the scaffold.
  double get lift {
    final own = _ownLift;
    if (_downLift case final down?) return down + own;
    return own;
  }

  double get _ownLift {
    // Round 67: in his seat on the bus, his feet hidden.
    if (bus case final bus?) {
      return bus.inside ? PipBus.seatLift : 0;
    }
    // Round 63: out, as his run says (a knock, his seat), and a bob.
    if (run case final run?) {
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
      return 0.5 * gravity * left * left;
    }
    if (activity == PipActivity.thrown && _t < throwTime) {
      return _throwHigh * math.sin(math.pi * _t / throwTime);
    }
    if (activity == PipActivity.dancing) {
      // A hop on every beat.
      return 3 * math.sin(math.pi * ((_t / beatTime) % 1)).abs();
    }
    if (activity == PipActivity.showing && _shownNow.hops && _t < showHop) {
      return 3 * math.sin(math.pi * _t / showHop); // a hop: something came
    }
    // Round 53: the pill twice (a second hop).
    if (activity == PipActivity.showing &&
        _shownNow == PipScreen.pill &&
        _t >= 0.5 &&
        _t < 0.9) {
      return 3 * math.sin(math.pi * (_t - 0.5) / 0.4);
    }
    if (activity == PipActivity.hatching && _t >= popEnd && _t < jumpEnd) {
      final p = (_t - popEnd) / (jumpEnd - popEnd);
      // A little higher than the spawn's hop, still in the room.
      return 7 * math.sin(math.pi * p);
    }
    if (activity == PipActivity.spawning && _t >= riseEnd && _t < hopEnd) {
      final p = (_t - riseEnd) / (hopEnd - riseEnd);
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
        return hop(wakeHopStart, wakeHopEnd, 3);
      case PipActivity.poweringOn:
        return hop(riseUpEnd, onEnd, 3);
      case PipActivity.fetching when _picking != null:
        final p = _picking!;
        if (p < shakeEnd || p >= pickEnd) return 0;
        // Round 97: after his shake, a hop.
        return 4 * math.sin(math.pi * (p - shakeEnd) / (pickEnd - shakeEnd));
      default:
    }
    if (frame == PipFrame.step1 || frame == PipFrame.step3) return 1;
    return 0;
  }

  /// Squash and stretch: (width, height) scale.
  (double, double) get stretch {
    // Round 53: waking, a stretch up; picking something up, a crouch (his
    // feet stay on the ground, his legs don't float).
    if (activity == PipActivity.wakingUp && _t >= yawnAt && _t < yawnEnd) {
      final s = 0.12 * math.sin(math.pi * (_t - yawnAt) / (yawnEnd - yawnAt));
      return (1 - s / 2, 1 + s);
    }
    // Round 97: a happy little shake once the new battery's in.
    if (activity == PipActivity.fetching &&
        _picking != null &&
        _picking! >= handOut &&
        _picking! < shakeEnd) {
      final s = 0.07 *
          math.sin(math.pi * 8 * (_picking! - handOut) / (shakeEnd - handOut));
      return (1 + s, 1 - s);
    }
    final crouch = switch (activity) {
      PipActivity.adventuring => run?.crouch,
      PipActivity.flower when _flowerStage == 2 => _t / flowerPick,
      // Round 54: down for the new battery, and up again with it.
      PipActivity.fetching
          when _picking != null &&
              _picking! >= throwAt &&
              _picking! < atSlotAgain =>
        (_picking! - throwAt) / (atSlotAgain - throwAt),
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
      PipActivity.thrown => _t - throwTime,
      _ => null,
    };
    if (landed != null) {
      if (landed < 0) {
        return activity == PipActivity.falling ? (0.9, 1.15) : (1, 1);
      }
      if (landed < landHold) {
        final s = 0.28 * math.sin(math.pi * landed / landHold);
        return (1 + s / 2, 1 - s);
      }
      return (1, 1);
    }
    if (activity == PipActivity.hatching) {
      if (_t >= popEnd && _t < jumpEnd) {
        final p = (_t - popEnd) / (jumpEnd - popEnd);
        final s = 0.18 * math.cos(math.pi * p).clamp(0, 1);
        return (1 - s / 2, 1 + s);
      }
      if (_t >= jumpEnd && _t < hatchLandEnd) {
        final p = (_t - jumpEnd) / (hatchLandEnd - jumpEnd);
        final s = 0.2 * math.sin(math.pi * p);
        return (1 + s / 2, 1 - s);
      }
      return (1, 1);
    }
    if (activity != PipActivity.spawning) return (1, 1);
    if (_t >= riseEnd && _t < hopEnd) {
      // Stretched going up, back to size at the top.
      final p = (_t - riseEnd) / (hopEnd - riseEnd);
      final s = 0.18 * math.cos(math.pi * p).clamp(0, 1);
      return (1 - s / 2, 1 + s);
    }
    if (_t >= hopEnd && _t < landEnd) {
      // Squashed on landing, springing back.
      final p = (_t - hopEnd) / (landEnd - hopEnd);
      final s = 0.2 * math.sin(math.pi * p);
      return (1 + s / 2, 1 - s);
    }
    return (1, 1);
  }

  /// The cracked ground's dirt, flying up while he comes out: 0 none,
  /// then 0 → 1 over the crack and the rise.
  double get dirt {
    if (activity != PipActivity.spawning || _t >= riseEnd) return 0;
    return _t / riseEnd;
  }

  // Round 44: his charging station's measures and timings (what it does:
  // `pip_brain_station.dart`).

  /// The station's size, in pixels; how far from it he stands to plug
  /// in; how long it takes to rise out of the ground (or sink back).
  static const stationWidth = 14;
  static const stationHeight = 27;
  static const stationGap = 6;
  static const stationRise = 0.9;

  /// Plugging in, in seconds: his hands pop in, the near one flies to
  /// the hook, takes the plug, carries it to his side, pushes it in, and
  /// the hands pop away.
  static const mittsInEnd = 0.25;
  static const toHookEnd = 0.75;
  static const grabEnd = 0.95;
  static const carryEnd = 1.55;
  static const pushEnd = 1.75;
  static const plugEnd = 2.0;

  /// Unplugging: the hands pop in, the near one takes the plug out,
  /// carries it back to the hook, and they pop away.
  static const toPortEnd = 0.6;
  static const pullEnd = 0.8;
  static const backEnd = 1.4;
  static const hangEnd = 1.6;
  static const unplugEnd = 1.85;

  /// Played from Pip Home's list: how long he charges before unplugging.
  static const demoChargeHold = 6.0;

  /// Round 58: at his station, watched, a segment this often (the user:
  /// Round 88 15 s, it was 30; Round 91 8 s).
  static const chargeEvery = 8.0;

  /// The drone's size, in pixels.
  static const droneWidth = 10;
  static const droneHeight = 5;

  /// Its trip's parts, in seconds: up out of the station's top, over to
  /// him, beaming down on him, back over the station, down into it.
  static const droneRise = 0.5;
  static const droneOut = 1.2;
  static const droneBeam = 1.6;
  static const droneBack = 1.2;
  static const droneSink = 0.5;

  /// How high above the ground it hovers over him lying there (its
  /// bottom), and where its beam ends (his side).
  static const droneHover = 30.0;
  static const beamTo = 17.0;
  static const portUp = 9.0;
  static const hookUp = 5.0;
  static const socketUp = 8.0;

  static (double, double) _lerp(
          (double, double) a, (double, double) b, double p) =>
      (a.$1 + (b.$1 - a.$1) * p, a.$2 + (b.$2 - a.$2) * p);

  static double _ease(double p) {
    final c = p.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  /// Bedtime (his life says asleep): he doesn't go and plug in.
  bool _bedtime = false;

  // Round 52: entrances.

  /// How many rows of sky he has above the ground (the room says), to
  /// drop in from above it.
  int skyRows = 40;

  /// Falling: how fast (pixels a second squared); how long it takes from
  /// above the room ([_fallTime], from [skyRows]); after landing, how
  /// long the squash and the dust last.
  static const gravity = 160.0;
  double _fallTime = 0.6;
  static const landHold = 0.45;

  /// Thrown in: how long in the air, how high the arc, where from.
  static const throwTime = 0.95;
  double _throwHigh = 14;
  double _throwFrom = 0;

  /// Angry after a throw, in seconds.
  static const angryTime = 2.6;

  /// Comes into his field by [entrance] now (from wherever he is).
  void enter(PipEntrance entrance) {
    _landed = false;
    // Round 128: in his house, up through its floor (not through its roof
    // or walls).
    if (atHome) entrance = PipEntrance.ground;
    switch (entrance) {
      case PipEntrance.ground:
        _start(PipActivity.spawning);
      case PipEntrance.sky:
        _fallTime = math.sqrt(2 * (skyRows + height) / gravity);
        _start(PipActivity.falling);
      case PipEntrance.side:
        // From beyond the left edge (the menu swings in from the left),
        // landing a third of the way in.
        _throwFrom = -width - 4.0;
        _target = (roomWidth * 0.3).clamp(_minX, _maxX).toDouble();
        _throwHigh = math.min(18, math.max(4, skyRows - height - 6)).toDouble();
        x = _throwFrom;
        facingRight = true;
        _start(PipActivity.thrown);
    }
  }

  /// Moments to feel (Round 53: a kick, a strike, a landing), taken by
  /// his room to buzz the phone.
  final List<PipBuzz> _buzzes = [];

  /// Round 98: whether [mark] was passed in this step of [dt] (with
  /// [now] after it).
  static bool _passed(double mark, double now, double dt) =>
      now >= mark && now - dt < mark;

  /// A [buzz] as his animation's clock passes [mark] (Round 98).
  void _buzzOn(double mark, double dt, PipBuzz buzz) {
    if (_passed(mark, _t, dt)) _buzzes.add(buzz);
  }

  List<PipBuzz> takeBuzzes() {
    final taken = [..._buzzes];
    _buzzes.clear();
    return taken;
  }

  bool _landed = false;

  /// Seconds the app was away before he comes in again (Round 52: back
  /// after a while, by one of his entrances).
  static const awayFor = Duration(minutes: 10);

  /// When his room was last left (the menu closed), for [awayFor].
  DateTime? leftAt;

  /// Just made, about to come out of the ground (nothing seen yet).
  /// (The ground only cracks after a moment: a first frame or two may
  /// have gone by.)
  bool get freshSpawn => activity == PipActivity.spawning && _t < crackEnd / 2;

  /// Turned round mid-air, thrown in: radians (one whole tumble).
  double get spin => activity == PipActivity.thrown && _t < throwTime
      ? 2 * math.pi * _ease(_t / throwTime)
      : activity == PipActivity.adventuring
          ? run?.spin ?? 0
          : 0;

  /// Dust puffing up where he landed (from the sky or a throw): 0 → 1,
  /// or null.
  double? get landingDust {
    final landed = switch (activity) {
      PipActivity.falling => _t - _fallTime,
      PipActivity.thrown => _t - throwTime,
      _ => -1.0,
    };
    if (landed < 0 || landed >= landHold) return null;
    return landed / landHold;
  }

  /// Angry (after a throw): his face says so, a fist shakes beside his
  /// head, cross words (#!) above it.
  bool get angry => activity == PipActivity.angry;

  /// Seconds into what he's doing (for things that flicker with it).
  double get zsClock => _t;

  /// The fist's top, above the ground, and how far it shakes up.
  static const fistUp = height - 3.0;
  static const fistShake = 2.0;

  /// The shaking fist: (x, height above the ground), or null.
  (double, double)? get fist {
    if (!angry) return null;
    // Round 79 (it went too far from his body): beside his
    // head, a pixel off his casing as his other hands, shaken up and
    // down (it was over his head, shaken out sideways).
    final shake = (_t * 8).floor().isEven ? 0.0 : fistShake;
    final side = handBeside(right: facingRight) - 1;
    return (side, fistUp + shake);
  }

  // Round 52: his field's events' chances and timings (`pip_brain_events.dart`).

  /// The chance, each time he'd walk off, that something happens instead.
  static const eventChance = 0.09;
  static const starTime = 1.1;

  /// A little dance: its length and beat, in seconds.
  static const danceTime = 4.0;
  static const beatTime = 0.5;
  static const bugWidth = 8;
  static const bugSpeed = 9.0;
  static const swordIn = 0.35;
  static const swingTime = 0.3;
  static const poofTime = 0.35;

  /// How far his sword reaches past his side.
  static const reach = 7.0;
  static const sproutTime = 1.2;
  static const flowerPick = 0.45;
  static const flowerHold = 3.0;
  static const flowerFade = 0.6;
  static const butterflySpeed = 11.0;
  static const ballSize = 4;
  static const kickTime = 0.25;

  /// Round 98: how fast the ball must come down for its bounce to buzz.
  static const ballBuzzSpeed = 15.0;

  // Round 53: a meal's and his screen's timings (`pip_brain_looks.dart`).

  /// How long he eats; when each bite is (seconds in).
  static const eatTime = 6.5;
  static const plateIn = 0.4;
  static const bites = [1.4, 2.6, 3.8];
  static const biteTime = 0.35;
  static const eatenAt = 4.6;
  static const plateWidth = 10;

  /// The plate's height held (below his mouth; up to it for a bite).
  static const plateRest = 3.0;

  /// How long after a recipe was read he eats, when seen.
  static const eatsWithin = Duration(hours: 1);

  static final _notifyScreens = [
    for (final s in PipScreen.values)
      if (s.notification) s,
  ];

  /// How long his hop is when something comes (it lands with a buzz).
  static const showHop = 0.4;

  // Round 63–76: his days out's timings (`pip_brain_outings.dart`).

  static const previewEventAt = 6.0;
  static const previewLength = 17.0;
  static const busPreviewRide = 4.0;

  /// How far into his break counts as just starting (about a minute and
  /// a half of the half hour).
  static const breakJustStarted = 0.05;

  /// Round 132: away this long, his run is taken up afresh ([freshOut]).
  static const outStale = Duration(seconds: 10);

  /// The most the trees hurry or hold back to keep to [outRun].
  static const treeCatchUp = 0.5;

  /// How far off before they're simply put there.
  static const treeJump = 20.0;
  static const levelFlashTime = 1.8;

  static double _easeOut(double p) => 1 - math.pow(1 - p, 3).toDouble();

  // Round 128–134: his places' sets of activities (`pip_brain_places.dart`).

  static const _downActs = {
    PipActivity.poweringOff,
    PipActivity.off,
    PipActivity.poweringOn,
  };

  static const _awayFromHome = {
    PipActivity.adventuring,
    PipActivity.riding,
    PipActivity.questing,
  };

  /// What doesn't happen in his house (his field's things); Pip Home's
  /// list says so.
  static const fieldOnly = {
    PipAnimation.fromSky,
    PipAnimation.fromSide,
    PipAnimation.bugs,
    PipAnimation.flower,
    PipAnimation.butterfly,
    PipAnimation.ball,
    PipAnimation.shootingStar,
    PipAnimation.puddle,
    PipAnimation.twirl,
    PipAnimation.handOut,
    PipAnimation.flakes,
    PipAnimation.snowman,
    PipAnimation.snowball,
    PipAnimation.lost,
  };

  // His field, as his room says (each check): dusk or night, the sky,
  // a ski day; and the clocks for what moves in it.

  /// Dusk or night in his sky (the room says): shooting stars then.
  bool dark = false;

  /// Round 70 (the room says): a grey sky (no shooting stars), and rain,
  /// snow or winter (no flowers or butterflies).
  bool overcast = false;
  bool bleak = false;

  /// Round 70: seconds going by for his field's moving things (trees
  /// swaying, rain, leaves, lights), always.
  double sceneClock = 0;

  /// Round 67: a ski day (his room says): his day out is skiing, it
  /// snows, his gear stands in a snowbank, a ski beanie.
  bool skiing = false;
  bool snowy = false;

  /// Seconds his snow has been falling (Round 67), for the flakes.
  double snowClock = 0;
}
