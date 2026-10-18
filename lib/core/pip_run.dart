import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:the_app/core/pip_brain.dart';

/// Where he is in his day out (Round 63).
enum RunPhase {
  /// Just registered: his sword held up high, a fanfare.
  cheer,

  /// Walking to the middle of his room.
  toCentre,

  /// Drawing his sword.
  drawing,

  /// Running right (the ground moving under him), striking bugs.
  running,

  /// A bug got him: knocked back, his sword flying off.
  knocked,

  /// On the ground a moment after.
  down,

  /// Going back for his sword...
  toSword,

  /// ...picking it up...
  pickUp,

  /// ...and back to the middle.
  back,

  /// Round 64: a tavern coming up; he runs till it's beside him.
  arriving,

  /// Putting the sword away, walking to his seat.
  toSeat,

  /// Sitting at the table: a plate flies out of the window, he eats.
  sitting,

  /// Up from the table.
  standUp,

  /// 18:00: slowing to a stop, the sword away.
  ending,

  /// Over: he's back to his usual self.
  done,
}

/// His day out as it's drawn (Round 63): Pip in the middle of his room,
/// running, while the ground and what's on it scroll by. Measured in the
/// room's pixels; "world" places move with the ground ([shift]), so a
/// thing at world x is drawn at x − [shift].
class PipRun {
  final math.Random random;

  PipRun(this.random, {required this.x, required this.roomWidth});

  int roomWidth;
  RunPhase phase = RunPhase.running;

  /// Seconds into [phase], and since the start (his steps).
  double t = 0;
  double clock = 0;

  /// How far the ground has moved, and how fast it's moving now.
  double shift = 0;
  double speed = 0;

  /// His left edge on the screen, and which way he faces.
  double x;
  bool facingRight = true;

  /// Moments to feel, taken by his brain.
  final buzzes = <PipBuzz>[];

  static const runSpeed = 20.0;
  static const walkSpeed = PipBrain.speed * 1.3;
  static const cheerTime = 3.0;
  static const drawTime = 0.35;
  static const swingTime = 0.3;
  static const poofTime = 0.35;
  static const knockTime = 0.7;
  static const downTime = 0.5;
  static const pickTime = 0.45;
  static const sheatheTime = 0.4;
  static const plateFlight = 0.6;
  static const standUpTime = 0.4;
  static const endTime = 0.9;

  /// How fast a bug crawls at him, how often they come (seconds, from
  /// the last), and the chance one gets him first.
  static const bugCrawl = 6.0;
  static const bugFrom = 2.5;
  static const bugSpread = 4.0;
  static const hitChance = 0.2;

  /// The middle of the room, where he runs.
  double get centre => math.max(0, roomWidth - PipBrain.width) / 2;

  // Wanted by his life: his break, and the end of the day out.
  bool _wantBreak = false;
  bool _wantEnd = false;

  /// How far through his break (0 to 1): the meal eaten as it goes.
  double breakDone = 0;

  /// His life says: on his break or not (and how far), or over.
  void want({required bool onBreak, double done = 0, bool end = false}) {
    _wantBreak = onBreak;
    breakDone = done;
    _wantEnd = end;
  }

  /// Starts his day out: [cheer] (just registered), else seen ([animate]:
  /// he walks to the middle and draws his sword) or simply running.
  void start({bool cheer = false, required bool animate}) {
    if (cheer) {
      _to(RunPhase.cheer);
    } else if (animate) {
      _to(RunPhase.toCentre);
    } else {
      x = centre;
      speed = runSpeed;
      _to(RunPhase.running);
    }
  }

  /// Seen first while on his break: at the table, eating.
  void seated() {
    tavernAt = shift + _seatX(centre) - seatOffset;
    x = _seatX(centre);
    facingRight = false;
    speed = 0;
    plate = 1;
    _sheathed = true;
    _to(RunPhase.sitting);
  }

  void _to(RunPhase next) {
    phase = next;
    t = 0;
  }

  // A bug: its left edge (world), whether it gets him, running off after.
  double? bugAt;
  bool _hitter = false;
  bool _fleeing = false;
  double _nextBug = bugFrom;
  double _swing = -1;

  // A struck bug's poof: its middle (world) and how far.
  double? _poofAt;
  double _poofT = 0;

  // His sword flying off and lying there: from and to (world).
  double _swordFrom = 0;
  double? swordAt;
  bool _sheathed = false;

  /// The tavern's left edge (world; Round 64), and the plate's flight to
  /// the table (0 to 1; null: not yet).
  double? tavernAt;
  double? plate;

  /// The tavern's size, and where in it: the window's middle, the table,
  /// and his seat (his left edge, from the tavern's left).
  static const tavernWidth = 54;
  static const windowMiddle = 22;
  static const tableLeft = 33;
  static const tableWidth = 10;
  static const tableHeight = 6;
  static const seatOffset = 42;

  double _seatX(double near) => near + 8;

  /// A bug just ahead now (tests and pictures): [hits] him or not.
  @visibleForTesting
  void debugBug({required bool hits}) {
    bugAt = shift + x + PipBrain.width + 14;
    _hitter = hits;
    _fleeing = false;
  }

  /// Moves on by [dt] seconds.
  void step(double dt) {
    t += dt;
    clock += dt;
    shift += speed * dt;
    _stepBug(dt);
    final tavern = tavernAt;
    if (tavern != null && tavern + tavernWidth - shift < -2) tavernAt = null;
    switch (phase) {
      case RunPhase.cheer:
        if (t >= cheerTime) _to(RunPhase.toCentre);
      case RunPhase.toCentre:
        if (_walkTo(centre, dt)) _to(RunPhase.drawing);
      case RunPhase.drawing:
        facingRight = true;
        if (t >= drawTime) {
          _sheathed = false;
          speed = runSpeed;
          _to(RunPhase.running);
        }
      case RunPhase.running:
        _run(dt);
      case RunPhase.knocked:
        final p = (t / knockTime).clamp(0.0, 1.0);
        x = _knockFrom - 12 * p;
        if (t >= knockTime) {
          buzzes.add(PipBuzz.heavy);
          _to(RunPhase.down);
        }
      case RunPhase.down:
        if (t >= downTime) _to(RunPhase.toSword);
      case RunPhase.toSword:
        final at = swordAt ?? shift + x;
        if (_walkTo(at - shift - 1, dt, fast: true)) {
          facingRight = true;
          _to(RunPhase.pickUp);
        }
      case RunPhase.pickUp:
        if (t >= pickTime / 2) swordAt = null;
        if (t >= pickTime) _to(RunPhase.back);
      case RunPhase.back:
        if (_walkTo(centre, dt, fast: true)) {
          facingRight = true;
          if (_sheathed) {
            _to(RunPhase.drawing);
          } else {
            speed = runSpeed;
            _to(RunPhase.running);
          }
        }
      case RunPhase.arriving:
        final seat = tavernAt! + seatOffset - shift;
        if (seat <= _seatX(centre)) {
          speed = 0;
          _to(RunPhase.toSeat);
        }
      case RunPhase.toSeat:
        if (t >= sheatheTime) _sheathed = true;
        if (_walkTo(tavernAt! + seatOffset - shift, dt) && t >= sheatheTime) {
          facingRight = false;
          plate = 0;
          _to(RunPhase.sitting);
        }
      case RunPhase.sitting:
        plate = math.min(1, (plate ?? 0) + dt / plateFlight);
        if (!_wantBreak || _wantEnd) _to(RunPhase.standUp);
      case RunPhase.standUp:
        if (t >= standUpTime) {
          plate = null;
          _to(_wantEnd ? RunPhase.ending : RunPhase.back);
        }
      case RunPhase.ending:
        speed = math.max(0, speed - runSpeed * dt / endTime);
        if (t >= endTime) {
          speed = 0;
          _sheathed = true;
          _to(RunPhase.done);
        }
      case RunPhase.done:
        break;
    }
  }

  double _knockFrom = 0;

  void _run(double dt) {
    speed = runSpeed;
    facingRight = true;
    x = centre;
    if (_wantEnd && _swing < 0) {
      // A bug still coming scurries off.
      if (bugAt != null) _fleeing = true;
      _to(RunPhase.ending);
      return;
    }
    if (_wantBreak && bugAt == null && tavernAt == null) {
      tavernAt = shift + roomWidth + 2;
      _to(RunPhase.arriving);
      return;
    }
    if (_swing >= 0) {
      _swing += dt;
      if (_swing >= swingTime) {
        _swing = -1;
        _poofAt = bugAt! + PipBrain.bugWidth / 2;
        _poofT = 0;
        bugAt = null;
        buzzes.add(PipBuzz.light);
      }
      return;
    }
    final bug = bugAt;
    if (bug == null) {
      _nextBug -= dt;
      if (_nextBug <= 0 && !_wantBreak && !_wantEnd) {
        bugAt = shift + roomWidth;
        _hitter = random.nextDouble() < hitChance;
        _fleeing = false;
        _nextBug = bugFrom + random.nextDouble() * bugSpread;
      }
      return;
    }
    final gap = bug - shift - (x + PipBrain.width);
    if (_hitter && gap <= 1) {
      // It gets him: knocked back, the sword flying off behind him.
      _knockFrom = x;
      speed = 0;
      _swordFrom = shift + x + PipBrain.width;
      swordAt = shift + math.max(2, x - 24);
      _fleeing = true;
      buzzes.add(PipBuzz.medium);
      _to(RunPhase.knocked);
    } else if (!_hitter && gap <= PipBrain.reach) {
      _swing = 0;
    }
  }

  void _stepBug(double dt) {
    if (_poofAt != null) {
      _poofT += dt;
      if (_poofT >= poofTime) _poofAt = null;
    }
    final bug = bugAt;
    if (bug == null) return;
    if (_fleeing) {
      bugAt = bug + bugCrawl * 3 * dt;
      if (bugAt! - shift > roomWidth) bugAt = null;
    } else if (_swing < 0) {
      bugAt = bug - bugCrawl * dt;
    }
  }

  /// Walks to [to]; true once there.
  bool _walkTo(double to, double dt, {bool fast = false}) {
    final distance = (fast ? walkSpeed : PipBrain.speed) * dt;
    if ((to - x).abs() <= distance) {
      x = to;
      return true;
    }
    facingRight = to > x;
    x += to > x ? distance : -distance;
    return false;
  }

  /// Walking or running (his legs step).
  bool get stepping => switch (phase) {
        RunPhase.running || RunPhase.arriving => true,
        RunPhase.ending => speed > 2,
        RunPhase.toCentre ||
        RunPhase.toSword ||
        RunPhase.back ||
        RunPhase.toSeat =>
          true,
        _ => false,
      };

  /// How quick his steps are (1: walking).
  double get stepRate => phase == RunPhase.running ||
          phase == RunPhase.arriving ||
          phase == RunPhase.ending
      ? 1.8
      : phase == RunPhase.toSword || phase == RunPhase.back
          ? 1.3
          : 1;

  /// How high off the ground (a knock's arc, or his seat).
  double get lift => switch (phase) {
        RunPhase.knocked => 7 * math.sin(math.pi * (t / knockTime).clamp(0, 1)),
        RunPhase.sitting => seatHeight,
        RunPhase.standUp => seatHeight * (1 - t / standUpTime) +
            2 * math.sin(math.pi * t / standUpTime),
        _ => 0,
      };

  static const seatHeight = 3.0;

  /// Crouched picking up the sword: 0 to 1.
  double? get crouch => phase == RunPhase.pickUp ? t / pickTime : null;

  /// Tumbling back (radians) as he's knocked.
  double get spin => phase == RunPhase.knocked
      ? -2 * math.pi * (t / knockTime).clamp(0.0, 1.0)
      : 0;

  /// The sword in his hand: (hand x, height, angle, size) on the screen,
  /// as `PipBrain.sword`; null: not in his hand.
  (double, double, double, double)? get sword {
    final hand = facingRight
        ? x + PipBrain.width - PipBrain.bodyInset + 2
        : x + PipBrain.bodyInset - 2;
    final forward = facingRight ? 1.0 : -1.0;
    switch (phase) {
      case RunPhase.cheer:
        // Held up high over his head, pointing at the sky.
        final double size = (t / 0.3).clamp(0.0, 1.0);
        return (x + PipBrain.width / 2, PipBrain.height + 6.0, 0, size);
      case RunPhase.drawing:
        return (hand, 7, forward * 0.3, (t / drawTime).clamp(0.0, 1.0));
      case RunPhase.running || RunPhase.arriving || RunPhase.back:
        if (_sheathed) return null;
        final angle = _swing >= 0
            ? 0.3 + 1.5 * _ease(_swing / swingTime)
            : 0.3 + 0.08 * math.sin(clock * 9);
        return (hand, 7, forward * angle, 1);
      case RunPhase.pickUp when t >= pickTime / 2:
        return (hand, 6, forward * 0.3, 1);
      case RunPhase.toSeat:
        if (_sheathed) return null;
        return (hand, 7, forward * 0.3, 1 - (t / sheatheTime).clamp(0.0, 1.0));
      case RunPhase.ending:
        if (_sheathed) return null;
        return (hand, 7, forward * 0.3, 1 - (t / endTime).clamp(0.0, 1.0));
      default:
        return null;
    }
  }

  /// The sword flying off or lying on the ground: (its middle x, height
  /// above the ground, angle) on the screen; null: in his hand.
  (double, double, double)? get lyingSword {
    final at = swordAt;
    if (at == null) return null;
    if (phase == RunPhase.knocked) {
      final p = (t / knockTime).clamp(0.0, 1.0);
      final sx = _swordFrom + (at - _swordFrom) * p - shift;
      return (sx, 7 + 12 * math.sin(math.pi * p) - 6 * p, -3 * math.pi * p);
    }
    return (at - shift, 1, -math.pi / 2);
  }

  /// The bug: its left edge on the screen, its legs up, walking right
  /// (running off); null: none.
  (double, bool, bool)? get bug {
    final b = bugAt;
    if (b == null) return null;
    return (b - shift, (clock * 8).floor().isEven, _fleeing);
  }

  /// A struck bug's poof: its middle on the screen and 0 → 1.
  (double, double)? get poof {
    final p = _poofAt;
    if (p == null) return null;
    return (p - shift, _poofT / poofTime);
  }

  /// The tavern's left edge on the screen, or null.
  double? get tavern {
    final at = tavernAt;
    return at == null ? null : at - shift;
  }

  /// The plate: (its middle x, height above the ground, meal left 0–1);
  /// flying out of the window to the table, then eaten as his break goes.
  (double, double, double)? get plateAt {
    final p = plate;
    final tav = tavern;
    if (p == null || tav == null) return null;
    final fromX = tav + windowMiddle, fromY = 10.0;
    final toX = tav + tableLeft + tableWidth / 2, toY = tableHeight.toDouble();
    final px = fromX + (toX - fromX) * p;
    final py = fromY + (toY - fromY) * p + 5 * math.sin(math.pi * p);
    return (px, py, phase == RunPhase.sitting ? 1 - breakDone : 0);
  }

  /// A bite now (his mouth open), sitting with his meal.
  bool get biting =>
      phase == RunPhase.sitting &&
      (plate ?? 0) >= 1 &&
      breakDone < 1 &&
      (clock % 3.2) < 0.35;

  static double _ease(double p) {
    final q = p.clamp(0.0, 1.0);
    return q < 0.5 ? 2 * q * q : 1 - math.pow(-2 * q + 2, 2) / 2;
  }
}
