import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Round 53: a longer wake-up, a crouch to pick a flower, the flower in
/// his hand, the sword held out, bigger bugs, buzzes where things hit, no
/// pictures on his screen just for fun, and his screen reading right
/// when he faces left.
void main() {
  PipBrain up({int width = 140, int seed = 3}) => PipBrain(
        roomWidth: width,
        random: math.Random(seed),
      )
        ..skyRows = 59
        ..step(PipBrain.landEnd);

  void run(PipBrain pip, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      pip.step(1 / 60);
    }
  }

  PipBrain asleep() {
    final p = up()..show(PipShow.fallAsleep);
    run(p, 3);
    expect(p.activity, PipActivity.asleep);
    return p;
  }

  test('waking up takes longer: eyes shut a while, a stretch, then the hop',
      () {
    final p = asleep()..show(PipShow.wakeUp);
    run(p, 0.8);
    expect(p.face, PipFace.asleep, reason: 'eyes still shut');
    run(p, 0.5); // 1.3 s: stretching up, on the ground
    expect(p.stretch.$2, greaterThan(1.05));
    expect(p.lift, lessThanOrEqualTo(0));
    run(p, 0.8); // 2.1 s: the hop
    expect(p.lift, greaterThan(0));
    expect(p.activity, PipActivity.wakingUp);
    run(p, 0.5);
    expect(p.activity, isNot(PipActivity.wakingUp));
  });

  test('picking a flower: he crouches, his feet staying on the ground', () {
    final p = up(seed: 5)..play(PipAnimation.flower);
    var crouched = false;
    for (var i = 0; i < 60 * 30 && p.flowerHand == null; i++) {
      p.step(1 / 60);
      if (p.stretch.$2 < 0.95) {
        crouched = true;
        expect(p.lift, 0, reason: 'feet on the ground');
        expect(p.frame, isNot(PipFrame.tuck), reason: 'legs not tucked up');
      }
    }
    expect(crouched, isTrue);
  });

  test("the flower's stem goes down into his hand", () {
    for (final left in [false, true]) {
      final p = up(seed: 5)..play(PipAnimation.flower);
      for (var i = 0; i < 60 * 30 && p.flowerHand == null; i++) {
        p.step(1 / 60);
      }
      p.facingRight = !left;
      final (fx, foot, _, _) = p.flower!;
      final (hx, hy) = p.flowerHand!;
      // The stem's foot below the top of the hand (hy), not over it.
      expect(foot, lessThan(hy), reason: left ? 'left' : 'right');
      // Its stem (drawn from fx - 1, third column) inside the hand's two.
      final stem = fx - 1 + 2;
      expect(stem, inInclusiveRange(hx, hx + 1), reason: left ? 'L' : 'R');
    }
  });

  test('the sword: held out beside him, leaning away from him', () {
    for (final right in [true, false]) {
      final p = up()..facingRight = right;
      expect(p.play(PipAnimation.bugs), isTrue);
      var angles = 0;
      for (var i = 0; i < 60 * 60 && p.activity == PipActivity.bugHunt; i++) {
        p.step(1 / 60);
        final sword = p.sword;
        if (sword == null) continue;
        final (hx, _, angle, size) = sword;
        if (size < 0.5) continue;
        final away = p.facingRight ? angle > 0 : angle < 0;
        expect(away, isTrue, reason: 'leaning away, angle $angle');
        expect(p.facingRight ? hx > p.x + PipBrain.width : hx < p.x, isTrue,
            reason: 'beside him, not over him');
        angles++;
      }
      expect(angles, greaterThan(10));
    }
  });

  test('bugs are bigger (8 wide), their legs stepping', () {
    expect(PipBrain.bugWidth, 8);
    for (final b in [PipSprites.bugUp, PipSprites.bugDown]) {
      expect(b, everyElement(hasLength(PipBrain.bugWidth)));
      expect(b.length, greaterThanOrEqualTo(6));
    }
    expect(PipSprites.bugUp.last, isNot(PipSprites.bugDown.last));
  });

  test("the sword's grip is where the hand holds it", () {
    expect(
        PipSprites.sword[PipSprites.swordGrip].trim().replaceAll('.', ''), 't');
    expect(PipSprites.sword.first.length, greaterThanOrEqualTo(5));
  });

  group('buzzes', () {
    test('landing from the sky: a medium one, once', () {
      final p = up()..enter(PipEntrance.sky);
      final buzzes = <PipBuzz>[];
      for (var i = 0; i < 60 * 10 && p.activity == PipActivity.falling; i++) {
        p.step(1 / 60);
        buzzes.addAll(p.takeBuzzes());
      }
      expect(buzzes, [PipBuzz.medium]);
    });

    test('landing from a throw: a heavy one, once', () {
      final p = up()..enter(PipEntrance.side);
      final buzzes = <PipBuzz>[];
      for (var i = 0; i < 60 * 10 && p.activity == PipActivity.thrown; i++) {
        p.step(1 / 60);
        buzzes.addAll(p.takeBuzzes());
      }
      expect(buzzes, [PipBuzz.heavy]);
    });

    test('a bug struck: a light one each; the ball kicked: a medium one', () {
      final bugs = up()..play(PipAnimation.bugs);
      final struck = <PipBuzz>[];
      var poofs = 0;
      var wasPoof = false;
      for (var i = 0;
          i < 60 * 60 && bugs.activity == PipActivity.bugHunt;
          i++) {
        bugs.step(1 / 60);
        struck.addAll(bugs.takeBuzzes());
        if (bugs.poof != null && !wasPoof) poofs++;
        wasPoof = bugs.poof != null;
      }
      expect(struck, List.filled(poofs, PipBuzz.light));
      final ball = up(seed: 7)..play(PipAnimation.ball);
      final kicked = <PipBuzz>[];
      for (var i = 0; i < 60 * 30 && ball.activity == PipActivity.ball; i++) {
        ball.step(1 / 60);
        kicked.addAll(ball.takeBuzzes());
      }
      expect(kicked, [PipBuzz.medium]);
    });

    test('taken once: then none until the next', () {
      final p = up(seed: 7)..play(PipAnimation.ball);
      run(p, 30);
      expect(p.takeBuzzes(), isNotEmpty);
      expect(p.takeBuzzes(), isEmpty);
    });
  });

  test(
      'nothing on his screen just for fun: only notifications, his pill, '
      'music and the happy face', () {
    expect(PipScreen.values.map((s) => s.name),
        ['envelope', 'bell', 'alert', 'pill', 'music', 'happy']);
    // Hours of standing about: events, but never a picture on his own.
    for (var seed = 0; seed < 4; seed++) {
      final p = up(seed: seed);
      final seen = <PipActivity>{};
      for (var i = 0; i < 60 * 60 * 20; i++) {
        p.step(1 / 60);
        seen.add(p.activity);
        if (p.activity == PipActivity.angry) break;
      }
      expect(seen, isNot(contains(PipActivity.showing)), reason: 'seed $seed');
      expect(
          seen.intersection({
            PipActivity.bugHunt,
            PipActivity.flower,
            PipActivity.butterfly,
            PipActivity.ball,
            PipActivity.dancing,
          }),
          isNotEmpty,
          reason: 'events still happen');
    }
  });

  test('facing left, his screen reads right: its picture is turned first', () {
    for (final s in PipScreen.values) {
      final frame = PipSprites.screenFrame(s, 0.3);
      final turned = PipSprites.screenTurned(frame);
      // Drawn mirrored, the turned frame's screen is the picture as is.
      final mirrored = [
        for (final row in turned) row.split('').reversed.join(),
      ];
      final top =
          PipSprites.screenFrame(s, 0.3).indexWhere((r) => r.contains('W'));
      for (var y = top; y < top + PipSprites.screenRows; y++) {
        expect(mirrored[y].substring(3, 3 + PipSprites.screenWidth),
            frame[y].substring(3, 3 + PipSprites.screenWidth),
            reason: '${s.name} row $y');
      }
      expect(turned.length, frame.length);
    }
  });
}
