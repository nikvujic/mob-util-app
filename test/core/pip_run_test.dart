import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_run.dart';

/// Pip's day out, as it's drawn (Round 63): setting off, running, bugs,
/// his break at the tavern (Round 64), coming back.
void main() {
  const out = (onBreak: false, breakDone: 0.0);
  const onBreak = (onBreak: true, breakDone: 0.0);

  PipBrain standing() {
    final b = PipBrain(roomWidth: 200, random: math.Random(1));
    b.step(PipBrain.landEnd);
    expect(b.activity, PipActivity.standing);
    return b;
  }

  void steps(PipBrain b, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      b.step(1 / 60);
    }
  }

  test(
      'opened while he\'s out: simply running in the middle, the ground '
      'moving', () {
    final b = standing();
    b.adventure(out, animate: false);
    expect(b.activity, PipActivity.adventuring);
    final run = b.run!;
    expect(run.phase, RunPhase.running);
    expect(b.x, run.centre);
    expect(b.facingRight, isTrue);
    expect(b.sword, isNotNull);
    final from = run.shift;
    steps(b, 1);
    expect(run.shift - from, closeTo(PipRun.runSpeed, 1));
    expect(b.x, run.centre, reason: 'he stays in the middle');
  });

  test('just made (the app opened): straight out, no way in', () {
    final b = PipBrain(roomWidth: 200, random: math.Random(1));
    expect(b.freshSpawn, isTrue);
    b.adventure(out, animate: false);
    expect(b.activity, PipActivity.adventuring);
  });

  test('seen setting off: to the middle, the sword drawn, then running', () {
    final b = standing();
    b.x = 10;
    b.adventure(out, animate: true);
    expect(b.run!.phase, RunPhase.toCentre);
    expect(b.sword, isNull);
    steps(b, 8);
    expect(b.run!.phase, RunPhase.running);
    expect(b.x, b.run!.centre);
    expect(b.sword!.$4, 1);
  });

  test(
      'a bug coming: in from the edge, crawling closer (Round 72: never '
      'popping up beside him); struck, a poof and a buzz; he runs on', () {
    final b = standing();
    b.adventure(out, animate: false);
    b.takeBuzzes();
    expect(b.run!.bugComing(hits: false), isTrue);
    expect(b.run!.bugComing(hits: true), isFalse, reason: 'one at a time');
    var last = b.bug!.$1;
    expect(last, greaterThanOrEqualTo(200 - PipBrain.bugWidth),
        reason: 'at the edge');
    var poofed = false;
    for (var i = 0; i < 60 * 6; i++) {
      b.step(1 / 60);
      poofed = poofed || b.poof != null;
      if (b.bug case (final x, _, _)) {
        expect(last - x, lessThan(2), reason: 'no jumps');
        last = x;
      }
    }
    expect(poofed, isTrue);
    expect(b.bug, isNull);
    expect(b.takeBuzzes(), contains(PipBuzz.light));
    expect(b.run!.phase, RunPhase.running);
  });

  test(
      'one that gets him: knocked back, his sword flies off; he fetches it '
      'and runs on', () {
    final b = standing();
    b.adventure(out, animate: false);
    b.run!.bugComing(hits: true);
    for (var i = 0; i < 60 * 8 && b.run!.phase != RunPhase.knocked; i++) {
      b.step(1 / 60);
    }
    steps(b, 0.1);
    expect(b.run!.phase, RunPhase.knocked);
    expect(b.sword, isNull);
    expect(b.run!.lyingSword, isNotNull);
    expect(b.x, lessThan(b.run!.centre));
    steps(b, 1.5);
    final buzzes = b.takeBuzzes();
    expect(buzzes, containsAll([PipBuzz.medium, PipBuzz.heavy]));
    // Walking back for it, then picking it up.
    var picked = false;
    for (var i = 0; i < 60 * 8 && b.run!.phase != RunPhase.running; i++) {
      b.step(1 / 60);
      picked = picked || b.run!.phase == RunPhase.pickUp;
    }
    expect(picked, isTrue);
    expect(b.run!.phase, RunPhase.running);
    expect(b.run!.lyingSword, isNull);
    expect(b.sword, isNotNull);
    expect(b.x, b.run!.centre);
  });

  test(
      'his break: the tavern comes, he sits, the plate flies to the table; '
      'then back out', () {
    final b = standing();
    b.adventure(out, animate: false);
    b.adventure(onBreak, animate: true);
    steps(b, 0.1);
    expect(b.run!.phase, RunPhase.arriving);
    expect(b.run!.tavern, isNotNull);
    for (var i = 0; i < 60 * 20 && b.run!.phase != RunPhase.sitting; i++) {
      b.step(1 / 60);
    }
    expect(b.run!.phase, RunPhase.sitting);
    expect(b.sword, isNull, reason: 'put away');
    expect(b.facingRight, isFalse, reason: 'at the table');
    steps(b, 1);
    final (_, height, left) = b.run!.plateAt!;
    expect(height, closeTo(PipRun.tableHeight, 1e-9));
    expect(left, 1);
    b.adventure((onBreak: true, breakDone: 0.5), animate: true);
    expect(b.run!.plateAt!.$3, 0.5, reason: 'eaten as his break goes');
    b.adventure(out, animate: true);
    for (var i = 0; i < 60 * 10 && b.run!.phase != RunPhase.running; i++) {
      b.step(1 / 60);
    }
    expect(b.run!.phase, RunPhase.running);
    expect(b.sword, isNotNull);
  });

  test(
      'opened just as his break starts: he runs up to the tavern '
      '(Round 66)', () {
    final b = standing();
    b.adventure((onBreak: true, breakDone: 0.0), animate: false);
    expect(b.run!.phase, isNot(RunPhase.sitting));
    steps(b, 0.1);
    expect(b.run!.phase, RunPhase.arriving);
  });

  test('opened during his break: at the table, eating', () {
    final b = standing();
    b.adventure((onBreak: true, breakDone: 0.3), animate: false);
    expect(b.run!.phase, RunPhase.sitting);
    expect(b.run!.plateAt!.$3, closeTo(0.7, 1e-9));
    expect(b.run!.speed, 0);
  });

  test('18:00 seen: he slows to a stop and is back; unseen: back at once', () {
    final b = standing();
    b.adventure(out, animate: false);
    b.run!.bugComing(hits: false);
    b.adventure(null, animate: true);
    steps(b, 0.1);
    expect(b.run!.phase, RunPhase.ending);
    expect(b.bug!.$3, isTrue, reason: 'a bug still coming scurries off');
    steps(b, 2);
    expect(b.activity, isNot(PipActivity.adventuring));
    expect(b.run, isNull);

    final c = standing();
    c.adventure(out, animate: false);
    c.adventure(null, animate: false);
    expect(c.activity, PipActivity.standing);
  });

  test('registered: his sword held up high, then off he goes', () {
    final b = standing();
    expect(b.cheer(), isTrue);
    expect(b.cheering, isTrue);
    final (_, up, angle, _) = b.sword!;
    expect(up, greaterThan(PipBrain.height));
    expect(angle, 0);
    steps(b, PipRun.cheerTime + 6);
    expect(b.run!.phase, RunPhase.running);
  });

  test(
      'out, nothing else starts; his life\'s "awake" '
      'is him out', () {
    final b = standing();
    b.adventure(out, animate: false);
    for (final a in PipAnimation.values) {
      expect(mayStart(PipActivity.adventuring, a), isFalse);
    }
    expect(b.eat(), isFalse);
    expect(b.notify(), isFalse);
    expect(b.show(PipShow.awake), isTrue);
    expect(b.activity, PipActivity.adventuring);
  });

  test('a level up: a flash over him and a buzz, then gone', () {
    final b = standing();
    b.takeBuzzes();
    b.levelUp();
    expect(b.levelFlash, 0);
    steps(b, 0.5);
    expect(b.takeBuzzes(), [PipBuzz.medium, PipBuzz.light]);
    steps(b, PipBrain.levelFlashTime);
    expect(b.levelFlash, isNull);
  });

  test(
      'a battery given while he\'s out (Round 65): it flies to him, he '
      'catches it running; one at a time', () {
    final b = standing();
    b.adventure(out, animate: false);
    b.takeBuzzes();
    expect(b.canTakeBattery, isTrue);
    expect(b.takeBattery(10), isTrue);
    expect(b.canTakeBattery, isFalse, reason: 'one in the air');
    final (from, high) = b.battery!;
    expect(from, 10);
    expect(high, PipBrain.dropHeight);
    steps(b, PipRun.batteryFlight / 2);
    expect(b.battery!.$1, greaterThan(10));
    expect(b.run!.phase, RunPhase.running);
    steps(b, PipRun.batteryFlight);
    expect(b.battery, isNull);
    expect(b.takeBuzzes(), contains(PipBuzz.light));
    expect(b.canTakeBattery, isTrue);
  });
}
