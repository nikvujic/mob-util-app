part of 'pip_brain.dart';

/// Round 138 (out of `pip_brain.dart`): what happens in his field now and
/// then while he stands about (Round 52): a shooting star at dusk, bugs
/// he fights off, a flower he picks, a butterfly, a ball.
class _PipEventsState {
  // A shooting star.
  bool starFromLeft = true;
  int bugsLeft = 0;
  double? bugX;
  bool bugFromRight = true;

  /// 0 the sword pops in, 1 the bug crawls (he goes for it), 2 the
  /// swing, 3 the poof; [_phaseT] seconds into it.
  int bugPhase = 0;
  double phaseT = 0;
  double flowerX = 0;

  /// 0 it comes up, 1 he walks over, 2 he picks it, 3 he holds it, 4 it
  /// fades.
  int flowerPhase = 0;
  double flyX = 0;
  double flyFrom = 0;
  bool flyRight = true;
  double ballX = 0;
  double ballUp = 0;
  double ballSpeed = 0;
  double ballVy = 0;

  /// 0 it rolls in, 1 he walks up to it, 2 the kick, 3 it flies off.
  int ballPhase = 0;
}

extension PipBrainEvents on PipBrain {
  // Round 52: events, now and then while he stands about.

  /// Room enough for an event (something coming in, him going to it).
  bool get _eventRoom => roomWidth >= 3 * PipBrain.width + 10;

  /// Something happens instead of a walk, sometimes: not with the
  /// station up, and not at bedtime. True if it did.
  bool _maybeEvent() {
    if (!_eventRoom || _wantsStation || _bedtime) return false;
    if (random.nextDouble() >= PipBrain.eventChance) return false;
    // Round 128: in his house, its own.
    if (atHome) return _maybeHomeEvent();
    // Round 75: mostly the weather's, while it's doing something.
    if (_maybeWeatherEvent()) return true;
    // At dusk or night, now and then a shooting star (Round 70: not
    // under a grey sky).
    if (dark && !overcast && random.nextInt(4) == 0) {
      play(PipAnimation.shootingStar);
      return true;
    }
    final pick = random.nextInt(9);
    switch (pick) {
      case 0 || 1:
        _startBugs();
      // Round 70: no flowers or butterflies in rain, snow or winter.
      case 2 || 3 when !bleak:
        _startFlower();
      case 4 || 5 when !bleak:
        _startButterfly();
      case 2 || 3 || 4 || 5:
        _startBugs();
      case 6 || 7:
        _startBall();
      default:
        _start(PipActivity.dancing);
    }
    return true;
  }

  bool get shootingStarFromLeft => _ev.starFromLeft;

  /// The shooting star: (x, rows down from the top of the sky, how far
  /// across 0–1); null when there's none.
  (double, double, double)? get shootingStar {
    if (activity != PipActivity.stargazing || _t >= PipBrain.starTime) {
      return null;
    }
    final p = _t / PipBrain.starTime;
    final from = _ev.starFromLeft ? roomWidth * 0.1 : roomWidth * 0.9;
    final to = _ev.starFromLeft ? roomWidth * 0.75 : roomWidth * 0.25;
    return (from + (to - from) * p, 4 + skyRows * 0.25 * p, p);
  }

  // Bugs.

  void _startBugs() {
    _ev.bugsLeft = 1 + random.nextInt(3);
    _start(PipActivity.bugHunt);
    _nextBug();
    _ev.bugPhase = 0;
  }

  void _nextBug() {
    _ev.bugFromRight = random.nextBool();
    _ev.bugX =
        _ev.bugFromRight ? roomWidth.toDouble() : -PipBrain.bugWidth.toDouble();
    _ev.bugPhase = 1;
    _ev.phaseT = 0;
  }

  /// Where he swings from: his side facing the bug.
  double get _swordSide => facingRight ? x + PipBrain.width : x;

  bool get _bugWalking => _ev.bugPhase == 1 && !_bugInReach && _ev.bugX != null;

  bool get _bugInReach {
    final b = _ev.bugX;
    if (b == null) return false;
    final near = facingRight ? b : b + PipBrain.bugWidth;
    return (near - _swordSide).abs() <= PipBrain.reach &&
        (facingRight == (b > x));
  }

  void _stepBugs(double dt) {
    _ev.phaseT += dt;
    final b = _ev.bugX;
    switch (_ev.bugPhase) {
      case 0: // the sword pops in
        if (_ev.phaseT >= PipBrain.swordIn) {
          _ev.bugPhase = 1;
          _ev.phaseT = 0;
        }
      case 1: // the bug crawls in; he hurries at it
        if (b == null) return;
        final towards =
            b + PipBrain.bugWidth / 2 > x + PipBrain.width / 2 ? 1 : -1;
        _ev.bugX = b - towards * PipBrain.bugSpeed * dt;
        facingRight = towards > 0;
        if (_bugInReach) {
          _ev.bugPhase = 2;
          _ev.phaseT = 0;
        } else if ((b - x).abs() > PipBrain.width) {
          // Up to it, but not off his field.
          x = (x + towards * PipBrain.hurry * dt)
              .clamp(_minX, _maxX)
              .toDouble();
        }
      case 2: // the swing
        if (_ev.phaseT >= PipBrain.swingTime) {
          _ev.bugPhase = 3;
          _ev.phaseT = 0;
          _buzzes.add(PipBuzz.light); // struck
        }
      case 3: // the poof
        if (_ev.phaseT >= PipBrain.poofTime) {
          _ev.bugsLeft--;
          if (_ev.bugsLeft > 0) {
            _nextBug();
          } else {
            _ev.bugX = null;
            _ev.bugPhase = 4;
            _ev.phaseT = 0;
          }
        }
      default: // all gone: proud a moment, the sword away
        if (_ev.phaseT >= 1.6) _stand();
    }
  }

  /// The bug: its left edge and whether its legs are up (they step);
  /// null when there's none (or it's gone in a poof).
  (double, bool, bool)? get bug {
    if (activity == PipActivity.adventuring) return _out.run?.bug;
    final b = _ev.bugX;
    if (activity != PipActivity.bugHunt || b == null || _ev.bugPhase == 3) {
      return null;
    }
    // Mirrored going right (it comes from his left).
    return (
      b,
      (_t * 8).floor().isEven,
      b + PipBrain.bugWidth / 2 < x + PipBrain.width / 2
    );
  }

  /// The poof where a bug was struck: its middle and 0 → 1.
  (double, double)? get poof {
    if (activity == PipActivity.adventuring) return _out.run?.poof;
    if (activity != PipActivity.bugHunt || _ev.bugPhase != 3) return null;
    return (
      (_ev.bugX ?? x) + PipBrain.bugWidth / 2,
      _ev.phaseT / PipBrain.poofTime
    );
  }

  /// His sword (Round 52, for the adventures later): held in a floating
  /// hand at (x, height above the ground), its angle (0 up, pointing
  /// forward as it grows) and size (popping in and away); null when put
  /// away.
  (double, double, double, double)? get sword {
    if (activity == PipActivity.adventuring) return _out.run?.sword;
    // Round 127: felling a tree, breaking stone: swing after swing.
    if (questView?.swing case final swing?) {
      final forward = facingRight ? 1.0 : -1.0;
      final angle = swing < 0.5
          ? forward * (0.3 + 1.5 * PipBrain._ease(swing * 2))
          : forward * (1.8 - 1.5 * PipBrain._ease((swing - 0.5) * 2));
      return (handBeside(right: facingRight), 7, angle, 1);
    }
    if (activity != PipActivity.bugHunt) return null;
    // Round 53: held out in front, pointing up and away from him.
    // Round 54: a little closer to him.
    final hand = handBeside(right: facingRight);
    final double size = switch (_ev.bugPhase) {
      0 => (_ev.phaseT / PipBrain.swordIn).clamp(0.0, 1.0),
      4 => (1 - (_ev.phaseT - 1.0) / 0.4).clamp(0.0, 1.0),
      _ => 1,
    };
    final forward = facingRight ? 1.0 : -1.0;
    final double angle = switch (_ev.bugPhase) {
      2 =>
        forward * (0.3 + 1.5 * PipBrain._ease(_ev.phaseT / PipBrain.swingTime)),
      3 => forward * 1.8,
      _ => forward * 0.3, // raised, ready, leaning forward
    };
    return (hand, 7, angle, size);
  }

  // A flower.

  void _startFlower() {
    // Somewhere a few steps away, inside his field.
    final max = _maxX;
    var at = x;
    for (var i = 0; i < 12 && (at - x).abs() < 12; i++) {
      at = random.nextDouble() * max;
    }
    if ((at - x).abs() < 12) at = x < max / 2 ? max : 0;
    _ev.flowerX = at + PipBrain.width / 2 - 1;
    _target = at;
    _ev.flowerPhase = 0;
    _start(PipActivity.flower);
  }

  void _stepFlower(double dt) {
    switch (_ev.flowerPhase) {
      case 0:
        if (_t >= PipBrain.sproutTime) {
          _ev.flowerPhase = 1;
          facingRight = _target > x;
          _t = 0;
        }
      case 1:
        final distance = pace * dt;
        if ((_target - x).abs() <= distance) {
          x = _target;
          _ev.flowerPhase = 2;
          _t = 0;
        } else {
          x += _target > x ? distance : -distance;
        }
      case 2:
        if (_t >= PipBrain.flowerPick) {
          _buzzes.add(PipBuzz.light); // Round 98: picked
          _ev.flowerPhase = 3;
          _t = 0;
        }
      case 3:
        if (_t >= PipBrain.flowerHold) {
          _ev.flowerPhase = 4;
          _t = 0;
        }
      default:
        if (_t >= PipBrain.flowerFade) _stand();
    }
  }

  /// The flower: (x, height above the ground of its stem's foot, grown
  /// 0–1, faded 0–1); in the ground until picked, then in his hand.
  (double, double, double, double)? get flower {
    if (activity != PipActivity.flower) return null;
    return switch (_ev.flowerPhase) {
      0 => (_ev.flowerX, 0, (_t / PipBrain.sproutTime).clamp(0.0, 1.0), 0),
      1 || 2 => (_ev.flowerX, 0, 1, 0),
      _ => (
          // Round 53: its stem down in his hand.
          handBeside(right: facingRight) - 2,
          4,
          1,
          _ev.flowerPhase == 4 ? (_t / PipBrain.flowerFade).clamp(0.0, 1.0) : 0,
        ),
    };
  }

  /// The hand holding the flower: (x, height), or null.
  (double, double)? get flowerHand {
    if (activity != PipActivity.flower || _ev.flowerPhase < 3) return null;
    return (handBeside(right: facingRight) - 1, 5);
  }

  // A butterfly.

  void _startButterfly() {
    _ev.flyRight = random.nextBool();
    _ev.flyFrom = _ev.flyRight ? -6.0 : roomWidth + 1.0;
    _ev.flyX = _ev.flyFrom;
    _start(PipActivity.butterfly);
  }

  void _stepButterfly(double dt) {
    _ev.flyX += (_ev.flyRight ? 1 : -1) * PipBrain.butterflySpeed * dt;
    // He watches it: turned towards it.
    facingRight = _ev.flyX + 2 > x + PipBrain.width / 2;
    if (_ev.flyRight ? _ev.flyX > roomWidth + 2 : _ev.flyX < -8) _stand();
  }

  bool get _butterflyClose =>
      activity == PipActivity.butterfly &&
      (_ev.flyX + 2 - (x + PipBrain.width / 2)).abs() < PipBrain.width;

  /// The butterfly: (x, height above the ground, wings up); null when
  /// there's none. It bobs as it goes.
  (double, double, bool)? get butterfly {
    if (activity != PipActivity.butterfly) return null;
    final up = 24 + 4 * math.sin(_t * 3) + 2 * math.sin(_t * 7.3);
    return (_ev.flyX, up, (_t * 6).floor().isEven);
  }

  // A ball.

  void _startBall() {
    final fromRight = random.nextBool();
    _ev.ballX =
        fromRight ? roomWidth.toDouble() : -PipBrain.ballSize.toDouble();
    _ev.ballSpeed = fromRight ? -26 : 26;
    _ev.ballUp = 0;
    _ev.ballVy = 0;
    _ev.ballPhase = 0;
    _start(PipActivity.ball);
  }

  void _stepBall(double dt) {
    switch (_ev.ballPhase) {
      case 0:
        // Slowing as it rolls; it stops on its own.
        _ev.ballX += _ev.ballSpeed * dt;
        _ev.ballSpeed *= math.pow(0.45, dt).toDouble();
        if (_ev.ballSpeed.abs() < 3) {
          _ev.ballSpeed = 0;
          _ev.ballPhase = 1;
          // Beside it, the side it came from... facing it.
          final behind =
              _ev.ballX + PipBrain.ballSize / 2 > x + PipBrain.width / 2;
          _target = (behind
                  ? _ev.ballX - PipBrain.width + 1
                  : _ev.ballX + PipBrain.ballSize - 1)
              .clamp(0, _maxX)
              .toDouble();
          facingRight = _target < _ev.ballX;
          if ((_target - x).abs() > 0.5) facingRight = _target > x;
        }
      case 1:
        final distance = pace * dt;
        if ((_target - x).abs() <= distance) {
          x = _target;
          facingRight =
              _ev.ballX + PipBrain.ballSize / 2 > x + PipBrain.width / 2;
          _ev.ballPhase = 2;
          _t = 0;
        } else {
          x += _target > x ? distance : -distance;
        }
      case 2:
        if (_t >= PipBrain.kickTime) {
          _buzzes.add(PipBuzz.medium); // the kick
          _ev.ballPhase = 3;
          _ev.ballSpeed = facingRight ? 55 : -55;
          _ev.ballVy = 45;
          _t = 0;
        }
      default:
        _ev.ballX += _ev.ballSpeed * dt;
        _ev.ballVy -= PipBrain.gravity * dt;
        _ev.ballUp += _ev.ballVy * dt;
        if (_ev.ballUp < 0) {
          _ev.ballUp = 0;
          // Round 98: a buzz on each bounce that's still a bounce.
          if (_ev.ballVy < -PipBrain.ballBuzzSpeed) _buzzes.add(PipBuzz.light);
          _ev.ballVy = -_ev.ballVy * 0.5; // a bounce
        }
        if (_ev.ballX > roomWidth + 2 || _ev.ballX < -PipBrain.ballSize - 2) {
          _stand();
        }
    }
  }

  /// The ball: (left edge, height above the ground, which way it's
  /// turned 0–3); null when there's none.
  (double, double, int)? get ball {
    if (activity != PipActivity.ball) return null;
    return (_ev.ballX, _ev.ballUp, (_ev.ballX / 2).floor() % 4);
  }
}
