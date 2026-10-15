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

  // Round 52: more ways in, and things happening in his field.

  /// Dropping in from the sky: he falls, lands with a squash and dust.
  falling,

  /// Thrown in from the side (the menu's swing): tumbling through the
  /// air, landing with a thump.
  thrown,

  /// After being thrown in: a scowl, a fist shaken, cross words.
  angry,

  /// Bugs crawl in; he pops out a sword and fights them off.
  bugHunt,

  /// Something on his screen for a while (a notification, or his medicine).
  showing,

  /// A flower comes up; he walks over, picks it, holds it a while.
  flower,

  /// A butterfly flutters by; he watches it.
  butterfly,

  /// A ball rolls in; he walks up and kicks it away.
  ball,

  /// At dusk or night: a shooting star streaks over; he looks up at it.
  stargazing,

  /// A little dance: hops, turning to the beat, music on his screen.
  dancing,

  /// Round 53: eating from a plate in his hands, a few bites, crumbs.
  eating,
}

/// A buzz of the phone, how strong (Round 53).
enum PipBuzz { light, medium, heavy }

/// How he comes into his field (Round 52): out of the ground, from the
/// sky, or thrown in from the side (only in the menu, by its swing).
enum PipEntrance { ground, sky, side }

/// What his screen can show for a while (Round 52): notifications (when
/// one comes), and with some events (Round 53: not for fun on its own).
enum PipScreen {
  envelope(notification: true),
  bell(notification: true),
  alert(notification: true),

  /// Round 53: a pill, reminding of a medicine (the medicine red dot).
  pill,

  /// Dancing.
  music,

  /// Proud (after the bugs) or glad (holding a flower).
  happy;

  /// Shown when a notification comes (Round 53: no more pictures for fun:
  /// the others go with an event).
  final bool notification;

  /// Shown with a hop: a notification, or his medicine reminder.
  bool get hops => notification || this == PipScreen.pill;

  const PipScreen({this.notification = false});
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
enum PipFace {
  normal,
  tired,
  veryTired,
  asleep,
  off,

  /// Round 52: thrown in, and cross about it.
  angry,
}

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
  // Round 54: in the list too, as a preview (no battery used).
  fetch('Changing his battery'),
  // Round 44: the station rises, he plugs in, charges a while, unplugs.
  charge('Charging'),
  // Round 52: more entrances, and things that happen now and then.
  fromSky('Falling from the sky'),
  fromSide('Thrown in from the side'),
  bugs('Fighting bugs'),
  notified('A notification'),
  flower('Picking a flower'),
  butterfly('Watching a butterfly'),
  ball('Kicking a ball'),
  shootingStar('A shooting star'),
  dance('A little dance'),
  // Round 53: a medicine due (the red dot), and after a recipe.
  medicine('A medicine reminder'),
  eat('Eating');

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
///
/// Round 52: an entrance (from the sky, thrown in, angry after) or an
/// event (bugs, his screen, a flower, a butterfly, a ball) runs its
/// course; they start only while he's up and about.
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
      PipActivity.unplugging ||
      // Round 52: an entrance, or an event, runs its course.
      PipActivity.falling ||
      PipActivity.thrown ||
      PipActivity.angry ||
      PipActivity.bugHunt ||
      PipActivity.showing ||
      PipActivity.flower ||
      PipActivity.butterfly ||
      PipActivity.ball ||
      PipActivity.stargazing ||
      PipActivity.dancing ||
      PipActivity.eating =>
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

  /// His casing's sides, in from his box's (Round 54: hands go by these).
  static const bodyInset = 2;

  /// A hand's middle beside him, a pixel off his casing: on his right or
  /// his left. Its two pixels are [handX] - 1 and [handX].
  double handBeside({required bool right}) =>
      right ? x + width - bodyInset + 2 : x + bodyInset - 2;

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
        // Round 54: a preview (no battery used): one dropped near him.
        return takeBattery(_batterySpot);
      case PipAnimation.charge:
        // Only where there's room for the station. The phone plugged in
        // and him not at it (full, say): it plays all the same (Round 45).
        if (!_stationFits) return false;
        _demoCharge = 0;
        _setStation(true, animate: true);
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
        _start(PipActivity.stargazing);
        _starFromLeft = random.nextBool();
      case PipAnimation.dance:
        _start(PipActivity.dancing);
      case PipAnimation.medicine:
        _startShowing(PipScreen.pill);
      case PipAnimation.eat:
        _start(PipActivity.eating);
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
    // Round 54: to stand beside it (it by the hand he'll use), on the
    // side he comes from if there's room there.
    final rightOf = left + batteryWidth / 2 >= x + width / 2;
    final besideLeft = left - (width - bodyInset + 1); // it on his right
    final besideRight = left + batteryWidth + 1 - bodyInset; // his left
    bool fits(double at) => at >= 0 && at <= _maxX;
    final take = rightOf
        ? (fits(besideLeft) || !fits(besideRight))
        : !fits(besideRight) && fits(besideLeft);
    _batteryOnRight = take;
    _target = (take ? besideLeft : besideRight).clamp(0, _maxX).toDouble();
    facingRight = _target >= x;
    return true;
  }

  /// Which side of him the dropped battery is (Round 54).
  bool _batteryOnRight = true;

  /// A spot a few steps off for a battery to drop at (Round 54: the
  /// preview), on whichever side has room.
  double get _batterySpot {
    final right = x + width - bodyInset + 1 + 20;
    if (right + batteryWidth <= roomWidth) return right;
    final left = x + bodyInset - 1 - batteryWidth - 20;
    return left >= 0
        ? left
        : right.clamp(0, roomWidth - batteryWidth).toDouble();
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
    // Round 54: taken by the hand, carried to his slot, pushed in.
    final p = _picking;
    if (activity == PipActivity.fetching && p != null && p >= grabbed) {
      final out = _slotLeft(out: true);
      if (p < atSlotAgain) {
        final q = _ease((p - grabbed) / (atSlotAgain - grabbed));
        return _lerp((b, 0), (out, slotUp), q);
      }
      final q =
          _ease(((p - atSlotAgain) / (pushedIn - atSlotAgain)).clamp(0.0, 1.0));
      return _lerp((out, slotUp), (_slotLeft(out: false), slotUp), q);
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

  /// Waking's parts (Round 53: slower): eyes open, a stretch, then up
  /// with a hop.
  static const eyesOpenAt = 1.0;
  static const stretchEnd = 1.8;
  static const wakeHopEnd = 2.4;

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
  static const pickEnd = 3.0;

  /// The slot's bottom (height above the ground) and its height.
  static const slotUp = 6.0;
  static const slotRows = 7;

  /// A battery's left edge by his slot: all in (behind his casing) or
  /// out (a pixel off it).
  double _slotLeft({required bool out}) => _batteryOnRight
      ? (out ? x + width - bodyInset + 1 : x + width - bodyInset - batteryWidth)
      : (out ? x + bodyInset - 1 - batteryWidth : x + bodyInset.toDouble());

  /// Where the hand is holding a battery at [left], [up]: at its outer
  /// side ((x, height) of the hand's middle).
  (double, double) _holding(double left, double up) => (
        _batteryOnRight ? left + batteryWidth + 1 : left - 1,
        up + batteryHeight / 2,
      );

  /// The old battery, out of his side: its left edge, height above the
  /// ground, how faded (0–1) and turned (flying, end over end); null
  /// while it's in him, and gone.
  (double, double, double, bool)? get oldBattery {
    final p = _picking;
    if (activity != PipActivity.fetching || p == null || p < atSlot) {
      return null;
    }
    final inside = _slotLeft(out: false);
    final out = _slotLeft(out: true);
    if (p < pulledOut) {
      final q = _ease((p - atSlot) / (pulledOut - atSlot));
      return (inside + (out - inside) * q, slotUp, 0, false);
    }
    if (p < throwAt) {
      // Lifted, ready to throw.
      final q = _ease((p - pulledOut) / (throwAt - pulledOut));
      return (out, slotUp + 4 * q, 0, false);
    }
    final q = (p - throwAt) / throwFlight;
    if (q >= 1) return null;
    final away = _batteryOnRight ? 1.0 : -1.0;
    return (
      out + away * 50 * q,
      slotUp + 4 + 16 * math.sin(math.pi * q * 0.9),
      q < 0.6 ? 0 : (q - 0.6) / 0.4,
      (q * 8).floor().isOdd,
    );
  }

  /// The slot in his side, open while the batteries go in and out: the
  /// column of his casing it's in, or null.
  double? get batterySlot {
    final p = _picking;
    if (activity != PipActivity.fetching || p == null) return null;
    if (p < handIn || p >= pushedIn + 0.1) return null;
    return _batteryOnRight ? x + width - bodyInset - 1 : x + bodyInset;
  }

  /// The hand changing his battery: (x, height of its middle, size).
  (double, double, double)? get _batteryHand {
    final p = _picking;
    if (activity != PipActivity.fetching || p == null || p >= handOut) {
      return null;
    }
    final rest = (handBeside(right: _batteryOnRight), 9.0);
    final atOld = _holding(_slotLeft(out: false), slotUp);
    final b = _battery;
    final onGround = b == null ? rest : _holding(b, 0);
    if (p < handIn) return (rest.$1, rest.$2, p / handIn);
    if (p < atSlot) {
      final (hx, hy) =
          _lerp(rest, atOld, _ease((p - handIn) / (atSlot - handIn)));
      return (hx, hy, 1);
    }
    if (p < throwAt) {
      final (left, up, _, _) = oldBattery!;
      final (hx, hy) = _holding(left, up);
      return (hx, hy, 1);
    }
    if (p < atBattery) {
      final from = _holding(_slotLeft(out: true), slotUp + 4);
      final (hx, hy) =
          _lerp(from, onGround, _ease((p - throwAt) / (atBattery - throwAt)));
      return (hx, hy, 1);
    }
    if (p < pushedIn) {
      final (left, up) = battery!;
      final (hx, hy) = _holding(left, up);
      return (hx, hy, 1);
    }
    final size = 1 - (p - pushedIn) / (handOut - pushedIn);
    final (hx, hy) = _holding(_slotLeft(out: false), slotUp);
    return (hx, hy, size.clamp(0.0, 1.0));
  }

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
      case PipActivity.angry:
        return PipFace.angry;
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
        if (_t >= _standFor && !_maybeEvent()) _walk();
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
            if (_batteryHeight == 0) {
              _picking = 0;
              facingRight = _batteryOnRight;
            }
          } else {
            x += _target > x ? distance : -distance;
          }
        } else {
          _picking = picking + dt;
          if (_picking! >= pushedIn) _battery = null;
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
        if (_t >= _showFor) _stand();
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
        // Turning on each beat.
        final beat = (_t / beatTime).floor();
        facingRight = beat.isEven;
        if (_t >= danceTime) _stand();
      case PipActivity.eating:
        if (_t >= eatTime) _stand();
    }
    _stepMedicine(dt);
    if (activity == PipActivity.standing) _maybeCharge();
    // Thrown in, he's still coming in from beyond the edge.
    if (activity != PipActivity.thrown) x = x.clamp(0, _maxX);
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

  /// His floating hand (Round 44: it pops in when he needs it, and away
  /// after): each (x, height above the ground, size 0–1); Round 54: only
  /// the one he uses (two holding his plate); none when not needed.
  List<(double, double, double)> get mitts {
    // Round 54: changing his battery.
    if (_batteryHand case (final hx, final hy, final size)) {
      return [(hx - 1, hy - 1.5, size)];
    }
    // Round 53: holding his plate, one each side.
    if (plate case (final px, final py, _, final size)) {
      return [(px - 1, py - 0.5, size), (px + plateWidth - 1, py - 0.5, size)];
    }
    final plugging = activity == PipActivity.plugging;
    if (!plugging && activity != PipActivity.unplugging) return const [];
    // Round 54: close by his side (a pixel off it), only the one he uses.
    final near = handBeside(right: _stationRight) - 1;
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
    return [(hx, hy, size)];
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
        _target = (roomWidth * 0.3).clamp(0, _maxX).toDouble();
        _throwHigh = math.min(18, math.max(4, skyRows - height - 6)).toDouble();
        x = _throwFrom;
        facingRight = true;
        _start(PipActivity.thrown);
    }
  }

  /// Moments to feel (Round 53: a kick, a strike, a landing), taken by
  /// his room to buzz the phone.
  final List<PipBuzz> _buzzes = [];
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

  /// Angry (after a throw): his face says so, a fist shakes over his
  /// head, cross words (#!) above it.
  bool get angry => activity == PipActivity.angry;

  /// Seconds into what he's doing (for things that flicker with it).
  double get zsClock => _t;

  /// The shaking fist: (x, height above the ground), or null.
  (double, double)? get fist {
    if (!angry) return null;
    final shake = (_t * 8).floor().isEven ? -1.0 : 1.0;
    // Round 54: by his side (drawn from its left pixel).
    final side = handBeside(right: facingRight) - 1;
    return (side + shake, height + 1.0);
  }

  // Round 52: events, now and then while he stands about.

  /// The chance, each time he'd walk off, that something happens instead.
  static const eventChance = 0.09;

  /// Room enough for an event (something coming in, him going to it).
  bool get _eventRoom => roomWidth >= 3 * width + 10;

  /// Something happens instead of a walk, sometimes: not with the
  /// station up, and not at bedtime. True if it did.
  bool _maybeEvent() {
    if (!_eventRoom || _wantsStation || _bedtime) return false;
    if (random.nextDouble() >= eventChance) return false;
    // At dusk or night, now and then a shooting star.
    if (dark && random.nextInt(4) == 0) {
      play(PipAnimation.shootingStar);
      return true;
    }
    final pick = random.nextInt(9);
    switch (pick) {
      case 0 || 1:
        _startBugs();
      case 2 || 3:
        _startFlower();
      case 4 || 5:
        _startButterfly();
      case 6 || 7:
        _startBall();
      default:
        _start(PipActivity.dancing);
    }
    return true;
  }

  /// Dusk or night in his sky (the room says): shooting stars then.
  bool dark = false;

  // A shooting star.
  bool _starFromLeft = true;
  bool get shootingStarFromLeft => _starFromLeft;
  static const starTime = 1.1;

  /// The shooting star: (x, rows down from the top of the sky, how far
  /// across 0–1); null when there's none.
  (double, double, double)? get shootingStar {
    if (activity != PipActivity.stargazing || _t >= starTime) return null;
    final p = _t / starTime;
    final from = _starFromLeft ? roomWidth * 0.1 : roomWidth * 0.9;
    final to = _starFromLeft ? roomWidth * 0.75 : roomWidth * 0.25;
    return (from + (to - from) * p, 4 + skyRows * 0.25 * p, p);
  }

  // Round 53: his medicine reminder.

  /// A medicine due and not marked (the room says, from the red dot).
  bool medicineDue = false;

  /// Seconds before he reminds of it: soon after it's due (or he's
  /// seen), then every [remindEvery] while it's still due.
  static const remindFirst = 3.0;
  static const remindEvery = 45.0;
  double _remindIn = remindFirst;

  void _stepMedicine(double dt) {
    if (!medicineDue) {
      _remindIn = remindFirst;
      return;
    }
    if (activity != PipActivity.standing && activity != PipActivity.walking) {
      return;
    }
    _remindIn -= dt;
    if (_remindIn > 0) return;
    _remindIn = remindEvery;
    _startShowing(PipScreen.pill);
  }

  // Round 53: eating, after a recipe was looked at a while.

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

  /// The recipe reading he last ate for (the room: once for each).
  DateTime? ateFor;

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
    final taken = bites.where((b) => _t >= b + biteTime / 2).length;
    final double size = _t < plateIn
        ? _t / plateIn
        : _t > eatTime - plateIn
            ? ((eatTime - _t) / plateIn).clamp(0.0, 1.0)
            : 1;
    var up = 0.0;
    for (final b in bites) {
      if (_t >= b && _t < b + biteTime) {
        up = 3 * math.sin(math.pi * (_t - b) / biteTime);
      }
    }
    final left = x + (width - plateWidth) / 2;
    return (left, plateRest + up, taken, size);
  }

  /// Crumbs falling from the plate after each bite: (x, height).
  List<(double, double)> get crumbs {
    if (activity != PipActivity.eating) return const [];
    final out = <(double, double)>[];
    for (final (i, b) in bites.indexed) {
      final since = _t - b - biteTime / 2;
      if (since < 0 || since >= 0.6) continue;
      final fall = 0.5 * 40 * since * since;
      for (final dx in const [-2.0, 3.0]) {
        final h = plateRest + 2 - fall;
        if (h > 0) out.add((x + width / 2 + dx + i, h));
      }
    }
    return out;
  }

  /// A little dance: its length and beat, in seconds.
  static const danceTime = 4.0;
  static const beatTime = 0.5;

  /// A notification came (his room heard): his screen shows one, with a
  /// hop, if he's up and about; else nothing (asleep, busy, charging).
  bool notify() {
    if (activity != PipActivity.standing && activity != PipActivity.walking) {
      return false;
    }
    _startShowing(_notifyScreens[random.nextInt(_notifyScreens.length)]);
    return true;
  }

  static final _notifyScreens = [
    for (final s in PipScreen.values)
      if (s.notification) s,
  ];

  // His screen showing something.
  PipScreen _screenShow = PipScreen.happy;
  double _showFor = 3;

  void _startShowing(PipScreen screen) {
    _screenShow = screen;
    _showFor = screen.hops ? 4.0 : 3.2;
    _start(PipActivity.showing);
  }

  /// What his screen shows and how far into it: while [PipActivity.
  /// showing], and after a bug fight (proud) or holding a flower (happy).
  (PipScreen, double)? get screenShow => switch (activity) {
        PipActivity.showing => (_screenShow, _t),
        PipActivity.dancing => (PipScreen.music, _t),
        PipActivity.eating when _t >= eatenAt => (
            PipScreen.happy,
            _t - eatenAt
          ),
        PipActivity.bugHunt when _bugsLeft == 0 => (PipScreen.happy, _phaseT),
        PipActivity.flower when _flowerPhase == 3 => (PipScreen.happy, _t),
        _ => null,
      };

  /// Shows [screen] now (for tests and pictures).
  @visibleForTesting
  void debugShow(PipScreen screen) => _startShowing(screen);

  // Bugs.

  int _bugsLeft = 0;
  double? _bugX;
  bool _bugFromRight = true;

  /// 0 the sword pops in, 1 the bug crawls (he goes for it), 2 the
  /// swing, 3 the poof; [_phaseT] seconds into it.
  int _bugPhase = 0;
  double _phaseT = 0;

  static const bugWidth = 8;
  static const bugSpeed = 9.0;
  static const swordIn = 0.35;
  static const swingTime = 0.3;
  static const poofTime = 0.35;

  /// How far his sword reaches past his side.
  static const reach = 7.0;

  void _startBugs() {
    _bugsLeft = 1 + random.nextInt(3);
    _start(PipActivity.bugHunt);
    _nextBug();
    _bugPhase = 0;
  }

  void _nextBug() {
    _bugFromRight = random.nextBool();
    _bugX = _bugFromRight ? roomWidth.toDouble() : -bugWidth.toDouble();
    _bugPhase = 1;
    _phaseT = 0;
  }

  /// Where he swings from: his side facing the bug.
  double get _swordSide => facingRight ? x + width : x;

  bool get _bugWalking => _bugPhase == 1 && !_bugInReach && _bugX != null;

  bool get _bugInReach {
    final b = _bugX;
    if (b == null) return false;
    final near = facingRight ? b : b + bugWidth;
    return (near - _swordSide).abs() <= reach && (facingRight == (b > x));
  }

  void _stepBugs(double dt) {
    _phaseT += dt;
    final b = _bugX;
    switch (_bugPhase) {
      case 0: // the sword pops in
        if (_phaseT >= swordIn) {
          _bugPhase = 1;
          _phaseT = 0;
        }
      case 1: // the bug crawls in; he hurries at it
        if (b == null) return;
        final towards = b + bugWidth / 2 > x + width / 2 ? 1 : -1;
        _bugX = b - towards * bugSpeed * dt;
        facingRight = towards > 0;
        if (_bugInReach) {
          _bugPhase = 2;
          _phaseT = 0;
        } else if ((b - x).abs() > width) {
          // Up to it, but not off his field.
          x = (x + towards * hurry * dt).clamp(0, _maxX).toDouble();
        }
      case 2: // the swing
        if (_phaseT >= swingTime) {
          _bugPhase = 3;
          _phaseT = 0;
          _buzzes.add(PipBuzz.light); // struck
        }
      case 3: // the poof
        if (_phaseT >= poofTime) {
          _bugsLeft--;
          if (_bugsLeft > 0) {
            _nextBug();
          } else {
            _bugX = null;
            _bugPhase = 4;
            _phaseT = 0;
          }
        }
      default: // all gone: proud a moment, the sword away
        if (_phaseT >= 1.6) _stand();
    }
  }

  /// The bug: its left edge and whether its legs are up (they step);
  /// null when there's none (or it's gone in a poof).
  (double, bool)? get bug {
    final b = _bugX;
    if (activity != PipActivity.bugHunt || b == null || _bugPhase == 3) {
      return null;
    }
    return (b, (_t * 8).floor().isEven);
  }

  /// The poof where a bug was struck: its middle and 0 → 1.
  (double, double)? get poof {
    if (activity != PipActivity.bugHunt || _bugPhase != 3) return null;
    return ((_bugX ?? x) + bugWidth / 2, _phaseT / poofTime);
  }

  /// His sword (Round 52, for the adventures later): held in a floating
  /// hand at (x, height above the ground), its angle (0 up, pointing
  /// forward as it grows) and size (popping in and away); null when put
  /// away.
  (double, double, double, double)? get sword {
    if (activity != PipActivity.bugHunt) return null;
    // Round 53: held out in front, pointing up and away from him.
    // Round 54: a little closer to him.
    final hand = handBeside(right: facingRight);
    final double size = switch (_bugPhase) {
      0 => (_phaseT / swordIn).clamp(0.0, 1.0),
      4 => (1 - (_phaseT - 1.0) / 0.4).clamp(0.0, 1.0),
      _ => 1,
    };
    final forward = facingRight ? 1.0 : -1.0;
    final double angle = switch (_bugPhase) {
      2 => forward * (0.3 + 1.5 * _ease(_phaseT / swingTime)),
      3 => forward * 1.8,
      _ => forward * 0.3, // raised, ready, leaning forward
    };
    return (hand, 7, angle, size);
  }

  // A flower.

  double _flowerX = 0;

  /// 0 it comes up, 1 he walks over, 2 he picks it, 3 he holds it, 4 it
  /// fades.
  int _flowerPhase = 0;
  static const sproutTime = 1.2;
  static const flowerPick = 0.45;
  static const flowerHold = 3.0;
  static const flowerFade = 0.6;

  void _startFlower() {
    // Somewhere a few steps away, inside his field.
    final max = _maxX;
    var at = x;
    for (var i = 0; i < 12 && (at - x).abs() < 12; i++) {
      at = random.nextDouble() * max;
    }
    if ((at - x).abs() < 12) at = x < max / 2 ? max : 0;
    _flowerX = at + width / 2 - 1;
    _target = at;
    _flowerPhase = 0;
    _start(PipActivity.flower);
  }

  void _stepFlower(double dt) {
    switch (_flowerPhase) {
      case 0:
        if (_t >= sproutTime) {
          _flowerPhase = 1;
          facingRight = _target > x;
          _t = 0;
        }
      case 1:
        final distance = pace * dt;
        if ((_target - x).abs() <= distance) {
          x = _target;
          _flowerPhase = 2;
          _t = 0;
        } else {
          x += _target > x ? distance : -distance;
        }
      case 2:
        if (_t >= flowerPick) {
          _flowerPhase = 3;
          _t = 0;
        }
      case 3:
        if (_t >= flowerHold) {
          _flowerPhase = 4;
          _t = 0;
        }
      default:
        if (_t >= flowerFade) _stand();
    }
  }

  /// The flower: (x, height above the ground of its stem's foot, grown
  /// 0–1, faded 0–1); in the ground until picked, then in his hand.
  (double, double, double, double)? get flower {
    if (activity != PipActivity.flower) return null;
    return switch (_flowerPhase) {
      0 => (_flowerX, 0, (_t / sproutTime).clamp(0.0, 1.0), 0),
      1 || 2 => (_flowerX, 0, 1, 0),
      _ => (
          // Round 53: its stem down in his hand.
          handBeside(right: facingRight) - 2,
          4,
          1,
          _flowerPhase == 4 ? (_t / flowerFade).clamp(0.0, 1.0) : 0,
        ),
    };
  }

  /// The hand holding the flower: (x, height), or null.
  (double, double)? get flowerHand {
    if (activity != PipActivity.flower || _flowerPhase < 3) return null;
    return (handBeside(right: facingRight) - 1, 5);
  }

  // A butterfly.

  double _flyX = 0;
  double _flyFrom = 0;
  bool _flyRight = true;
  static const butterflySpeed = 11.0;

  void _startButterfly() {
    _flyRight = random.nextBool();
    _flyFrom = _flyRight ? -6.0 : roomWidth + 1.0;
    _flyX = _flyFrom;
    _start(PipActivity.butterfly);
  }

  void _stepButterfly(double dt) {
    _flyX += (_flyRight ? 1 : -1) * butterflySpeed * dt;
    // He watches it: turned towards it.
    facingRight = _flyX + 2 > x + width / 2;
    if (_flyRight ? _flyX > roomWidth + 2 : _flyX < -8) _stand();
  }

  bool get _butterflyClose =>
      activity == PipActivity.butterfly &&
      (_flyX + 2 - (x + width / 2)).abs() < width;

  /// The butterfly: (x, height above the ground, wings up); null when
  /// there's none. It bobs as it goes.
  (double, double, bool)? get butterfly {
    if (activity != PipActivity.butterfly) return null;
    final up = 24 + 4 * math.sin(_t * 3) + 2 * math.sin(_t * 7.3);
    return (_flyX, up, (_t * 6).floor().isEven);
  }

  // A ball.

  double _ballX = 0;
  double _ballUp = 0;
  double _ballSpeed = 0;
  double _ballVy = 0;

  /// 0 it rolls in, 1 he walks up to it, 2 the kick, 3 it flies off.
  int _ballPhase = 0;
  static const ballSize = 4;
  static const kickTime = 0.25;

  void _startBall() {
    final fromRight = random.nextBool();
    _ballX = fromRight ? roomWidth.toDouble() : -ballSize.toDouble();
    _ballSpeed = fromRight ? -26 : 26;
    _ballUp = 0;
    _ballVy = 0;
    _ballPhase = 0;
    _start(PipActivity.ball);
  }

  void _stepBall(double dt) {
    switch (_ballPhase) {
      case 0:
        // Slowing as it rolls; it stops on its own.
        _ballX += _ballSpeed * dt;
        _ballSpeed *= math.pow(0.45, dt).toDouble();
        if (_ballSpeed.abs() < 3) {
          _ballSpeed = 0;
          _ballPhase = 1;
          // Beside it, the side it came from... facing it.
          final behind = _ballX + ballSize / 2 > x + width / 2;
          _target = (behind ? _ballX - width + 1 : _ballX + ballSize - 1)
              .clamp(0, _maxX)
              .toDouble();
          facingRight = _target < _ballX;
          if ((_target - x).abs() > 0.5) facingRight = _target > x;
        }
      case 1:
        final distance = pace * dt;
        if ((_target - x).abs() <= distance) {
          x = _target;
          facingRight = _ballX + ballSize / 2 > x + width / 2;
          _ballPhase = 2;
          _t = 0;
        } else {
          x += _target > x ? distance : -distance;
        }
      case 2:
        if (_t >= kickTime) {
          _buzzes.add(PipBuzz.medium); // the kick
          _ballPhase = 3;
          _ballSpeed = facingRight ? 55 : -55;
          _ballVy = 45;
          _t = 0;
        }
      default:
        _ballX += _ballSpeed * dt;
        _ballVy -= gravity * dt;
        _ballUp += _ballVy * dt;
        if (_ballUp < 0) {
          _ballUp = 0;
          _ballVy = -_ballVy * 0.5; // a bounce
        }
        if (_ballX > roomWidth + 2 || _ballX < -ballSize - 2) _stand();
    }
  }

  /// The ball: (left edge, height above the ground, which way it's
  /// turned 0–3); null when there's none.
  (double, double, int)? get ball {
    if (activity != PipActivity.ball) return null;
    return (_ballX, _ballUp, (_ballX / 2).floor() % 4);
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
        PipActivity.flower => _flowerPhase == 1 ? _stepFrame : PipFrame.idle,
        PipActivity.butterfly => _butterflyClose ? PipFrame.oh : PipFrame.idle,
        PipActivity.stargazing => PipFrame.oh,
        PipActivity.dancing =>
          (_t / beatTime * 2).floor().isEven ? PipFrame.step1 : PipFrame.step3,
        PipActivity.ball => switch (_ballPhase) {
            1 => _stepFrame,
            2 => PipFrame.step1,
            _ => PipFrame.idle,
          },
        // Round 53: his mouth open for each bite.
        PipActivity.eating => bites.any((b) => _t >= b && _t < b + biteTime)
            ? PipFrame.oh
            : PipFrame.idle,
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
  double get lift {
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
    if (activity == PipActivity.showing && _screenShow.hops && _t < 0.4) {
      return 3 * math.sin(math.pi * _t / 0.4); // a hop: something came
    }
    // Round 53: the pill twice (a second hop).
    if (activity == PipActivity.showing &&
        _screenShow == PipScreen.pill &&
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
            activity == PipActivity.wakingUp)) {
      return -2;
    }
    switch (activity) {
      case PipActivity.wakingUp:
        return hop(stretchEnd, wakeHopEnd, 3);
      case PipActivity.poweringOn:
        return hop(riseUpEnd, onEnd, 3);
      case PipActivity.fetching when _picking != null:
        final p = _picking!;
        if (p < handOut || p >= pickEnd) return 0;
        return 3 * math.sin(math.pi * (p - handOut) / (pickEnd - handOut));
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
        _t >= eyesOpenAt &&
        _t < stretchEnd) {
      final s = 0.12 *
          math.sin(math.pi * (_t - eyesOpenAt) / (stretchEnd - eyesOpenAt));
      return (1 - s / 2, 1 + s);
    }
    final crouch = switch (activity) {
      PipActivity.flower when _flowerPhase == 2 => _t / flowerPick,
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

  static double _easeOut(double p) => 1 - math.pow(1 - p, 3).toDouble();
}
