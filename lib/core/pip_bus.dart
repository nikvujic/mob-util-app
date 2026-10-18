import 'dart:math' as math;

import 'package:the_app/core/pip_brain.dart';

/// Where his ski trip's bus is (Round 67).
enum BusPhase {
  /// The bus drives in and stops (he's waiting beside where it stops).
  pullingIn,

  /// Its door opens and he walks in.
  boarding,

  /// The road starts moving.
  departing,

  /// On the road: the bus in the middle, him in a window.
  riding,

  /// The road slows to a stop.
  arriving,

  /// The door opens and he steps out.
  alighting,

  /// The bus drives off.
  pullingOut,

  /// Gone: he's back to his usual self.
  done,
}

/// His ski trip's bus ride as it's drawn (Round 67, the spec's 8.6): the
/// bus in the middle of his room and him in a window while the road and
/// what's beside it move past; setting off and arriving, seen.
class PipBus {
  PipBus({required this.roomWidth, required double pipX}) : _pipX = pipX;

  int roomWidth;
  BusPhase phase = BusPhase.riding;
  double t = 0;

  /// How far the road has moved, and how fast now.
  double road = 0;
  double speed = 0;

  /// The bus's left edge on the screen, and his while he's outside it.
  double busX = 0;
  double _pipX;

  static const width = 56;
  static const height = 24;
  static const roadSpeed = 30.0;
  static const pullTime = 2.0;
  static const doorTime = 0.4;
  static const departTime = 1.5;

  /// Where his window is, from the bus's left edge (his left edge there),
  /// and how high he sits (his feet hidden by the bus).
  static const seatX = 27.0;
  static const seatLift = 6.0;

  /// Where the door is, from the bus's left edge, and how wide.
  static const doorX = 5.0;
  static const doorWidth = 8;

  /// The bus parked in the middle.
  double get middle => (roomWidth - width) / 2;

  /// Seen setting off ([animate]): it pulls in and he boards; else he's
  /// simply on the road.
  void start({required bool animate}) {
    if (animate) {
      busX = -width.toDouble();
      phase = BusPhase.pullingIn;
    } else {
      busX = middle;
      speed = roadSpeed;
      phase = BusPhase.riding;
    }
    t = 0;
  }

  /// Arrived ([animate]: seen slowing, him stepping out, the bus off).
  bool _arrive = false;
  void arrive() => _arrive = true;

  void _to(BusPhase next) {
    phase = next;
    t = 0;
  }

  void step(double dt) {
    t += dt;
    walking = false;
    road += speed * dt;
    switch (phase) {
      case BusPhase.pullingIn:
        final p = (t / pullTime).clamp(0.0, 1.0);
        busX = -width + (middle + width) * (1 - math.pow(1 - p, 2));
        if (t >= pullTime) _to(BusPhase.boarding);
      case BusPhase.boarding:
        // Walking to the door, in, and the door shut.
        final door = busX + doorX + doorWidth / 2 - PipBrain.width / 2;
        final distance = PipBrain.speed * dt;
        if ((door - _pipX).abs() > distance) {
          _pipX += door > _pipX ? distance : -distance;
          facingRight = door > _pipX;
          walking = true;
          t = 0;
        } else {
          _pipX = door;
          if (t >= doorTime * 2) _to(BusPhase.departing);
        }
      case BusPhase.departing:
        speed = roadSpeed * (t / departTime).clamp(0.0, 1.0);
        if (t >= departTime) _to(BusPhase.riding);
      case BusPhase.riding:
        speed = roadSpeed;
        busX = middle;
        if (_arrive) _to(BusPhase.arriving);
      case BusPhase.arriving:
        speed = roadSpeed * (1 - (t / departTime).clamp(0.0, 1.0));
        if (t >= departTime) {
          speed = 0;
          _pipX = busX + doorX + doorWidth / 2 - PipBrain.width / 2;
          _to(BusPhase.alighting);
        }
      case BusPhase.alighting:
        // Out of the door and a few steps away from the bus.
        if (t >= doorTime) {
          final away = busX + width + 4;
          final distance = PipBrain.speed * dt;
          if ((away - _pipX).abs() > distance) {
            _pipX += distance;
            facingRight = true;
            walking = true;
          } else if (t >= doorTime * 3) {
            _to(BusPhase.pullingOut);
          }
        }
      case BusPhase.pullingOut:
        final p = (t / pullTime).clamp(0.0, 1.0);
        busX = middle + (roomWidth - middle) * p * p;
        if (t >= pullTime) _to(BusPhase.done);
      case BusPhase.done:
        break;
    }
  }

  /// Him inside it (in a window), or outside (waiting, walking to the
  /// door, stepping out).
  bool get inside => switch (phase) {
        BusPhase.departing || BusPhase.riding || BusPhase.arriving => true,
        BusPhase.boarding => t >= doorTime,
        BusPhase.alighting => t < doorTime,
        _ => false,
      };

  /// His left edge on the screen: at his window inside, else his own.
  double get pipX => inside ? busX + seatX : _pipX;

  /// Walking (outside, to the door or away), and which way he faces.
  bool walking = false;
  bool facingRight = true;

  /// The door open.
  bool get doorOpen =>
      (phase == BusPhase.boarding && t > 0) ||
      (phase == BusPhase.alighting && t < doorTime * 3);

  /// The bus to draw (gone once it's driven off).
  bool get busShown => phase != BusPhase.done;
}
