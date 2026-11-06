part of 'pip_brain.dart';

/// Round 138 (out of `pip_brain.dart`): his charging station (Round 44):
/// it rising where he is, him hurrying over, plugging in, charging (a
/// segment every few seconds watched), unplugging; and its drone (Round
/// 58) beaming a segment into him when he's off.
class _PipStationState {
  /// The phone plugged in (from his room, checked every second).
  bool phonePlugged = false;

  /// The demo (Pip Home's list): seconds charging so far, or null.
  double? demoCharge;

  /// The station's left edge (null: none), how far up it is (0 in the
  /// ground, 1 up), and which way it's going (1 rising, −1 sinking).
  double? x;
  double up = 0;
  int dir = 0;
  bool right = true;

  /// The drone's trip: its leg, and seconds into it (null: in the
  /// station).
  DronePhase? dronePhase;
  double droneT = 0;

  /// Where its leg of the trip began (its left, its bottom's height).
  (double, double) droneFrom = (0, 0);

  /// It charged him: taken once by the room, which tells his life.
  bool droneCharged = false;

  /// What his screen shows while he charges, and seconds into it.
  ChargeScreen screen = ChargeScreen.happy;
  double screenT = 0;
  double screenFor = 0;

  /// Seconds the station's been up (its lamp blinks on it).
  double clock = 0;
}

extension PipBrainStation on PipBrain {
  bool get phonePlugged => _st.phonePlugged;
  set phonePlugged(bool value) => _st.phonePlugged = value;

  // Round 44: his charging station.

  /// Whether the station should be up: the phone plugged in, or a demo.
  bool get _wantsStation => phonePlugged || _st.demoCharge != null;

  /// The station: its left edge, how far up (0 to 1), and whether its
  /// socket faces left (it's on his right); null when there's none.
  (double, double, bool)? get station {
    final sx = _st.x;
    if (sx == null) return null;
    return (sx, _st.up, _st.right);
  }

  /// The station rising or sinking now.
  bool get stationMoving => _st.dir != 0;

  /// Which side of him the station is on (it rises on the side with more
  /// room, so never on top of him).
  bool get stationOnRight => _st.right;

  /// Room for the station and him beside it, with some to spare.
  /// The station's spot: on the side of him with more room, at his
  /// room's edge (Round 128: or his house's wall).
  void _placeStation() {
    final low = atHome ? PipBrain.homeLeft : 0.0;
    final high = atHome ? PipBrain.homeRight : roomWidth.toDouble();
    _st.right = x + PipBrain.width / 2 <= (low + high) / 2;
    _st.x = _st.right ? high - PipBrain.stationWidth - 4 : low + 4;
  }

  bool get _stationFits =>
      roomWidth >=
      2 * PipBrain.width + PipBrain.stationWidth + PipBrain.stationGap + 8;

  /// Where he stands to plug in.
  double get _plugX => _st.right
      ? _st.x! - PipBrain.stationGap - PipBrain.width
      : _st.x! + PipBrain.stationWidth + PipBrain.stationGap;

  /// The phone plugged in or not, as now known; [animate]: seen happening
  /// (the station rises or sinks, he plugs in or out), else made so at
  /// once (the app opened while charging: he's simply there, charging).
  void setPlugged(bool plugged, {bool animate = true}) {
    if (plugged == phonePlugged && (_st.x != null) == _wantsStation) {
      return;
    }
    phonePlugged = plugged;
    // A demo going on: it ends on its own.
    if (_st.demoCharge != null) return;
    _setStation(plugged, animate: animate);
  }

  void _setStation(bool up, {required bool animate}) {
    if (up) {
      if (!_stationFits) return;
      if (_st.x == null) {
        // The side with more room: never on top of him.
        _placeStation();
        _st.up = animate ? 0 : 1;
        _st.dir = animate ? 1 : 0;
      } else if (_st.dir < 0) {
        _st.dir = 1; // sinking: back up
      }
      // Round 55: a medicine due, he reminds first (and goes after).
      if (!animate && _goesCharging && !medicineDue) {
        // Simply there, charging.
        x = _plugX;
        facingRight = _st.right;
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
    animate ? _sinkStation() : _st.x = null;
  }

  void _sinkStation() {
    if (_st.x == null) return;
    _st.dir = -1;
  }

  void _startUnplugging() {
    _start(PipActivity.unplugging);
    facingRight = _st.right;
  }

  void _stepStation(double dt) {
    _st.clock += dt;
    if (_st.x == null || _st.dir == 0) return;
    _st.up += _st.dir * dt / PipBrain.stationRise;
    if (_st.up >= 1) {
      _st.up = 1;
      _st.dir = 0;
    } else if (_st.up <= 0) {
      _st.x = null;
      _st.up = 0;
      _st.dir = 0;
    }
  }

  // Round 58: off with the phone plugged in, the station's drone flies
  // over and charges him a segment; then he's up and walks over to plug
  // in as ever.

  /// Where it starts and ends: in the station's top.
  (double, double) get _droneHome => (
        _st.x! + (PipBrain.stationWidth - PipBrain.droneWidth) / 2,
        PipBrain.stationHeight - PipBrain.droneHeight.toDouble(),
      );

  /// Over the station, before going down into it (or after coming up).
  (double, double) get _droneAbove =>
      (_droneHome.$1, PipBrain.stationHeight + 4.0);

  /// Over his middle, lying there.
  (double, double) get _droneOver {
    final middle = _fallRight
        ? x + PipBrain.width + PipBrain.height / 2
        : x - PipBrain.height / 2;
    return (
      (middle - PipBrain.droneWidth / 2)
          .clamp(0, math.max(0, roomWidth - PipBrain.droneWidth))
          .toDouble(),
      PipBrain.droneHover,
    );
  }

  /// Whether it would set off now: he's off (for real, not a demo), the
  /// phone plugged in, the station up and still (at night too: off, his
  /// life says off whatever the hour; charged, he then goes to sleep).
  bool get droneDue =>
      _st.dronePhase == null &&
      activity == PipActivity.off &&
      !_demo &&
      // Up only while the phone's plugged in (or a demo, never while
      // he's off).
      _st.x != null &&
      _st.dir == 0;

  /// The drone to draw: its left, its bottom's height, and whether it
  /// beams down on him; null when it's in the station.
  (double, double, bool)? get drone {
    final phase = _st.dronePhase;
    if (phase == null || _st.x == null) return null;
    final (from, to, length) = switch (phase) {
      DronePhase.rising => (_droneHome, _droneAbove, PipBrain.droneRise),
      DronePhase.out => (_st.droneFrom, _droneOver, PipBrain.droneOut),
      DronePhase.beaming => (_droneOver, _droneOver, PipBrain.droneBeam),
      DronePhase.back => (_st.droneFrom, _droneAbove, PipBrain.droneBack),
      DronePhase.sinking => (_droneAbove, _droneHome, PipBrain.droneSink),
    };
    final p = PipBrain._ease((_st.droneT / length).clamp(0.0, 1.0));
    // An arc on the long legs; a little bob while beaming.
    final arc = phase == DronePhase.out || phase == DronePhase.back
        ? 8 * math.sin(math.pi * p)
        : phase == DronePhase.beaming
            ? math.sin(_st.droneT * 9)
            : 0.0;
    return (
      from.$1 + (to.$1 - from.$1) * p,
      from.$2 + (to.$2 - from.$2) * p + arc,
      phase == DronePhase.beaming,
    );
  }

  /// Its rotors' turn: two ways, quickly in turn.
  bool get droneSpin => (_st.droneT * 12).floor().isEven;

  /// The drone's charge, once: true if it charged him since last asked.
  bool takeDroneCharge() {
    final charged = _st.droneCharged;
    _st.droneCharged = false;
    return charged;
  }

  /// Sets it off at once, if it's due (also with his room not moving:
  /// then simply done, him back on).
  bool sendDrone({bool animate = true}) {
    if (!droneDue) return false;
    if (!animate) {
      _droneCharge();
      return true;
    }
    _st.dronePhase = DronePhase.rising;
    _st.droneT = 0;
    return true;
  }

  /// It charged him a segment: he comes back on (no battery to fly in).
  void _droneCharge() {
    _st.droneCharged = true;
    _start(PipActivity.poweringOn);
    _t = PipBrain.flyEnd;
  }

  void _droneLeg(DronePhase next) {
    final at = drone;
    _st.droneFrom = at == null ? _droneAbove : (at.$1, at.$2);
    _st.dronePhase = next;
    _st.droneT = 0;
  }

  void _stepDrone(double dt) {
    if (_st.dronePhase == null && droneDue) sendDrone();
    final phase = _st.dronePhase;
    if (phase == null) return;
    // The station gone (unplugged): so is the drone.
    if (_st.x == null || _st.dir < 0) {
      _st.dronePhase = null;
      return;
    }
    _st.droneT += dt;
    // On by other means meanwhile (a battery): it goes home.
    final waiting = phase == DronePhase.rising ||
        phase == DronePhase.out ||
        phase == DronePhase.beaming;
    if (waiting && activity != PipActivity.off) {
      _droneLeg(DronePhase.back);
      return;
    }
    switch (phase) {
      case DronePhase.rising when _st.droneT >= PipBrain.droneRise:
        _droneLeg(DronePhase.out);
      case DronePhase.out when _st.droneT >= PipBrain.droneOut:
        _droneLeg(DronePhase.beaming);
      case DronePhase.beaming when _st.droneT >= PipBrain.droneBeam:
        _droneCharge();
        _droneLeg(DronePhase.back);
      case DronePhase.back when _st.droneT >= PipBrain.droneBack:
        _droneLeg(DronePhase.sinking);
      case DronePhase.sinking when _st.droneT >= PipBrain.droneSink:
        _st.dronePhase = null;
      default:
    }
  }

  /// He'd go and plug in now: the station up, he isn't full (it's for
  /// looks: he ignores it full), or it's a demo; not at bedtime.
  bool get _goesCharging =>
      _st.x != null &&
      _wantsStation &&
      !_bedtime &&
      // Round 58: empty, he's off: the drone sees to him first.
      segments > 0 &&
      (segments < 3 || _st.demoCharge != null) &&
      (activity == PipActivity.standing ||
          activity == PipActivity.walking ||
          activity == PipActivity.spawning);

  /// Standing about with the station up and wanted: off he hurries.
  void _maybeCharge() {
    if (_st.dir != 0 || !_goesCharging) return;
    _target = _plugX;
    if ((_target - x).abs() < 0.5) {
      x = _target;
      facingRight = _st.right;
      _start(PipActivity.plugging);
      return;
    }
    facingRight = _target > x;
    _start(PipActivity.toStation);
  }

  void _nextScreen() {
    final others = [
      for (final s in ChargeScreen.values)
        if (s != _st.screen) s,
    ];
    _st.screen = others[random.nextInt(others.length)];
    _st.screenT = 0;
    // A demo shows more of them.
    _st.screenFor = _st.demoCharge != null ? 1.5 : 4 + random.nextDouble() * 3;
  }

  /// Shows [screen], [t] seconds in (for tests and pictures).
  @visibleForTesting
  void debugScreen(ChargeScreen screen, double t) {
    _st.screen = screen;
    _st.screenT = t;
    _st.screenFor = 100;
  }

  /// While charging: what his screen shows, and how far into it.
  (ChargeScreen, double)? get chargeScreen =>
      activity == PipActivity.charging ? (_st.screen, _st.screenT) : null;

  /// The station's lamp: blinking slowly while it's up.
  bool get stationLamp => _st.clock % 1.2 < 0.6;

  /// His port (where the plug goes) and the station's hook and socket, as
  /// (x, height above the ground) in room pixels.
  (double, double) get _port =>
      (_st.right ? x + PipBrain.width - 2 : x, PipBrain.portUp);
  (double, double) get _hook => (
        _st.right ? _st.x! - 3 : _st.x! + PipBrain.stationWidth + 1,
        PipBrain.hookUp,
      );
  (double, double) get socket => (
        _st.right ? _st.x! - 1 : _st.x! + PipBrain.stationWidth,
        PipBrain.socketUp,
      );

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
      return [
        (px - 1, py - 0.5, size),
        (px + PipBrain.plateWidth - 1, py - 0.5, size)
      ];
    }
    final plugging = activity == PipActivity.plugging;
    if (!plugging && activity != PipActivity.unplugging) return const [];
    // Round 54: close by his side (a pixel off it), only the one he uses.
    final near = handBeside(right: _st.right) - 1;
    const rest = 8.0;
    final double size;
    if (_t < PipBrain.mittsInEnd) {
      size = _t / PipBrain.mittsInEnd;
    } else {
      final out = plugging ? PipBrain.pushEnd : PipBrain.hangEnd;
      final end = plugging ? PipBrain.plugEnd : PipBrain.unplugEnd;
      size = _t < out ? 1 : 1 - ((_t - out) / (end - out)).clamp(0.0, 1.0);
    }
    final hand = _plugPoint ?? (near, rest);
    // Before it takes the plug, and after it lets go: on its way.
    final (hx, hy) = switch (plugging) {
      true when _t < PipBrain.toHookEnd => PipBrain._lerp(
          (near, rest),
          (_hook.$1, _hook.$2 - 1),
          PipBrain._ease((_t - PipBrain.mittsInEnd) /
              (PipBrain.toHookEnd - PipBrain.mittsInEnd)),
        ),
      false when _t < PipBrain.toPortEnd => PipBrain._lerp(
          (near, rest),
          (_port.$1, _port.$2 - 2),
          PipBrain._ease((_t - PipBrain.mittsInEnd) /
              (PipBrain.toPortEnd - PipBrain.mittsInEnd)),
        ),
      _ when _plugPoint != null => (hand.$1, hand.$2 - 2),
      _ => (near, rest),
    };
    return [(hx, hy, size)];
  }

  /// Where the plug is (x, height above the ground) while a hand carries
  /// it; null when it's on the hook or in his side ([plug] says).
  (double, double)? get _plugPoint {
    if (activity == PipActivity.plugging &&
        _t >= PipBrain.toHookEnd &&
        _t < PipBrain.carryEnd) {
      final p = _t < PipBrain.grabEnd
          ? 0.0
          : (_t - PipBrain.grabEnd) / (PipBrain.carryEnd - PipBrain.grabEnd);
      return PipBrain._lerp(_hook, _port, PipBrain._ease(p));
    }
    if (activity == PipActivity.unplugging &&
        _t >= PipBrain.pullEnd &&
        _t < PipBrain.backEnd) {
      return PipBrain._lerp(
          _port,
          _hook,
          PipBrain._ease(
              (_t - PipBrain.pullEnd) / (PipBrain.backEnd - PipBrain.pullEnd)));
    }
    return null;
  }

  /// The plug (x, height above the ground): on the hook, carried, or in
  /// his side; null without a station.
  (double, double)? get plug {
    if (_st.x == null) return null;
    final carried = _plugPoint;
    if (carried != null) return carried;
    final inPort = switch (activity) {
      PipActivity.charging => true,
      PipActivity.plugging => _t >= PipBrain.carryEnd,
      PipActivity.unplugging => _t < PipBrain.pullEnd,
      _ => false,
    };
    return inPort ? _port : _hook;
  }

  /// Sparks at the plug: pushed in, and the charging screen that has
  /// them; each (x, height above the ground).
  List<(double, double)> get sparks {
    final pushing = activity == PipActivity.plugging &&
        _t >= PipBrain.carryEnd &&
        _t < PipBrain.pushEnd;
    final screen = activity == PipActivity.charging &&
        _st.screen == ChargeScreen.sparks &&
        (_st.screenT * 6).floor().isEven;
    final p = _picking;
    if (activity == PipActivity.fetching && p != null) {
      // Round 97: a crackle at his slot as the new one clicks in.
      if (p >= PipBrain.pushedIn && p < PipBrain.pushedIn + PipBrain.sparkFor) {
        final q = (p - PipBrain.pushedIn) / PipBrain.sparkFor;
        final side = _batteryOnRight ? 1.0 : -1.0;
        final sx = _batteryOnRight
            ? x + PipBrain.width - PipBrain.bodyInset
            : x + PipBrain.bodyInset - 1;
        final sy = PipBrain.slotUp + PipBrain.slotRows / 2;
        return [
          for (final (dx, dy) in const [
            (1.0, 1.0),
            (1.0, -1.0),
            (1.4, 0.0),
            (0.4, 1.6),
            (0.4, -1.6)
          ])
            (sx + side * dx * (1 + 4 * q), sy + dy * (1 + 3 * q)),
        ];
      }
      // Round 97: sparkles round him as he hops for joy.
      if (p >= PipBrain.shakeEnd && p < PipBrain.pickEnd) {
        final q =
            (p - PipBrain.shakeEnd) / (PipBrain.pickEnd - PipBrain.shakeEnd);
        final mid = x + PipBrain.width / 2;
        return [
          for (final (dx, up) in const [
            (-1.0, 0.3),
            (1.0, 0.3),
            (-0.7, 1.0),
            (0.7, 1.0)
          ])
            (
              mid + dx * (PipBrain.width / 2 + 2 + 4 * q),
              6 + up * (PipBrain.height - 4) + 4 * q
            ),
        ];
      }
    }
    if (!pushing && !screen) return const [];
    final (px, py) = _port;
    final out = _st.right ? 1.0 : -1.0;
    final t = (_t * 10).floor();
    return [
      for (var i = 0; i < 4; i++)
        (px + out * (2 + (t + i * 3) % 4), py + (i.isEven ? 2 : -1) + i % 2),
    ];
  }

  /// Humming (a charging screen): little notes floating up, each (x from
  /// his middle, y above his head, how faded 0–1).
  List<(double, double, double)> get notes {
    if (activity != PipActivity.charging ||
        _st.screen != ChargeScreen.humming) {
      return const [];
    }
    return [
      for (var i = 0; i < 2; i++)
        if (((_st.screenT / 2.2 + i / 2) % 1) case final p)
          ((i.isEven ? 5 : -7) + 3 * p, 2 + 10 * p, p),
    ];
  }
}
