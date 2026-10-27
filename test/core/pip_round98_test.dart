import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';

/// Round 98: the phone buzzes through his animations wherever
/// something lands, hits or clicks: the battery drop, its bounce, the old
/// one pulled out and landing, the new one clicking in, his hops, falling
/// over, plugging in, bites, dance beats, a flower picked, the ball, the
/// snowman done and the snowball at you.
void main() {
  PipBrain up() => PipBrain(roomWidth: 140, random: math.Random(3))
    ..skyRows = 59
    ..step(PipBrain.landEnd);

  /// Steps [p] until [done] (at most [limit] seconds), the buzzes taken
  /// as they come, with when (seconds since the start).
  List<(double, PipBuzz)> buzzes(PipBrain p, bool Function(PipBrain) done,
      {double limit = 20}) {
    p.takeBuzzes();
    final seen = <(double, PipBuzz)>[];
    var t = 0.0;
    while (t < limit && !done(p)) {
      p.step(1 / 60);
      t += 1 / 60;
      for (final b in p.takeBuzzes()) {
        seen.add((t, b));
      }
    }
    expect(done(p), isTrue, reason: 'it finished');
    return seen;
  }

  List<PipBuzz> kinds(List<(double, PipBuzz)> seen) =>
      [for (final (_, b) in seen) b];

  bool standing(PipBrain p) => p.activity == PipActivity.standing;

  /// The times of [seen] near [at] (within a frame or two).
  Matcher near(double at) => closeTo(at, 2 / 60);

  test('out of the ground: the ground cracks, then he lands his hop', () {
    final p = up();
    expect(p.play(PipAnimation.spawn), isTrue);
    final seen = buzzes(p, standing);
    expect(kinds(seen), [PipBuzz.light, PipBuzz.light]);
    expect(seen[0].$1, near(PipBrain.crackEnd));
    expect(seen[1].$1, near(PipBrain.hopEnd));
  });

  test('out of his egg: a buzz as he lands', () {
    final p = up();
    expect(p.play(PipAnimation.hatch), isTrue);
    final seen = buzzes(p, standing);
    expect(kinds(seen), [PipBuzz.light]);
    expect(seen.single.$1, near(PipBrain.hatchLandEnd));
  });

  test('falling asleep: settling down; waking: down from his hop', () {
    final p = up();
    expect(p.play(PipAnimation.fallAsleep), isTrue);
    final down = buzzes(p, (p) => p.activity == PipActivity.asleep);
    expect(kinds(down), [PipBuzz.light]);
    expect(down.single.$1, near(PipBrain.settleAt));
    expect(p.play(PipAnimation.wakeUp), isTrue);
    final woken = buzzes(p, standing);
    expect(kinds(woken), [PipBuzz.light]);
    expect(woken.single.$1, near(PipBrain.wakeHopEnd));
  });

  test('running out: a thud as he falls over', () {
    final p = up();
    expect(p.play(PipAnimation.powerOff), isTrue);
    final seen = buzzes(p, (p) => p.activity == PipActivity.off);
    expect(kinds(seen), [PipBuzz.medium]);
    expect(seen.single.$1, near(PipBrain.fallEnd));
  });

  test('back on: the battery reaches him, then down from his hop', () {
    final p = up();
    p.play(PipAnimation.powerOff);
    buzzes(p, (p) => p.activity == PipActivity.off);
    expect(p.takeBattery(80), isTrue);
    expect(p.activity, PipActivity.poweringOn);
    final seen = buzzes(p, standing);
    expect(kinds(seen), [PipBuzz.medium, PipBuzz.light]);
    expect(seen[0].$1, near(PipBrain.flyEnd));
    expect(seen[1].$1, near(PipBrain.onEnd));
  });

  test(
      'changing his battery: the drop, its bounce, the old one out and '
      'landing, the new one clicking in, his hop', () {
    final p = up()..x = 10;
    expect(p.takeBattery(80), isTrue);
    final seen = buzzes(p, standing);
    expect(kinds(seen), [
      PipBuzz.medium, // dropped
      PipBuzz.light, // its bounce
      PipBuzz.light, // the old one pulled out
      PipBuzz.medium, // the old one lands
      PipBuzz.heavy, // the new one in
      PipBuzz.light, // down from his hop
    ]);
    final fall = PipBrain.dropHeight / PipBrain.fallSpeed;
    expect(seen[0].$1, near(fall));
    expect(seen[1].$1, near(fall + PipBrain.bounceTime));
    // The rest by his hand's clock, once he's beside it: as far apart as
    // its marks are.
    final start = seen[2].$1 - PipBrain.pulledOut;
    expect(seen[3].$1 - start, near(PipBrain.throwAt + PipBrain.throwFlight));
    expect(seen[4].$1 - start, near(PipBrain.pushedIn));
    expect(seen[5].$1 - start, near(PipBrain.pickEnd));
  });

  test('charging: the cable taken, plugged in; pulled out after', () {
    final p = up();
    expect(p.play(PipAnimation.charge), isTrue);
    var unplugged = false;
    final seen = buzzes(p, (p) {
      unplugged |= p.activity == PipActivity.unplugging;
      return unplugged && standing(p);
    });
    expect(kinds(seen), [PipBuzz.light, PipBuzz.medium, PipBuzz.medium]);
  });

  test('a little dance: a buzz on every beat', () {
    final p = up();
    expect(p.play(PipAnimation.dance), isTrue);
    final seen = buzzes(p, standing);
    final beats = PipBrain.danceTime ~/ PipBrain.beatTime - 1;
    expect(kinds(seen), List.filled(beats, PipBuzz.light));
    for (final (i, (t, _)) in seen.indexed) {
      expect(t, near(PipBrain.beatTime * (i + 1)));
    }
  });

  test('eating: a buzz on each bite', () {
    final p = up();
    expect(p.play(PipAnimation.eat), isTrue);
    final seen = buzzes(p, standing);
    expect(kinds(seen), List.filled(PipBrain.bites.length, PipBuzz.light));
    for (final (i, (t, _)) in seen.indexed) {
      expect(t, near(PipBrain.bites[i] + PipBrain.biteTime / 2));
    }
  });

  test('a notification: down from his hop; his medicine: twice', () {
    final p = up();
    expect(p.play(PipAnimation.notified), isTrue);
    final seen = buzzes(p, standing);
    expect(kinds(seen), [PipBuzz.light]);
    expect(seen.single.$1, near(PipBrain.showHop));
    expect(p.play(PipAnimation.medicine), isTrue);
    final pill = buzzes(p, standing);
    expect(kinds(pill), [PipBuzz.light, PipBuzz.light]);
    expect(pill[1].$1, near(0.9));
  });

  test('a happy screen (no hop): no buzz', () {
    final p = up()..debugShow(PipScreen.happy);
    expect(buzzes(p, standing), isEmpty);
  });

  test('a flower: a buzz as he picks it', () {
    final p = up();
    expect(p.play(PipAnimation.flower), isTrue);
    expect(kinds(buzzes(p, standing)), [PipBuzz.light]);
  });

  test('the ball: the kick, then a buzz on each real bounce', () {
    final p = up();
    expect(p.play(PipAnimation.ball), isTrue);
    final seen = kinds(buzzes(p, standing));
    expect(seen.first, PipBuzz.medium);
    expect(seen.skip(1), isNotEmpty, reason: 'it bounces');
    expect(seen.skip(1), everyElement(PipBuzz.light));
    expect(seen.length, lessThanOrEqualTo(4), reason: 'not every hop');
  });

  test('the snowman built: a buzz; the snowball splats at you: a thud', () {
    final p = up();
    expect(p.play(PipAnimation.snowman), isTrue);
    expect(kinds(buzzes(p, standing)), [PipBuzz.light]);
    expect(p.play(PipAnimation.snowball), isTrue);
    expect(kinds(buzzes(p, standing)), [PipBuzz.medium]);
  });

  test('calm ones stay calm: a blink, a butterfly, a shooting star', () {
    for (final a in [
      PipAnimation.blink,
      PipAnimation.butterfly,
      PipAnimation.shootingStar,
    ]) {
      final p = up();
      expect(p.play(a), isTrue);
      expect(buzzes(p, standing), isEmpty, reason: a.label);
    }
  });
}
