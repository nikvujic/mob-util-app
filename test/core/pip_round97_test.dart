import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Round 97 (Nikola): changing his battery, livelier: the new one bounces
/// as it lands and glints while it waits; the old one has no red bit, is
/// thrown over his head to his other side (never over the new one), lands
/// with a puff of dust; a crackle as the new one clicks in; a shake, then
/// a hop with sparkles.
void main() {
  PipBrain up() => PipBrain(roomWidth: 140, random: math.Random(3))
    ..skyRows = 59
    ..step(PipBrain.landEnd);

  /// Runs the swap from [at], calling [each] every frame.
  void swap(PipBrain p, double at, void Function(PipBrain) each) {
    expect(p.takeBattery(at), isTrue);
    for (var i = 0; i < 60 * 8 && p.activity == PipActivity.fetching; i++) {
      p.step(1 / 60);
      each(p);
    }
    expect(p.activity, PipActivity.standing);
  }

  test('the old battery: dull, no red bit left in it', () {
    expect(PipSprites.batteryEmpty.join(), isNot(contains('R')));
  });

  test('the new one bounces once as it lands, and glints while it waits', () {
    final p = up()..x = 10;
    final heights = <double>[];
    var glints = 0;
    var landed = false;
    swap(p, 80, (p) {
      final b = p.battery;
      if (b != null && p.oldBattery == null && p.mitts.isEmpty) {
        heights.add(b.$2);
      }
      if (p.batteryGlint != null) glints++;
      landed |= b != null && b.$2 == 0;
    });
    expect(landed, isTrue);
    // Down to the ground, up again a little, down again.
    final firstGround = heights.indexWhere((h) => h == 0);
    final after = heights.skip(firstGround + 1).take(20).toList();
    expect(after.reduce(math.max), greaterThan(0.5), reason: 'a bounce');
    expect(after.reduce(math.max), lessThanOrEqualTo(PipBrain.bounceHeight));
    expect(glints, greaterThan(0));
  });

  test('the glint twinkles: on a moment, then off', () {
    final p = up()..x = 10;
    p.takeBattery(80);
    final seen = <bool>[];
    for (var i = 0; i < 60 * 2; i++) {
      p.step(1 / 60);
      if (p.battery case (_, final h) when h == 0) {
        seen.add(p.batteryGlint != null);
      }
      if (p.mitts.isNotEmpty) break;
    }
    expect(seen, contains(true));
    expect(seen.where((g) => !g).length, greaterThan(seen.length ~/ 2),
        reason: 'mostly off');
  });

  test('a glint only on the ground, before it is taken', () {
    final p = up()..x = 10;
    expect(p.takeBattery(80), isTrue);
    expect(p.batteryGlint, isNull, reason: 'still falling');
    var wasHeld = false;
    for (var i = 0; i < 60 * 8 && p.activity == PipActivity.fetching; i++) {
      p.step(1 / 60);
      final b = p.battery;
      if (p.mitts.isNotEmpty && b != null && b.$2 > 0.5) wasHeld = true;
      if (wasHeld) expect(p.batteryGlint, isNull, reason: 'in his hand');
    }
    expect(wasHeld, isTrue);
  });

  test(
      'the old one lands on his other side with a puff of dust, then '
      'fades; a crackle at his slot; a shake, then a hop with sparkles', () {
    final p = up()..x = 10;
    var dust = 0;
    final slotSparks = <(double, double)>[];
    final hopSparks = <(double, double)>[];
    var shook = false;
    var hopped = 0.0;
    swap(p, 80, (p) {
      if (p.batteryDust.isNotEmpty) dust++;
      final sparks = p.sparks;
      if (sparks.isNotEmpty) {
        if (p.lift > 0) {
          hopSparks.addAll(sparks);
        } else {
          slotSparks.addAll(sparks);
        }
      }
      final (sx, sy) = p.stretch;
      if (sx > 1.02 && sy < 0.98 && p.mitts.isEmpty) shook = true;
      hopped = math.max(hopped, p.lift);
    });
    expect(dust, greaterThan(0));
    expect(slotSparks, isNotEmpty, reason: 'as it clicked in');
    // By his right side (the slot), not far.
    final right = p.x + PipBrain.width - PipBrain.bodyInset;
    for (final (x, _) in slotSparks) {
      expect(x, inInclusiveRange(right - 1, right + 8));
    }
    expect(shook, isTrue);
    expect(hopped, greaterThan(3));
    expect(hopSparks, isNotEmpty);
  });

  test('on his left, too: thrown over him, never over the new one', () {
    final p = up()..x = 100;
    swap(p, 10, (p) {
      if ((p.oldBattery, p.battery) case ((final o?, final b?))) {
        final apart = o.$1 + PipBrain.batteryWidth <= b.$1 ||
            b.$1 + PipBrain.batteryWidth <= o.$1 ||
            o.$2 >= b.$2 + PipBrain.batteryHeight ||
            b.$2 >= o.$2 + PipBrain.batteryHeight;
        expect(apart, isTrue, reason: 'old $o over new $b');
      }
    });
  });

  test('by a wall, it lands in the room', () {
    final p = up()..x = 0;
    final olds = <double>[];
    swap(p, 30, (p) {
      if (p.oldBattery case final o?) olds.add(o.$1);
    });
    expect(
        olds.every((x) => x >= 0 && x <= 140 - PipBrain.batteryWidth), isTrue);
  });
}
