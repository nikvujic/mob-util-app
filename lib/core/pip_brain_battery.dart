part of 'pip_brain.dart';

/// Round 138 (out of `pip_brain.dart`): a battery given him (Round 37):
/// dropped where it was tapped, him walking over, a hand pulling the old
/// one out of his side and throwing it away, the new one pushed in (Round
/// 54), or, off, it flying to him and him coming back on.
class _PipBatteryState {
  /// The battery dropped in his room: its left edge, and how high above
  /// the ground it still is (it falls); null when there's none.
  double? left;
  double height = 0;

  /// Where the battery was dropped (a flying one starts there).
  double from = 0;

  /// Seconds into picking it up, once he's there.
  double? picking;

  /// Which side of him the dropped battery is (Round 54).
  bool onRight = true;

  /// Seconds since the dropped battery hit the ground (Round 97: it
  /// bounces once), or null while it falls.
  double? landed;
}

extension PipBrainBattery on PipBrain {
  // Round 37–97: his batteries.

  /// Whether a battery dropped now would be taken (up and about, or
  /// off: it flies to him).
  bool get canTakeBattery =>
      mayStart(activity, PipAnimation.fetch) ||
      mayStart(activity, PipAnimation.powerOn) ||
      // Round 65: out on his adventure, it flies to him as he runs.
      (activity == PipActivity.adventuring && run?.canCatch == true) ||
      // Round 75: in his tent, it flies in (one at a time).
      (activity == PipActivity.sheltering && !_batteryFlying) ||
      // Round 133: at his quest's work, it flies to him there.
      (activity == PipActivity.questing && !_batteryFlying);

  /// A battery dropped at [at] (room pixels from the left): he walks over
  /// and picks it up, or, off, it flies to him and he comes back on.
  bool takeBattery(double at) {
    if (!canTakeBattery) return false;
    // Round 128: at home, on his house's floor.
    final left = (atHome
            ? at.clamp(_minX, _maxX + PipBrain.width - PipBrain.batteryWidth)
            : at.clamp(0, math.max(0, roomWidth - PipBrain.batteryWidth)))
        .toDouble();
    if (activity == PipActivity.adventuring) {
      run!.catchBattery(left);
      return true;
    }
    if (activity == PipActivity.sheltering ||
        activity == PipActivity.questing) {
      _flyBatteryIn(left);
      return true;
    }
    _bt.left = left;
    _bt.from = left;
    _bt.height = PipBrain.dropHeight;
    _bt.landed = null;
    if (activity == PipActivity.off) {
      _start(PipActivity.poweringOn);
      return true;
    }
    _start(PipActivity.fetching);
    _bt.picking = null;
    // Round 54: to stand beside it (it by the hand he'll use), on the
    // side he comes from if there's room there.
    // Round 97: a few pixels off, so the old one pulled out of
    // his side isn't over the new one.
    final rightOf = left + PipBrain.batteryWidth / 2 >= x + PipBrain.width / 2;
    final besideLeft = left -
        (PipBrain.width -
            PipBrain.bodyInset +
            1 +
            PipBrain.batteryGap); // it on his right
    final besideRight = left +
        PipBrain.batteryWidth +
        1 +
        PipBrain.batteryGap -
        PipBrain.bodyInset; // his left
    bool fits(double at) => at >= _minX && at <= _maxX;
    final take = rightOf
        ? (fits(besideLeft) || !fits(besideRight))
        : !fits(besideRight) && fits(besideLeft);
    _bt.onRight = take;
    _target = (take ? besideLeft : besideRight).clamp(_minX, _maxX).toDouble();
    facingRight = _target >= x;
    return true;
  }

  /// A spot a few steps off for a battery to drop at (Round 54: the
  /// preview), on whichever side has room.
  double get _batterySpot {
    final right = x + PipBrain.width - PipBrain.bodyInset + 1 + 20;
    if (right + PipBrain.batteryWidth <= roomWidth) return right;
    final left = x + PipBrain.bodyInset - 1 - PipBrain.batteryWidth - 20;
    return left >= 0
        ? left
        : right.clamp(0, roomWidth - PipBrain.batteryWidth).toDouble();
  }

  /// The battery to draw: its left edge and how high above the ground
  /// (flying to him while he's off), or null.
  (double, double)? get battery {
    if (activity == PipActivity.adventuring) return run?.battery;
    if (activity == PipActivity.sheltering) return _tentBattery;
    if (activity == PipActivity.questing) return _questBattery;
    final b = _bt.left;
    if (b == null) return null;
    if (activity == PipActivity.poweringOn) {
      if (_t >= PipBrain.flyEnd) return null;
      // An arc from where it was dropped to his middle.
      final p = _t / PipBrain.flyEnd;
      final to = _fallRight
          ? x + PipBrain.width + PipBrain.height / 2
          : x - PipBrain.height / 2;
      return (
        _bt.from + (to - PipBrain.batteryWidth / 2 - _bt.from) * p,
        _bt.height * (1 - p) + 18 * math.sin(math.pi * p),
      );
    }
    // Round 54: taken by the hand, carried to his slot, pushed in.
    final p = _bt.picking;
    if (activity == PipActivity.fetching &&
        p != null &&
        p >= PipBrain.grabbed) {
      final out = _slotLeft(out: true);
      if (p < PipBrain.atSlotAgain) {
        final q = PipBrain._ease(
            (p - PipBrain.grabbed) / (PipBrain.atSlotAgain - PipBrain.grabbed));
        return PipBrain._lerp((b, 0), (out, PipBrain.slotUp), q);
      }
      final q = PipBrain._ease(((p - PipBrain.atSlotAgain) /
              (PipBrain.pushedIn - PipBrain.atSlotAgain))
          .clamp(0.0, 1.0));
      return PipBrain._lerp(
          (out, PipBrain.slotUp), (_slotLeft(out: false), PipBrain.slotUp), q);
    }
    final landed = _bt.landed;
    final bounce = landed != null && landed < PipBrain.bounceTime
        ? PipBrain.bounceHeight *
            math.sin(math.pi * landed / PipBrain.bounceTime)
        : 0.0;
    return (b, _bt.height + bounce);
  }

  /// Round 97: a glint on the new battery now and then while it waits on
  /// the ground ((x, height above the ground) of its middle), or null.
  (double, double)? get batteryGlint {
    final b = _bt.left;
    final landed = _bt.landed;
    if (activity != PipActivity.fetching || b == null || landed == null) {
      return null;
    }
    final p = _bt.picking;
    if (p != null && p >= PipBrain.grabbed) return null;
    if (landed % PipBrain.glintEvery >= PipBrain.glintFor) return null;
    return (b + PipBrain.batteryWidth - 1, PipBrain.batteryHeight - 1);
  }

  /// A battery's left edge by his slot: all in (behind his casing) or
  /// out (a pixel off it).
  double _slotLeft({required bool out}) => _bt.onRight
      ? (out
          ? x + PipBrain.width - PipBrain.bodyInset + 1
          : x + PipBrain.width - PipBrain.bodyInset - PipBrain.batteryWidth)
      : (out
          ? x + PipBrain.bodyInset - 1 - PipBrain.batteryWidth
          : x + PipBrain.bodyInset.toDouble());

  /// Where the hand is holding a battery at [left], [up]: at its outer
  /// side ((x, height) of the hand's middle).
  (double, double) _holding(double left, double up) => (
        _bt.onRight ? left + PipBrain.batteryWidth + 1 : left - 1,
        up + PipBrain.batteryHeight / 2,
      );

  /// The old battery, out of his side: its left edge, height above the
  /// ground, how faded (0–1) and turned (flying, end over end); null
  /// while it's in him, and gone.
  (double, double, double, bool)? get oldBattery {
    final p = _bt.picking;
    if (activity != PipActivity.fetching || p == null || p < PipBrain.atSlot) {
      return null;
    }
    final inside = _slotLeft(out: false);
    final out = _slotLeft(out: true);
    if (p < PipBrain.pulledOut) {
      final q = PipBrain._ease(
          (p - PipBrain.atSlot) / (PipBrain.pulledOut - PipBrain.atSlot));
      return (inside + (out - inside) * q, PipBrain.slotUp, 0, false);
    }
    if (p < PipBrain.throwAt) {
      // Lifted, ready to throw.
      final q = PipBrain._ease(
          (p - PipBrain.pulledOut) / (PipBrain.throwAt - PipBrain.pulledOut));
      return (out, PipBrain.slotUp + 4 * q, 0, false);
    }
    final land = _oldBatteryLands;
    final q = (p - PipBrain.throwAt) / PipBrain.throwFlight;
    if (q < 1) {
      // Round 97 (never over the new one): over his head to his
      // other side, end over end.
      return (
        out + (land - out) * q,
        (PipBrain.slotUp + 4) * (1 - q) +
            (PipBrain.height + 6) * math.sin(math.pi * q),
        0,
        (q * 8).floor().isOdd,
      );
    }
    final on = p - PipBrain.throwAt - PipBrain.throwFlight;
    if (on >= PipBrain.landedLies + PipBrain.landedFades) return null;
    // A small hop as it lands, then still, then fading.
    final bounce = on < 0.12 ? 1.0 * math.sin(math.pi * on / 0.12) : 0.0;
    final fade = on < PipBrain.landedLies
        ? 0.0
        : ((on - PipBrain.landedLies) / PipBrain.landedFades).clamp(0, 1);
    return (land, bounce, fade.toDouble(), false);
  }

  /// Where the old battery lands: his other side, a little off.
  double get _oldBatteryLands {
    final at = _bt.onRight
        ? x + PipBrain.bodyInset - 1 - PipBrain.batteryWidth - 8
        : x + PipBrain.width - PipBrain.bodyInset + 1 + 8;
    return at
        .clamp(0, math.max(0, roomWidth - PipBrain.batteryWidth))
        .toDouble();
  }

  /// Round 97: the old battery's landing, a puff of dust: (x, height
  /// above the ground, how faded) for each speck.
  List<(double, double, double)> get batteryDust {
    final p = _bt.picking;
    if (activity != PipActivity.fetching || p == null) return const [];
    final on = p - PipBrain.throwAt - PipBrain.throwFlight;
    if (on < 0 || on >= 0.4) return const [];
    final q = on / 0.4;
    final mid = _oldBatteryLands + PipBrain.batteryWidth / 2;
    return [
      for (final (dx, rise) in const [
        (-1.0, 0.6),
        (1.0, 0.6),
        (-0.6, 1.0),
        (0.6, 1.0)
      ])
        (mid + dx * (3 + 4 * q), rise * 3 * math.sin(math.pi * q), q),
    ];
  }

  /// The slot in his side, open while the batteries go in and out: the
  /// column of his casing it's in, or null.
  double? get batterySlot {
    final p = _bt.picking;
    if (activity != PipActivity.fetching || p == null) return null;
    if (p < PipBrain.handIn || p >= PipBrain.pushedIn + 0.1) return null;
    return _bt.onRight
        ? x + PipBrain.width - PipBrain.bodyInset - 1
        : x + PipBrain.bodyInset;
  }

  /// The hand changing his battery: (x, height of its middle, size).
  (double, double, double)? get _batteryHand {
    final p = _bt.picking;
    if (activity != PipActivity.fetching ||
        p == null ||
        p >= PipBrain.handOut) {
      return null;
    }
    final rest = (handBeside(right: _bt.onRight), 9.0);
    final atOld = _holding(_slotLeft(out: false), PipBrain.slotUp);
    final b = _bt.left;
    final onGround = b == null ? rest : _holding(b, 0);
    if (p < PipBrain.handIn) return (rest.$1, rest.$2, p / PipBrain.handIn);
    if (p < PipBrain.atSlot) {
      final (hx, hy) = PipBrain._lerp(
          rest,
          atOld,
          PipBrain._ease(
              (p - PipBrain.handIn) / (PipBrain.atSlot - PipBrain.handIn)));
      return (hx, hy, 1);
    }
    if (p < PipBrain.throwAt) {
      final (left, up, _, _) = oldBattery!;
      final (hx, hy) = _holding(left, up);
      return (hx, hy, 1);
    }
    if (p < PipBrain.atBattery) {
      final from = _holding(_slotLeft(out: true), PipBrain.slotUp + 4);
      final (hx, hy) = PipBrain._lerp(
          from,
          onGround,
          PipBrain._ease((p - PipBrain.throwAt) /
              (PipBrain.atBattery - PipBrain.throwAt)));
      return (hx, hy, 1);
    }
    if (p < PipBrain.pushedIn) {
      final (left, up) = battery!;
      final (hx, hy) = _holding(left, up);
      return (hx, hy, 1);
    }
    final size =
        1 - (p - PipBrain.pushedIn) / (PipBrain.handOut - PipBrain.pushedIn);
    final (hx, hy) = _holding(_slotLeft(out: false), PipBrain.slotUp);
    return (hx, hy, size.clamp(0.0, 1.0));
  }

  /// A battery here: dropped, flying to him, or in his hand.
  bool get _hasBattery => _bt.left != null;

  /// The battery gone: in him, or a demo's put away.
  void _dropBattery() => _bt.left = null;

  /// Seconds into changing it, once he's beside it; null: on his way.
  double? get _picking => _bt.picking;

  /// The side of him it's on (a hand on that side swaps it).
  bool get _batteryOnRight => _bt.onRight;

  /// Changing his battery, each step: it falls, he hurries over, a hand
  /// swaps it (Round 54); a buzz at each moment felt (Round 98).
  void _stepFetching(double dt) {
    if (_bt.height == 0) {
      _bt.landed = (_bt.landed ?? 0) + dt;
      // Round 98: down again after its bounce.
      if (PipBrain._passed(PipBrain.bounceTime, _bt.landed!, dt)) {
        _buzzes.add(PipBuzz.light);
      }
    }
    final falling = _bt.height > 0;
    _bt.height = math.max(0, _bt.height - PipBrain.fallSpeed * dt);
    // Round 98: the battery drop.
    if (falling && _bt.height == 0) _buzzes.add(PipBuzz.medium);
    final picking = _bt.picking;
    if (picking == null) {
      final distance = PipBrain.hurry * dt;
      if ((_target - x).abs() <= distance) {
        x = _target;
        if (_bt.height == 0) {
          _bt.picking = 0;
          facingRight = _bt.onRight;
        }
      } else {
        x += _target > x ? distance : -distance;
      }
    } else {
      final p = _bt.picking = picking + dt;
      // Round 98: the old one pulled out, landing with its clunk; the
      // new one clicking in; down from his hop of joy.
      for (final (at, buzz) in const [
        (PipBrain.pulledOut, PipBuzz.light),
        (PipBrain.throwAt + PipBrain.throwFlight, PipBuzz.medium),
        (PipBrain.pushedIn, PipBuzz.heavy),
        (PipBrain.pickEnd, PipBuzz.light),
      ]) {
        if (PipBrain._passed(at, p, dt)) _buzzes.add(buzz);
      }
      if (_bt.picking! >= PipBrain.pushedIn) _bt.left = null;
      if (_bt.picking! >= PipBrain.pickEnd) _stand();
    }
  }
}
