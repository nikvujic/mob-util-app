import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';

/// Round 54: his battery changed by hand (the old one pulled out of his
/// side and thrown away, the new one picked up and pushed in), and his
/// hands close to his body, only the one he uses.
void main() {
  PipBrain up({int width = 140, int seed = 3}) => PipBrain(
        roomWidth: width,
        random: math.Random(seed),
      )
        ..skyRows = 59
        ..step(PipBrain.landEnd);

  /// His casing's right edge (the first column past it) and left edge.
  double rightOf(PipBrain p) => p.x + PipBrain.width - PipBrain.bodyInset;
  double leftOf(PipBrain p) => p.x + PipBrain.bodyInset;

  /// A hand's two pixels (from its middle, as [PipBrain.handBeside]).
  void besideHim(PipBrain p, double handX, {required bool right}) {
    if (right) {
      expect(handX - 1, rightOf(p) + 1, reason: 'a pixel off his right');
    } else {
      expect(handX, leftOf(p) - 2, reason: 'a pixel off his left');
    }
  }

  /// Steps until he's started changing it (beside it, the hand in).
  void toSwap(PipBrain p) {
    for (var i = 0; i < 60 * 20 && p.mitts.isEmpty; i++) {
      p.step(1 / 60);
    }
    expect(p.mitts, isNotEmpty);
  }

  group('his battery, by hand', () {
    test(
        'beside it; the old one out of his side and thrown away; the new '
        'one picked up and pushed in; a hop', () {
      final p = up()..x = 10;
      expect(p.takeBattery(80), isTrue);
      toSwap(p);
      expect(p.facingRight, isTrue);
      expect(p.x, closeTo(80 - (rightOf(p) - p.x) - 1, 0.01),
          reason: 'it a pixel off his casing, by his hand');
      expect(p.batterySlot, isNull, reason: 'shut till the hand is there');
      final slots = <double>{};
      final olds = <(double, double, double, bool)>[];
      final hands = <double>[];
      var crouched = false;
      var hopped = false;
      double? grabbedAt;
      for (var i = 0; i < 60 * 5 && p.activity == PipActivity.fetching; i++) {
        p.step(1 / 60);
        if (p.batterySlot case final s?) slots.add(s);
        if (p.oldBattery case final o?) olds.add(o);
        if (p.mitts.isNotEmpty) {
          expect(p.mitts, hasLength(1), reason: 'one hand');
          hands.add(p.mitts.single.$2);
        }
        crouched |= p.stretch.$2 < 0.95;
        hopped |= p.lift > 0;
        final b = p.battery;
        if (b != null && b.$2 > 0 && grabbedAt == null) grabbedAt = b.$1;
      }
      expect(p.activity, PipActivity.standing);
      expect(slots, {rightOf(p) - 1}, reason: 'on his casing, his right');
      // The old one: from inside his casing, out a pixel off it…
      expect(olds.first.$1, lessThan(rightOf(p)));
      final out = olds.firstWhere((o) => o.$2 > PipBrain.slotUp);
      expect(out.$1, rightOf(p) + 1);
      // …then thrown off to his right, up, end over end, fading away.
      expect(olds.last.$1, greaterThan(out.$1 + 30));
      expect(olds.map((o) => o.$2).reduce(math.max),
          greaterThan(PipBrain.slotUp + 10));
      expect(olds.map((o) => o.$4).toSet(), {true, false});
      expect(olds.last.$3, greaterThan(0.8));
      expect(crouched, isTrue);
      expect(hands.reduce(math.min), lessThan(PipBrain.slotUp),
          reason: 'down to the new one');
      expect(grabbedAt, isNotNull, reason: 'it was lifted');
      expect(hopped, isTrue);
      expect(p.battery, isNull, reason: 'in him');
      expect(p.oldBattery, isNull);
      expect(p.mitts, isEmpty);
    });

    test('the new one goes into the slot: behind his casing at the end', () {
      final p = up()..x = 10;
      p.takeBattery(80);
      toSwap(p);
      var last = p.battery;
      while (p.battery != null) {
        last = p.battery;
        p.step(1 / 60);
      }
      expect(last!.$1, greaterThanOrEqualTo(leftOf(p)));
      expect(last.$1 + PipBrain.batteryWidth, lessThanOrEqualTo(rightOf(p)),
          reason: 'all in, behind his casing');
      expect(last.$2, PipBrain.slotUp);
    });

    test('on his left: he faces it, and throws the old one to the left', () {
      final p = up()..x = 100;
      p.takeBattery(10);
      toSwap(p);
      expect(p.facingRight, isFalse);
      expect(p.x,
          closeTo(10 + PipBrain.batteryWidth + 1 - PipBrain.bodyInset, 0.01));
      besideHim(p, p.mitts.single.$1 + 1, right: false);
      final olds = <double>[];
      for (var i = 0; i < 60 * 5 && p.activity == PipActivity.fetching; i++) {
        p.step(1 / 60);
        if (p.oldBattery case final o?) olds.add(o.$1);
        if (p.batterySlot case final s?) expect(s, leftOf(p));
      }
      expect(olds.last, lessThan(olds.first - 30));
    });

    test('no room on the side he comes from: the other side', () {
      // It's just right of the room's left edge, him at it: on his right
      // there's no room (he'd be off the edge), so it's on his left.
      final p = up()..x = 0;
      p.takeBattery(12);
      toSwap(p);
      expect(p.facingRight, isFalse);
      expect(p.x, greaterThan(0));
      expect(p.x, lessThanOrEqualTo(140 - PipBrain.width));
      // At the right wall, it just left of him: no room there for him to
      // its right, so it's on his right.
      final q = up()..x = 120;
      q.takeBattery(118);
      toSwap(q);
      expect(q.facingRight, isTrue);
      expect(q.x, closeTo(118 - (rightOf(q) - q.x) - 1, 0.01));
    });

    test('the hand moves smoothly, and carries the new one up to the slot', () {
      final p = up()..x = 10;
      p.takeBattery(80);
      toSwap(p);
      (double, double)? was;
      final carried = <(double, double)>[];
      for (var i = 0; i < 60 * 5 && p.activity == PipActivity.fetching; i++) {
        p.step(1 / 60);
        if (p.mitts.isNotEmpty) {
          final (hx, hy, _) = p.mitts.single;
          if (was != null) {
            expect((hx - was.$1).abs(), lessThan(2), reason: 'no jump');
            expect((hy - was.$2).abs(), lessThan(2), reason: 'no jump');
          }
          was = (hx, hy);
        }
        if (p.battery case (final bx, final bh)
            when bh > 0 && bh < PipBrain.slotUp) {
          carried.add((bx, bh));
        }
      }
      expect(carried.length, greaterThan(5), reason: 'lifted, on its way');
    });

    test('a preview from the list: one dropped near him', () {
      final p = up()..x = 40;
      expect(p.play(PipAnimation.fetch), isTrue);
      expect(p.activity, PipActivity.fetching);
      expect(p.battery, isNotNull);
      expect(PipAnimation.fetch.listed, isTrue);
      // At the right wall, it drops on his left.
      final q = up()..x = 120;
      expect(q.play(PipAnimation.fetch), isTrue);
      expect(q.battery!.$1, lessThan(q.x));
      // Asleep: no.
      final asleep = up()..show(PipShow.asleep);
      for (var i = 0; i < 300; i++) {
        asleep.step(1 / 60);
      }
      expect(asleep.play(PipAnimation.fetch), isFalse);
    });
  });

  group('his hands, close and one', () {
    test('the sword: a pixel off his casing, either side', () {
      for (final right in [true, false]) {
        final p = up()..facingRight = right;
        p.play(PipAnimation.bugs);
        p.step(0.5);
        besideHim(p, p.sword!.$1, right: right);
      }
    });

    test('the fist, angry: by his side', () {
      final p = up()..enter(PipEntrance.side);
      while (p.activity != PipActivity.angry) {
        p.step(1 / 60);
      }
      // Drawn from its left pixel, shaking a pixel either way.
      final shakes = <double>{};
      while (p.activity == PipActivity.angry) {
        final (fx, _) = p.fist!;
        shakes.add(fx + 1 - p.handBeside(right: p.facingRight));
        p.step(1 / 60);
      }
      expect(shakes, {-1.0, 1.0});
    });

    test('the flower in his hand: by his side', () {
      final p = up(seed: 5)..play(PipAnimation.flower);
      while (p.flowerHand == null) {
        p.step(1 / 60);
      }
      besideHim(p, p.flowerHand!.$1 + 1, right: p.facingRight);
    });
  });
}
