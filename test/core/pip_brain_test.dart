import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';

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
    expect(
        seen,
        containsAll([
          PipActivity.spawning,
          PipActivity.standing,
          PipActivity.walking,
        ]));
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

  group('his egg (Round 34)', () {
    test('cracks with taps: 1, then every 2; the 7th hatches him', () {
      final p =
          PipBrain(roomWidth: 120, random: math.Random(7), hatched: false);
      expect(p.activity, PipActivity.egg);
      expect(p.spawned, isFalse);
      final cracks = <int>[];
      for (var i = 0; i < 6; i++) {
        expect(p.tapEgg(), isFalse);
        cracks.add(p.crack);
      }
      expect(cracks, [1, 1, 2, 2, 3, 3]);
      expect(p.tapEgg(), isTrue, reason: 'the 7th');
      expect(p.activity, PipActivity.hatching);
      expect(p.tapEgg(), isFalse, reason: 'once');
    });

    test('hatching: the top pops, he jumps out, lands, the shell fades', () {
      final p =
          PipBrain(roomWidth: 120, random: math.Random(7), hatched: false);
      for (var i = 0; i < 7; i++) {
        p.tapEgg();
      }
      expect(p.visible, isFalse, reason: 'the pop first');
      run(p, 0.3);
      expect(p.visible, isTrue);
      expect(p.lift, greaterThan(0), reason: 'jumping out');
      expect(p.capFlight, greaterThan(0));
      run(p, 0.5); // ~0.8 s: landing
      expect(p.stretch.$2, lessThan(1), reason: 'squashed');
      run(p, 0.5); // ~1.3 s
      expect(p.shellFade, inExclusiveRange(0, 1));
      run(p, 0.6);
      expect(p.activity, PipActivity.standing);
      expect(p.spawned, isTrue);
    });
  });

  group('energy, sleep and batteries (Round 37)', () {
    PipBrain up({int width = 120}) {
      final p = pip(width: width);
      run(p, 3); // out of the ground, standing about
      return p;
    }

    test('fresh, he appears as his life says, without coming up', () {
      final asleep = pip()..show(PipShow.asleep);
      expect(asleep.activity, PipActivity.asleep);
      expect(asleep.sunk, 0);
      final off = pip()..show(PipShow.off);
      expect(off.activity, PipActivity.off);
      expect(off.tilt, 1);
      final turning = pip()..show(PipShow.powerOff);
      expect(turning.activity, PipActivity.poweringOff);
      final waking = pip()..show(PipShow.wakeUp);
      expect(waking.activity, PipActivity.wakingUp);
      final awake = pip()..show(PipShow.awake);
      expect(awake.activity, PipActivity.spawning, reason: 'still comes up');
    });

    test('falls asleep: eyes close, he settles, z\'s rise; wakes with a hop',
        () {
      final p = up();
      expect(p.show(PipShow.fallAsleep), isTrue);
      expect(p.face, PipFace.tired);
      run(p, 1);
      expect(p.face, PipFace.asleep);
      run(p, 1.5);
      expect(p.activity, PipActivity.asleep);
      expect(p.frame, PipFrame.tuck);
      expect(p.zs, hasLength(3));
      expect(p.show(PipShow.wakeUp), isTrue);
      run(p, PipBrain.wakeHopStart + 0.3); // Round 57: a longer wake
      expect(p.lift, greaterThan(0), reason: 'the hop');
      run(p, 1);
      expect(p.activity, isNot(PipActivity.asleep));
      expect(p.zs, isEmpty);
    });

    test('runs out: flickers, falls over, lies there dark', () {
      final p = up();
      p.show(PipShow.powerOff);
      final faces = <PipFace>{};
      for (var t = 0.0; t < PipBrain.flickerEnd; t += 1 / 60) {
        faces.add(p.face);
        p.step(1 / 60);
      }
      expect(faces, {PipFace.veryTired, PipFace.off}, reason: 'a flicker');
      run(p, 1);
      expect(p.activity, PipActivity.off);
      expect(p.tilt, 1);
      expect(p.face, PipFace.off);
      expect(p.play(PipAnimation.walk), isFalse, reason: 'off: nothing');
    });

    test('falls where there is room: right, or left at the right wall', () {
      final p = up();
      p.x = 0;
      p.show(PipShow.off);
      expect(p.fallRight, isTrue);
      final q = up()..x = 100;
      q.show(PipShow.off);
      expect(q.fallRight, isFalse);
    });

    test('a battery dropped: he walks over and picks it up', () {
      final p = up();
      p.x = 10;
      expect(p.takeBattery(80), isTrue);
      expect(p.activity, PipActivity.fetching);
      expect(p.battery!.$2, PipBrain.dropHeight, reason: 'falling in');
      // Hurrying (Round 44), whatever his energy.
      p.segments = 1;
      run(p, 1);
      expect(p.x, closeTo(10 + PipBrain.hurry, 1));
      for (var i = 0; i < 400 && p.activity == PipActivity.fetching; i++) {
        p.step(0.05);
      }
      expect(p.battery, isNull, reason: 'picked up');
      // Round 54: beside it (on his right), not over it.
      expect(p.x, closeTo(80 - (PipBrain.width - PipBrain.bodyInset + 1), 0.5));
      expect(p.activity, isNot(PipActivity.fetching));
    });

    test('off, a battery flies to him; he comes back on and gets up', () {
      final p = up()..show(PipShow.off);
      expect(p.takeBattery(10), isTrue);
      expect(p.activity, PipActivity.poweringOn);
      expect(p.battery, isNotNull);
      run(p, 0.8);
      expect(p.battery, isNull);
      run(p, 1.5);
      expect(p.activity, PipActivity.standing);
      expect(p.tilt, 0);
    });

    test('asleep, no battery taken', () {
      final p = up()..show(PipShow.asleep);
      run(p, 3);
      expect(p.canTakeBattery, isFalse);
      expect(p.takeBattery(10), isFalse);
    });

    test('his face and pace follow his energy', () {
      final p = up();
      expect(p.face, PipFace.normal);
      p.segments = 2;
      expect(p.face, PipFace.tired);
      expect(p.pace, closeTo(PipBrain.speed * 0.7, 1e-9));
      p.segments = 1;
      expect(p.face, PipFace.veryTired);
      expect(p.pace, lessThan(PipBrain.speed * 0.5));
    });

    test('from the list, asleep and off come back on their own', () {
      final p = up();
      expect(p.play(PipAnimation.fallAsleep, demo: true), isTrue);
      run(p, 9);
      expect(p.activity, isNot(PipActivity.asleep));
      expect(p.play(PipAnimation.powerOff, demo: true), isTrue);
      run(p, 6);
      expect(p.activity, isNot(PipActivity.off));
      expect(p.tilt, 0);
      // Played for real, he stays asleep.
      p.show(PipShow.asleep);
      run(p, 6);
      expect(p.activity, PipActivity.asleep);
    });

    test('busy, a change waits (and is tried again)', () {
      final p = up();
      p.takeBattery(100);
      expect(p.show(PipShow.asleep), isFalse);
      run(p, 10);
      expect(p.show(PipShow.asleep), isTrue);
    });
  });
}
