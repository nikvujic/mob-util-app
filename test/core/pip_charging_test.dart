import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';

/// Pip's charging station (Round 44).
void main() {
  /// Pip up and about (out of the ground), [segments] of energy.
  PipBrain up({int width = 120, int segments = 2, double? x}) {
    final p = PipBrain(roomWidth: width, random: math.Random(3))
      ..step(PipBrain.landEnd)
      ..segments = segments;
    if (x != null) p.x = x;
    return p;
  }

  void run(PipBrain pip, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      pip.step(1 / 60);
    }
  }

  /// Steps until he's no longer [doing] (at most [limit] seconds).
  void until(PipBrain pip, PipActivity doing, {double limit = 20}) {
    for (var t = 0.0; t < limit && pip.activity == doing; t += 1 / 60) {
      pip.step(1 / 60);
    }
  }

  test('plugged in: the station rises, he hurries over and plugs in', () {
    final p = up(x: 20);
    p.setPlugged(true);
    final (sx, rising, right) = p.station!;
    expect(rising, 0, reason: 'out of the ground');
    expect(right, isTrue, reason: 'on the side with more room');
    run(p, PipBrain.stationRise / 2);
    expect(p.station!.$2, inExclusiveRange(0, 1));
    expect(p.activity, isNot(PipActivity.toStation), reason: 'waits for it');
    run(p, PipBrain.stationRise / 2 + 0.05);
    expect(p.station!.$2, 1);
    expect(p.activity, PipActivity.toStation);
    // Hurrying, quicker than his walk.
    final from = p.x;
    run(p, 0.5);
    expect(p.x - from, closeTo(PipBrain.hurry * 0.5, 1));
    until(p, PipActivity.toStation);
    expect(p.activity, PipActivity.plugging);
    expect(p.x + PipBrain.width + PipBrain.stationGap, closeTo(sx, 0.01),
        reason: 'beside it');
    expect(p.facingRight, isTrue, reason: 'facing it');
    // His hands pop in, then away; the plug goes from the hook to his side.
    expect(p.plug, isNotNull);
    final onHook = p.plug!;
    run(p, PipBrain.mittsInEnd + 0.01);
    expect(p.mitts, hasLength(2));
    expect(p.mitts.every((m) => m.$3 == 1), isTrue);
    run(p, PipBrain.carryEnd - PipBrain.mittsInEnd);
    expect(p.plug, isNot(onHook), reason: 'in his side now');
    until(p, PipActivity.plugging);
    expect(p.activity, PipActivity.charging);
    expect(p.mitts, isEmpty, reason: 'popped away');
    expect(p.chargeScreen, isNotNull);
  });

  test('the station never rises on top of him', () {
    for (final width in [60, 90, 120, 200]) {
      for (var x = 0.0; x <= width - PipBrain.width; x += 3) {
        final p = up(width: width, x: x)..setPlugged(true, animate: false);
        final station = p.station;
        if (station == null) continue;
        final sx = station.$1;
        final apart =
            sx >= x + PipBrain.width || sx + PipBrain.stationWidth <= x;
        expect(apart, isTrue, reason: 'room $width, Pip at $x');
      }
    }
  });

  test('no room for it (a narrow room): no station', () {
    final p = up(width: 50)..setPlugged(true);
    expect(p.station, isNull);
    expect(p.play(PipAnimation.charge), isFalse);
  });

  test('full, he ignores it (and doesn\'t walk into it); not full, he goes',
      () {
    final p = up(segments: 3, x: 10)..setPlugged(true);
    run(p, 30);
    expect(p.station, isNotNull);
    expect(p.activity, isNot(PipActivity.toStation));
    expect(p.activity, isNot(PipActivity.charging));
    final sx = p.station!.$1;
    for (var i = 0; i < 600; i++) {
      p.step(0.05);
      expect(p.x + PipBrain.width, lessThanOrEqualTo(sx), reason: 'not in it');
    }
    p.segments = 2;
    until(p, PipActivity.walking);
    until(p, PipActivity.standing);
    expect([PipActivity.toStation, PipActivity.plugging, PipActivity.charging],
        contains(p.activity));
  });

  test('opened while charging: he\'s simply there, charging', () {
    final p = up(x: 60)..setPlugged(true, animate: false);
    expect(p.station!.$2, 1);
    expect(p.activity, PipActivity.charging);
    expect(p.plug, isNotNull);
  });

  test('unplugged while watching: he unplugs, the station sinks', () {
    final p = up(x: 60)..setPlugged(true, animate: false);
    p.setPlugged(false);
    expect(p.activity, PipActivity.unplugging);
    run(p, PipBrain.mittsInEnd + 0.01);
    expect(p.mitts, hasLength(2), reason: 'hands pop in');
    until(p, PipActivity.unplugging);
    expect(p.activity, PipActivity.standing);
    expect(p.station!.$2, lessThanOrEqualTo(1));
    run(p, PipBrain.stationRise + 0.05);
    expect(p.station, isNull, reason: 'gone into the ground');
  });

  test('busy (asleep): the station rises, but he doesn\'t use it', () {
    final p = up()..show(PipShow.asleep);
    run(p, 3);
    p.setPlugged(true);
    run(p, 5);
    expect(p.station!.$2, 1);
    expect(p.activity, PipActivity.asleep);
  });

  test('bedtime while charging: he unplugs first, then sleeps', () {
    final p = up(x: 60)..setPlugged(true, animate: false);
    expect(p.show(PipShow.fallAsleep), isFalse, reason: 'unplugging first');
    expect(p.activity, PipActivity.unplugging);
    until(p, PipActivity.unplugging);
    expect(p.activity, PipActivity.standing, reason: 'not back to it');
    expect(p.show(PipShow.fallAsleep), isTrue);
    expect(p.station, isNotNull, reason: 'the phone is still plugged in');
  });

  test(
      "while charging, the screen changes now and then; humming's notes "
      'float up; sparks', () {
    final p = up(x: 60)..setPlugged(true, animate: false);
    final seen = <ChargeScreen>{};
    for (var i = 0; i < 60 * 120; i++) {
      p.step(1 / 60);
      seen.add(p.chargeScreen!.$1);
      if (p.chargeScreen!.$1 == ChargeScreen.humming) {
        expect(p.notes, isNotEmpty);
      }
    }
    expect(seen.length, greaterThan(5));
    p.debugScreen(ChargeScreen.sparks, 0);
    expect(p.sparks, isNotEmpty);
  });

  test('the demo (Pip Home): even full, he plugs in, charges, unplugs', () {
    final p = up(segments: 3, x: 20);
    expect(p.play(PipAnimation.charge), isTrue);
    until(p, PipActivity.standing, limit: 3);
    until(p, PipActivity.toStation);
    until(p, PipActivity.plugging);
    expect(p.activity, PipActivity.charging);
    // His room checking: the phone isn't plugged in, the demo goes on.
    p.setPlugged(false);
    expect(p.activity, PipActivity.charging);
    until(p, PipActivity.charging, limit: PipBrain.demoChargeHold + 1);
    expect(p.activity, PipActivity.unplugging);
    until(p, PipActivity.unplugging);
    run(p, PipBrain.stationRise + 0.05);
    expect(p.station, isNull);
  });

  test(
      'the demo with the phone plugged in (Round 45): plays if he isn\'t '
      'at the station (full); not while he is', () {
    final full = up(segments: 3, x: 20)..setPlugged(true, animate: false);
    expect(full.activity, isNot(PipActivity.charging), reason: 'ignores it');
    expect(full.play(PipAnimation.charge), isTrue);
    until(full, PipActivity.standing, limit: 3);
    until(full, PipActivity.toStation);
    until(full, PipActivity.plugging);
    until(full, PipActivity.charging, limit: PipBrain.demoChargeHold + 1);
    expect(full.activity, PipActivity.unplugging, reason: 'full: off again');
    until(full, PipActivity.unplugging);
    run(full, 1);
    expect(full.station, isNotNull, reason: 'the phone is still plugged in');

    final charging = up(x: 60)..setPlugged(true, animate: false);
    expect(charging.play(PipAnimation.charge), isFalse);
  });

  group('energy while plugged in (Round 45: for fun, not to save him)', () {
    final at = DateTime(2026, 10, 14, 10);

    test('he uses it as ever', () {
      expect(
          PipEnergy.chargingLevelAt(2.5, at, at.add(const Duration(hours: 4))),
          closeTo(2.0, 1e-9));
    });

    test("but can't run out", () {
      expect(
          PipEnergy.chargingLevelAt(1, at, at.add(const Duration(hours: 30))),
          PipEnergy.chargingFloor);
      expect(PipEnergy.segments(PipEnergy.chargingFloor), 1);
    });

    test("out already, he stays out (the station doesn't fill him)", () {
      expect(PipEnergy.chargingLevelAt(0, at, at.add(const Duration(hours: 4))),
          0);
    });
  });
}
