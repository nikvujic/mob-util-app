import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';

/// Pip in his room (Round 26).
void main() {
  PipBrain pip({int width = 120}) =>
      PipBrain(roomWidth: width, random: math.Random(7));

  /// Steps [pip] through [seconds] in frames of 1/60 s.
  void run(PipBrain pip, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      pip.step(1 / 60);
    }
  }

  test('starts in the middle, under the ground', () {
    final p = pip();
    expect(p.x, (120 - PipBrain.width) / 2);
    expect(p.activity, PipActivity.spawning);
    expect(p.sunk, PipBrain.height, reason: 'all of him, antenna too');
    expect(p.dirt, 0);
  });

  test('comes up out of the ground, hops (stretched), lands (squashed)', () {
    final p = pip();
    run(p, 0.3);
    expect(p.dirt, greaterThan(0), reason: 'the ground cracks');
    run(p, 0.5); // ~0.8 s: rising
    expect(p.sunk, inExclusiveRange(0, PipBrain.height));
    run(p, 0.3); // ~1.1 s: the hop
    expect(p.sunk, 0);
    expect(p.lift, greaterThan(0));
    expect(p.stretch.$2, greaterThan(1), reason: 'taller going up');
    run(p, 0.45); // ~1.55 s: landing
    expect(p.frame, PipFrame.tuck);
    expect(p.stretch.$2, lessThan(1), reason: 'squashed');
    run(p, 0.2);
    expect(p.activity, isNot(PipActivity.spawning));
    expect(p.spawned, isTrue);
    expect(p.stretch, (1.0, 1.0));
  });

  test('then stands, blinks, walks within the room, facing his way', () {
    final p = pip();
    final seen = <PipActivity>{};
    final frames = <PipFrame>{};
    var lastX = p.x;
    for (var i = 0; i < 60 * 40; i++) {
      p.step(1 / 60);
      seen.add(p.activity);
      frames.add(p.frame);
      expect(p.x, inInclusiveRange(0, 120 - PipBrain.width));
      if (p.activity == PipActivity.walking && p.x != lastX) {
        expect(p.facingRight, p.x > lastX, reason: 'faces where he goes');
      }
      lastX = p.x;
    }
    expect(seen, containsAll(PipActivity.values));
    expect(
        frames, containsAll([PipFrame.blink, PipFrame.step1, PipFrame.step3]));
  });

  test('standing, now and then he turns to look the other way', () {
    final p = pip(width: PipBrain.width + 4); // too small to walk
    run(p, 2);
    var turns = 0;
    var facing = p.facingRight;
    for (var i = 0; i < 60 * 60; i++) {
      p.step(1 / 60);
      expect(p.activity, PipActivity.standing);
      if (p.facingRight != facing) turns++;
      facing = p.facingRight;
    }
    expect(turns, greaterThan(2), reason: 'a few times a minute');
    expect(turns, lessThan(20), reason: 'not all the time');
  });

  test('a room too small to walk in: he just stands', () {
    final p = pip(width: PipBrain.width + 4);
    run(p, 30);
    expect(p.activity, PipActivity.standing);
  });

  test('a narrower room keeps him inside it', () {
    final p = pip();
    run(p, 40);
    p.roomWidth = 30;
    expect(p.x, inInclusiveRange(0, 30 - PipBrain.width));
  });
}
