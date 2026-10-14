import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:the_app/core/pip_energy.dart';

/// What Pip is doing (Round 26).
enum PipActivity {
  /// Not hatched yet (Round 34): an egg in the middle of the room, cracked
  /// a little more by taps.
  egg,

  /// Out of the egg: its top pops off, he jumps out and lands, the shell
  /// fades.
  hatching,

  /// The first time the menu opens: the ground cracks, he comes up out
  /// of it, hops and lands.
  spawning,

  /// Standing about (blinking now and then).
  standing,

  /// Walking to a spot.
  walking,

  /// Round 37: eyes closing, he settles down to sleep.
  fallingAsleep,

  /// Asleep, settled down, little z's rising.
  asleep,

  /// Waking: eyes open, he gets up with a little hop.
  wakingUp,

  /// Out of energy: his screen flickers out and he falls over.
  poweringOff,

  /// Lying there, his screen dark.
  off,

  /// A battery flies to him (if one was given), his screen comes back on
  /// and he gets up.
  poweringOn,

  /// A battery dropped in his room: he walks over and picks it up.
  fetching,

  /// Round 44: the phone plugged in, he hurries to his charging station.
  toStation,

  /// At the station: his hands pop in, he takes the plug off its hook,
  /// plugs it into his side, and the hands pop away.
  plugging,

  /// Plugged in, his antenna lit, his screen changing now and then.
  charging,

  /// Unplugging: the same as plugging in, backwards.
  unplugging,
}

/// What his screen shows while he charges (Round 44), now and then
/// another, at random.
enum ChargeScreen {
  happy,
  battery,
  static,
  bolt,
  content,
  sparks,
  humming,
  blinking,
}

/// How his face looks (Round 37): by his energy, asleep, or off.
enum PipFace { normal, tired, veryTired, asleep, off }

/// His animations that can be played on request (Round 35: Pip Home's
/// Animations): each one he has, by name.
enum PipAnimation {
  spawn('Out of the ground'),
  hatch('Out of his egg'),
  walk('A walk'),
  blink('A blink'),
  turn('A look round'),
  // Round 37: in the list they come back on their own (asleep, then up
  // again; off, then on again).
  fallAsleep('Falling asleep'),
  powerOff('Running out'),
  wakeUp('Waking up', listed: false),
  powerOn('Back on', listed: false),
  fetch('Picking up a battery', listed: false),
  // Round 44: the station rises, he plugs in, charges a while, unplugs.
  charge('Charging');

  final String label;

  /// In Pip Home's Animations list (the others only happen for real).
  final bool listed;

  const PipAnimation(this.label, {this.listed = true});
}

/// What may start while he's doing something (Round 35): the one table
/// that keeps things from clashing. Mid-entrance (out of the ground or
/// his egg) nothing interrupts; an egg only hatches by its taps. New
/// activities and events (batteries, bugs...) get their row and column
/// here, and the table is tested whole.
///
/// Round 37: in the middle of falling asleep, waking, turning off or on,
/// or picking up a battery, nothing starts either. Asleep, he can only
/// wake (or run out); off, only come back on (a battery). Up and about,
/// anything but waking or coming back on.
///
/// Round 44: hurrying to his station, plugging in or out, or charging,
/// nothing starts (asleep at night, he first unplugs: [PipBrain.show]).
bool mayStart(PipActivity doing, PipAnimation next) => switch (doing) {
      PipActivity.egg ||
      PipActivity.hatching ||
      PipActivity.spawning ||
      PipActivity.fallingAsleep ||
      PipActivity.wakingUp ||
      PipActivity.poweringOff ||
      PipActivity.poweringOn ||
      PipActivity.fetching ||
      PipActivity.toStation ||
      PipActivity.plugging ||
      PipActivity.charging ||
      PipActivity.unplugging =>
        false,
      PipActivity.asleep =>
        next == PipAnimation.wakeUp || next == PipAnimation.powerOff,
      PipActivity.off => next == PipAnimation.powerOn,
      PipActivity.standing ||
      PipActivity.walking =>
        next != PipAnimation.wakeUp && next != PipAnimation.powerOn,
    };

/// Pip's frames, by name; drawn by `widgets/pip_room.dart`.
enum PipFrame { idle, blink, step1, step2, step3, step4, oh, tuck }

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
    x = first ? _maxX / 2 : x.clamp(0, _maxX);
  }

  /// Pip's size, in pixels (Round 27: 19 tall, his screen a row taller).
  static const width = 20;
  static const height = 19;

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

  /// Plays [animation] now, if [mayStart] lets it (false if not). A
  /// [demo] (Pip Home's list) of falling asleep or running out comes
  /// back on its own.
  bool play(PipAnimation animation, {bool demo = false}) {
    if (!mayStart(activity, animation)) return false;
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
      case PipAnimation.powerOff:
        _fallRight = x + width + height <= roomWidth;
        _start(PipActivity.poweringOff);
        _demo = demo;
      case PipAnimation.powerOn:
        _start(PipActivity.poweringOn);
        // No battery given (a demo): straight to the screen coming on.
        if (_battery == null) _t = flyEnd;
      case PipAnimation.fetch:
        return false; // only with a battery: [takeBattery]
      case PipAnimation.charge:
        // Only where there's room for the station. The phone plugged in
        // and him not at it (full, say): it plays all the same (Round 45).
        if (!_stationFits) return false;
        _demoCharge = 0;
        _setStation(true, animate: true);
    }
    return true;
  }

  void _start(PipActivity next) {
    activity = next;
    _t = 0;
    _demo = false;
  }

  /// Played from Pip Home's list: asleep or off, he comes back after a
  /// moment ([demoHold]).
  bool _demo = false;
  static const demoHold = 1.5;

  /// His energy's segments (0 to 3), from his life: his face, and how
  /// fast he walks.
  int segments = 3;

  /// Walking speed now: slower the less energy he has (Round 37).
  double get pace =>
      speed * switch (segments) { 3 => 1.0, 2 => 0.7, _ => 0.45 };

  /// Hurrying (Round 44: to a battery, or his station), whatever his
  /// energy: quicker than his best walk.
  static const hurry = speed * 1.6;

  /// The battery dropped in his room: its left edge, and how high above
  /// the ground it still is (it falls); null when there's none.
  double? _battery;
  double _batteryHeight = 0;

  /// Where the battery was dropped (a flying one starts there).
  double _batteryFrom = 0;

  /// Which way he fell (off): to the right, or the left (no room there).
  bool _fallRight = true;
  bool get fallRight => _fallRight;

  /// Seconds into picking it up, once he's there.
  double? _picking;

  /// Whether a battery dropped now would be taken (up and about, or
  /// off: it flies to him).
  bool get canTakeBattery =>
      mayStart(activity, PipAnimation.fetch) ||
      mayStart(activity, PipAnimation.powerOn);

  /// A battery dropped at [at] (room pixels from the left): he walks over
  /// and picks it up, or, off, it flies to him and he comes back on.
  bool takeBattery(double at) {
    if (!canTakeBattery) return false;
    final left = at.clamp(0, math.max(0, roomWidth - batteryWidth)).toDouble();
    _battery = left;
    _batteryFrom = left;
    _batteryHeight = dropHeight;
    if (activity == PipActivity.off) {
      _start(PipActivity.poweringOn);
      return true;
    }
    _start(PipActivity.fetching);
    _picking = null;
    // To stand over it, facing it.
    _target = (left + batteryWidth / 2 - width / 2).clamp(0, _maxX).toDouble();
    facingRight = _target >= x;
    return true;
  }

  /// The battery's size, how high it's dropped from, how fast it falls.
  static const batteryWidth = 4;
  static const batteryHeight = 7;
  static const dropHeight = 24.0;
  static const fallSpeed = 60.0;

  /// The battery to draw: its left edge and how high above the ground
  /// (flying to him while he's off), or null.
  (double, double)? get battery {
    final b = _battery;
    if (b == null) return null;
    if (activity == PipActivity.poweringOn) {
      if (_t >= flyEnd) return null;
      // An arc from where it was dropped to his middle.
      final p = _t / flyEnd;
      final to = _fallRight ? x + width + height / 2 : x - height / 2;
      return (
        _batteryFrom + (to - batteryWidth / 2 - _batteryFrom) * p,
        _batteryHeight * (1 - p) + 18 * math.sin(math.pi * p),
      );
    }
    return (b, _batteryHeight);
  }

  /// What to show, from his life (Round 37), made so: straight away if
  /// he's just appeared (instead of coming out of the ground), or with
  /// its animation. False if he's busy now (try again later).
  bool show(PipShow show) {
    // Round 44: plugged in at bedtime, he unplugs first (then sleeps;
    // the station stays, unused, while the phone's plugged in).
    _bedtime = show == PipShow.asleep || show == PipShow.fallAsleep;
    if (activity == PipActivity.charging && _bedtime) {
      _startUnplugging();
      return false;
    }
    final fresh = activity == PipActivity.spawning && _t == 0;
    if (fresh && show != PipShow.awake) _stand();
    switch (show) {
      case PipShow.awake:
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
        if (activity == PipActivity.asleep) return true;
        return play(PipAnimation.fallAsleep);
      case PipShow.fallAsleep:
        if (activity == PipActivity.asleep) return true;
        return play(PipAnimation.fallAsleep);
      case PipShow.wakeUp:
        if (fresh) _start(PipActivity.asleep);
        if (activity != PipActivity.asleep) return !_busy;
        return play(PipAnimation.wakeUp);
      case PipShow.off:
        if (activity == PipActivity.off) return true;
        if (_busy && activity != PipActivity.asleep) return false;
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
      activity != PipActivity.off;

  /// Falling asleep's parts: eyes closing, then settling down.
  static const eyesCloseAt = 0.8;
  static const settleAt = 1.4;
  static const asleepEnd = 1.9;

  /// Waking's parts: eyes open, then up with a hop.
  static const eyesOpenAt = 0.5;
  static const wakeHopEnd = 1.1;

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

  /// Picking the battery up: bent over it, then a hop of joy.
  static const pickAt = 0.35;
  static const pickEnd = 0.8;

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
    PipFace byEnergy() => switch (segments) {
          3 => PipFace.normal,
          2 => PipFace.tired,
          _ => PipFace.veryTired,
        };
    // A flicker: on and off a few times, the gaps longer each time.
    bool flickerOn(double p) => (math.sqrt(p) * 7).floor().isEven;
    switch (activity) {
      case PipActivity.asleep:
        return PipFace.asleep;
      case PipActivity.fallingAsleep:
        return _t < eyesCloseAt ? PipFace.tired : PipFace.asleep;
      case PipActivity.wakingUp:
        return _t < eyesOpenAt ? PipFace.asleep : byEnergy();
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
    if (activity != PipActivity.asleep) return const [];
    return [
      for (var i = 0; i < 3; i++)
        if (((_t / 2.4 + i / 3) % 1) case final p)
          (4 + 5 * p + i, 2 + 12 * p, p),
    ];
  }

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

  double get _maxX => math.max(0, roomWidth - width).toDouble();

  /// Moves on by [dt] seconds.
  void step(double dt) {
    _t += dt;
    _stepStation(dt);
    switch (activity) {
      case PipActivity.egg:
        break;
      case PipActivity.hatching:
        if (_t >= popEnd) {
          final p = ((_t - popEnd) / (jumpEnd - popEnd)).clamp(0.0, 1.0);
          x = _eggX - hatchJump * p;
        }
        // Landed: he turns to look at his shell.
        if (_t >= hatchLandEnd) facingRight = true;
        if (_t >= fadeEnd) _stand();
      case PipActivity.spawning:
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
        if (_t >= _standFor) _walk();
      case PipActivity.walking:
        final distance = pace * dt;
        if ((_target - x).abs() <= distance) {
          x = _target;
          _stand();
        } else {
          x += _target > x ? distance : -distance;
        }
      case PipActivity.fallingAsleep:
        if (_t >= asleepEnd) {
          final demo = _demo;
          _start(PipActivity.asleep);
          _demo = demo;
        }
      case PipActivity.asleep:
        if (_demo && _t >= demoHold) play(PipAnimation.wakeUp);
      case PipActivity.wakingUp:
        if (_t >= wakeHopEnd) _stand();
      case PipActivity.poweringOff:
        if (_t >= offEnd) {
          final demo = _demo;
          _start(PipActivity.off);
          _demo = demo;
        }
      case PipActivity.off:
        if (_demo && _t >= demoHold) {
          _battery = null;
          play(PipAnimation.powerOn);
        }
      case PipActivity.poweringOn:
        if (_t >= flyEnd) _battery = null;
        if (_t >= onEnd) _stand();
      case PipActivity.fetching:
        _batteryHeight = math.max(0, _batteryHeight - fallSpeed * dt);
        final picking = _picking;
        if (picking == null) {
          final distance = hurry * dt;
          if ((_target - x).abs() <= distance) {
            x = _target;
            if (_batteryHeight == 0) _picking = 0;
          } else {
            x += _target > x ? distance : -distance;
          }
        } else {
          _picking = picking + dt;
          if (_picking! >= pickAt) _battery = null;
          if (_picking! >= pickEnd) _stand();
        }
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
        if (_t >= plugEnd) {
          _start(PipActivity.charging);
          _nextScreen();
        }
      case PipActivity.charging:
        _screenT += dt;
        _screenFor -= dt;
        if (_screenFor <= 0) _nextScreen();
        final demo = _demoCharge;
        if (demo != null) {
          _demoCharge = demo + dt;
          if (_demoCharge! >= demoChargeHold) {
            _demoCharge = null;
            // The phone plugged in: he stays plugged in if he'd be anyway
            // (not full); else he unplugs (the station stays while the
            // phone's plugged in, else it sinks).
            if (!phonePlugged || segments >= 3) _startUnplugging();
          }
        }
      case PipActivity.unplugging:
        if (_t >= unplugEnd) {
          _stand();
          // The phone unplugged: the station goes too.
          if (!_wantsStation) _sinkStation();
        }
    }
    if (activity == PipActivity.standing) _maybeCharge();
    x = x.clamp(0, _maxX);
  }

  // Round 44: his charging station.

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

  /// The phone plugged in (from his room, checked every second).
  bool phonePlugged = false;

  /// The demo (Pip Home's list): seconds charging so far, or null.
  double? _demoCharge;

  /// Whether the station should be up: the phone plugged in, or a demo.
  bool get _wantsStation => phonePlugged || _demoCharge != null;

  /// The station's left edge (null: none), how far up it is (0 in the
  /// ground, 1 up), and which way it's going (1 rising, −1 sinking).
  double? _stationX;
  double _stationUp = 0;
  int _stationDir = 0;
  bool _stationRight = true;

  /// The station: its left edge, how far up (0 to 1), and whether its
  /// socket faces left (it's on his right); null when there's none.
  (double, double, bool)? get station {
    final sx = _stationX;
    if (sx == null) return null;
    return (sx, _stationUp, _stationRight);
  }

  /// The station rising or sinking now.
  bool get stationMoving => _stationDir != 0;

  /// Which side of him the station is on (it rises on the side with more
  /// room, so never on top of him).
  bool get stationOnRight => _stationRight;

  /// Room for the station and him beside it, with some to spare.
  bool get _stationFits =>
      roomWidth >= 2 * width + stationWidth + stationGap + 8;

  /// Where he stands to plug in.
  double get _plugX => _stationRight
      ? _stationX! - stationGap - width
      : _stationX! + stationWidth + stationGap;

  /// The phone plugged in or not, as now known; [animate]: seen happening
  /// (the station rises or sinks, he plugs in or out), else made so at
  /// once (the app opened while charging: he's simply there, charging).
  void setPlugged(bool plugged, {bool animate = true}) {
    if (plugged == phonePlugged && (_stationX != null) == _wantsStation) {
      return;
    }
    phonePlugged = plugged;
    // A demo going on: it ends on its own.
    if (_demoCharge != null) return;
    _setStation(plugged, animate: animate);
  }

  void _setStation(bool up, {required bool animate}) {
    if (up) {
      if (!_stationFits) return;
      if (_stationX == null) {
        // The side with more room: never on top of him.
        _stationRight = x + width / 2 <= roomWidth / 2;
        _stationX =
            _stationRight ? (roomWidth - stationWidth - 4).toDouble() : 4;
        _stationUp = animate ? 0 : 1;
        _stationDir = animate ? 1 : 0;
      } else if (_stationDir < 0) {
        _stationDir = 1; // sinking: back up
      }
      if (!animate && _goesCharging) {
        // Simply there, charging.
        x = _plugX;
        facingRight = _stationRight;
        _start(PipActivity.charging);
        _nextScreen();
      }
      return;
    }
    switch (activity) {
      case PipActivity.charging || PipActivity.plugging:
        if (animate) {
          _startUnplugging();
          return; // the station sinks once he's done
        }
        _stand();
      case PipActivity.toStation:
        _stand();
      case PipActivity.unplugging when animate:
        return;
      default:
    }
    if (activity == PipActivity.unplugging) _stand();
    animate ? _sinkStation() : _stationX = null;
  }

  void _sinkStation() {
    if (_stationX == null) return;
    _stationDir = -1;
  }

  void _startUnplugging() {
    _start(PipActivity.unplugging);
    facingRight = _stationRight;
  }

  void _stepStation(double dt) {
    _stationClock += dt;
    if (_stationX == null || _stationDir == 0) return;
    _stationUp += _stationDir * dt / stationRise;
    if (_stationUp >= 1) {
      _stationUp = 1;
      _stationDir = 0;
    } else if (_stationUp <= 0) {
      _stationX = null;
      _stationUp = 0;
      _stationDir = 0;
    }
  }

  /// Bedtime (his life says asleep): he doesn't go and plug in.
  bool _bedtime = false;

  /// He'd go and plug in now: the station up, he isn't full (it's for
  /// looks: he ignores it full, Nikola), or it's a demo; not at bedtime.
  bool get _goesCharging =>
      _stationX != null &&
      _wantsStation &&
      !_bedtime &&
      (segments < 3 || _demoCharge != null) &&
      (activity == PipActivity.standing ||
          activity == PipActivity.walking ||
          activity == PipActivity.spawning);

  /// Standing about with the station up and wanted: off he hurries.
  void _maybeCharge() {
    if (_stationDir != 0 || !_goesCharging) return;
    _target = _plugX;
    if ((_target - x).abs() < 0.5) {
      x = _target;
      facingRight = _stationRight;
      _start(PipActivity.plugging);
      return;
    }
    facingRight = _target > x;
    _start(PipActivity.toStation);
  }

  /// What his screen shows while he charges, and seconds into it.
  ChargeScreen _screen = ChargeScreen.happy;
  double _screenT = 0;
  double _screenFor = 0;

  void _nextScreen() {
    final others = [
      for (final s in ChargeScreen.values)
        if (s != _screen) s,
    ];
    _screen = others[random.nextInt(others.length)];
    _screenT = 0;
    // A demo shows more of them.
    _screenFor = _demoCharge != null ? 1.5 : 4 + random.nextDouble() * 3;
  }

  /// Shows [screen], [t] seconds in (for tests and pictures).
  @visibleForTesting
  void debugScreen(ChargeScreen screen, double t) {
    _screen = screen;
    _screenT = t;
    _screenFor = 100;
  }

  /// While charging: what his screen shows, and how far into it.
  (ChargeScreen, double)? get chargeScreen =>
      activity == PipActivity.charging ? (_screen, _screenT) : null;

  /// The station's lamp: blinking slowly while it's up.
  bool get stationLamp => _stationClock % 1.2 < 0.6;
  double _stationClock = 0;

  /// His port (where the plug goes) and the station's hook and socket, as
  /// (x, height above the ground) in room pixels.
  (double, double) get _port => (_stationRight ? x + width - 2 : x, portUp);
  (double, double) get _hook => (
        _stationRight ? _stationX! - 3 : _stationX! + stationWidth + 1,
        hookUp,
      );
  (double, double) get socket => (
        _stationRight ? _stationX! - 1 : _stationX! + stationWidth,
        socketUp,
      );
  static const portUp = 9.0;
  static const hookUp = 5.0;
  static const socketUp = 8.0;

  /// Where his floating hands are (Round 44: they pop in when he needs
  /// them, and away after): each (x, height above the ground, size 0–1),
  /// the near one (towards the station) first; none when not needed.
  List<(double, double, double)> get mitts {
    final plugging = activity == PipActivity.plugging;
    if (!plugging && activity != PipActivity.unplugging) return const [];
    final near = _stationRight ? x + width + 2 : x - 4;
    final far = _stationRight ? x - 4 : x + width + 2;
    const rest = 8.0;
    final double size;
    if (_t < mittsInEnd) {
      size = _t / mittsInEnd;
    } else {
      final out = plugging ? pushEnd : hangEnd;
      final end = plugging ? plugEnd : unplugEnd;
      size = _t < out ? 1 : 1 - ((_t - out) / (end - out)).clamp(0.0, 1.0);
    }
    final hand = _plugPoint ?? (near, rest);
    // Before it takes the plug, and after it lets go: on its way.
    final (hx, hy) = switch (plugging) {
      true when _t < toHookEnd => _lerp(
          (near, rest),
          (_hook.$1, _hook.$2 - 1),
          _ease((_t - mittsInEnd) / (toHookEnd - mittsInEnd)),
        ),
      false when _t < toPortEnd => _lerp(
          (near, rest),
          (_port.$1, _port.$2 - 2),
          _ease((_t - mittsInEnd) / (toPortEnd - mittsInEnd)),
        ),
      _ when _plugPoint != null => (hand.$1, hand.$2 - 2),
      _ => (near, rest),
    };
    return [(hx, hy, size), (far, rest, size)];
  }

  /// Where the plug is (x, height above the ground) while a hand carries
  /// it; null when it's on the hook or in his side ([plug] says).
  (double, double)? get _plugPoint {
    if (activity == PipActivity.plugging && _t >= toHookEnd && _t < carryEnd) {
      final p = _t < grabEnd ? 0.0 : (_t - grabEnd) / (carryEnd - grabEnd);
      return _lerp(_hook, _port, _ease(p));
    }
    if (activity == PipActivity.unplugging && _t >= pullEnd && _t < backEnd) {
      return _lerp(_port, _hook, _ease((_t - pullEnd) / (backEnd - pullEnd)));
    }
    return null;
  }

  /// The plug (x, height above the ground): on the hook, carried, or in
  /// his side; null without a station.
  (double, double)? get plug {
    if (_stationX == null) return null;
    final carried = _plugPoint;
    if (carried != null) return carried;
    final inPort = switch (activity) {
      PipActivity.charging => true,
      PipActivity.plugging => _t >= carryEnd,
      PipActivity.unplugging => _t < pullEnd,
      _ => false,
    };
    return inPort ? _port : _hook;
  }

  /// Sparks at the plug: pushed in, and the charging screen that has
  /// them; each (x, height above the ground).
  List<(double, double)> get sparks {
    final pushing =
        activity == PipActivity.plugging && _t >= carryEnd && _t < pushEnd;
    final screen = activity == PipActivity.charging &&
        _screen == ChargeScreen.sparks &&
        (_screenT * 6).floor().isEven;
    if (!pushing && !screen) return const [];
    final (px, py) = _port;
    final out = _stationRight ? 1.0 : -1.0;
    final t = (_t * 10).floor();
    return [
      for (var i = 0; i < 4; i++)
        (px + out * (2 + (t + i * 3) % 4), py + (i.isEven ? 2 : -1) + i % 2),
    ];
  }

  /// Humming (a charging screen): little notes floating up, each (x from
  /// his middle, y above his head, how faded 0–1).
  List<(double, double, double)> get notes {
    if (activity != PipActivity.charging || _screen != ChargeScreen.humming) {
      return const [];
    }
    return [
      for (var i = 0; i < 2; i++)
        if (((_screenT / 2.2 + i / 2) % 1) case final p)
          ((i.isEven ? 5 : -7) + 3 * p, 2 + 10 * p, p),
    ];
  }

  static (double, double) _lerp(
          (double, double) a, (double, double) b, double p) =>
      (a.$1 + (b.$1 - a.$1) * p, a.$2 + (b.$2 - a.$2) * p);

  static double _ease(double p) {
    final c = p.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  void _stand() {
    activity = PipActivity.standing;
    _t = 0;
    _standFor = 1.5 + random.nextDouble() * 3.5;
    // Now and then he looks round the other way for a bit.
    _turnAt = random.nextDouble() < 0.4
        ? _standFor * (0.3 + 0.4 * random.nextDouble())
        : null;
  }

  void _walk() {
    // Somewhere at least a few steps away, inside the room.
    final max = _maxX;
    if (max < 8) {
      _stand();
      return;
    }
    // Round 44: not into his station, if it's up.
    var low = 0.0, high = max;
    if (_stationX != null) {
      if (_stationRight) {
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
        PipActivity.hatching => _t < jumpEnd
            ? PipFrame.oh
            : (_t < hatchLandEnd ? PipFrame.tuck : PipFrame.idle),
        PipActivity.spawning => _t < hopEnd ? PipFrame.oh : PipFrame.tuck,
        PipActivity.standing => _blinking > 0 ? PipFrame.blink : PipFrame.idle,
        PipActivity.walking => _stepFrame,
        PipActivity.fallingAsleep =>
          _t < settleAt ? PipFrame.idle : PipFrame.tuck,
        PipActivity.asleep => PipFrame.tuck,
        PipActivity.wakingUp => _t < eyesOpenAt ? PipFrame.tuck : PipFrame.idle,
        PipActivity.poweringOff ||
        PipActivity.off ||
        PipActivity.poweringOn =>
          PipFrame.idle,
        PipActivity.fetching => _picking == null
            ? (_atTarget ? PipFrame.idle : _stepFrame)
            : (_picking! < pickAt ? PipFrame.tuck : PipFrame.idle),
        PipActivity.toStation => _stepFrame,
        PipActivity.plugging ||
        PipActivity.charging ||
        PipActivity.unplugging =>
          PipFrame.idle,
      };

  /// Hurrying, his steps come quicker too (Round 44).
  PipFrame get _stepFrame => const [
        PipFrame.step1,
        PipFrame.step2,
        PipFrame.step3,
        PipFrame.step4,
      ][(_t / (_hurrying ? stepTime * speed / hurry : stepTime)).floor() % 4];

  bool get _hurrying =>
      activity == PipActivity.toStation || activity == PipActivity.fetching;

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
  double get lift {
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
            activity == PipActivity.wakingUp)) {
      return -2;
    }
    switch (activity) {
      case PipActivity.wakingUp:
        return hop(eyesOpenAt + 0.15, wakeHopEnd, 3);
      case PipActivity.poweringOn:
        return hop(riseUpEnd, onEnd, 3);
      case PipActivity.fetching when _picking != null:
        final p = _picking!;
        if (p < pickAt || p >= pickEnd) return 0;
        return 3 * math.sin(math.pi * (p - pickAt) / (pickEnd - pickAt));
      default:
    }
    if (frame == PipFrame.step1 || frame == PipFrame.step3) return 1;
    return 0;
  }

  /// Squash and stretch: (width, height) scale.
  (double, double) get stretch {
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

  static double _easeOut(double p) => 1 - math.pow(1 - p, 3).toDouble();
}
