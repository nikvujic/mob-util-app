import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_run.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Round 74: his break at the tavern (eating bite by bite, sitting
/// still), its new look, and his field's trees alike in every room.
void main() {
  const out = (onBreak: false, breakDone: 0.0);
  const onBreak = (onBreak: true, breakDone: 0.0);

  PipBrain atTable({bool ski = false, int seed = 1}) {
    final b = PipBrain(roomWidth: 200, random: math.Random(seed))
      ..skiing = ski
      ..snowy = ski;
    b.step(PipBrain.landEnd);
    b.adventure(out, animate: false);
    b.adventure(onBreak, animate: true);
    for (var i = 0; i < 60 * 30 && b.run!.phase != RunPhase.sitting; i++) {
      b.step(1 / 60);
    }
    expect(b.run!.phase, RunPhase.sitting);
    return b;
  }

  void steps(PipBrain b, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      b.step(1 / 60);
    }
  }

  test(
      'sitting: still on his bench (sitting or chewing, not up and down '
      'like squats)', () {
    final b = atTable();
    final heights = <double>{};
    final frames = <PipFrame>{};
    for (var i = 0; i < 60 * 12; i++) {
      b.step(1 / 60);
      heights.add(b.lift);
      frames.add(b.frame);
    }
    expect(frames, {PipFrame.sit, PipFrame.chew});
    expect(heights, hasLength(1), reason: 'he stays at the one height');
  });

  test(
      'eating, watched: bite by bite, his hand bringing each from the plate '
      'to his mouth; the plate empty after a few', () {
    final b = atTable();
    final run = b.run!;
    steps(b, PipRun.plateFlight + 0.1);
    expect(run.plateAt!.$3, 1, reason: 'a full plate');
    var carried = false;
    var reached = false;
    var chewed = false;
    final lefts = <double>[];
    for (var i = 0; i < 60 * 40; i++) {
      b.step(1 / 60);
      if (run.hand case (final hx, final hy, _, final carrying)) {
        carried = carried || carrying;
        reached = reached ||
            ((hx - (b.x + PipRun.mouthX)).abs() < 0.5 &&
                (hy - PipRun.mouthUp).abs() < 0.5);
      }
      chewed = chewed || b.frame == PipFrame.chew;
      final left = run.plateAt!.$3;
      if (lefts.isEmpty || lefts.last != left) lefts.add(left);
    }
    expect(carried, isTrue);
    expect(reached, isTrue, reason: 'up to his mouth');
    expect(chewed, isTrue);
    expect(lefts.length, PipRun.bitesPerMeal + 1, reason: 'a bite at a time');
    expect(lefts.last, 0, reason: 'all eaten');
    expect(run.hand, isNull, reason: 'done: no more bites');
  });

  test('not watched: eaten by a quarter of the way into his break', () {
    final b = atTable();
    b.adventure((onBreak: true, breakDone: 0.25), animate: true);
    steps(b, 0.1);
    expect(b.run!.plateAt!.$3, 0);
  });

  test('at the hut: the mug carried to his mouth for each sip, and back', () {
    final b = atTable(ski: true);
    final run = b.run!;
    steps(b, PipRun.plateFlight + 0.1);
    final rest = run.plateAt!;
    var atMouth = false;
    var backDown = false;
    for (var i = 0; i < 60 * 6; i++) {
      b.step(1 / 60);
      final hand = run.hand;
      if (hand != null && hand.$4) {
        atMouth = atMouth || (hand.$2 - PipRun.mouthUp).abs() < 0.5;
        if (atMouth) backDown = backDown || (hand.$2 - rest.$2) < 2;
      }
    }
    expect(atMouth, isTrue);
    expect(backDown, isTrue);
  });

  test(
      'his field\'s trees go by with his time out: two rooms (each its own '
      'run, the ground moved differently) agree; at his break they stand', () {
    final a = PipBrain(roomWidth: 200, random: math.Random(1));
    final b = PipBrain(roomWidth: 140, random: math.Random(2));
    for (final p in [a, b]) {
      p.step(PipBrain.landEnd);
      p.adventure(out, animate: false);
    }
    steps(a, 3);
    steps(b, 1);
    expect(a.run!.shift, isNot(closeTo(b.run!.shift, 1)));
    a.syncOutRun(600, paused: false);
    b.syncOutRun(600, paused: false);
    expect(fieldPassing(a), fieldPassing(b));
    steps(a, 0.5);
    steps(b, 0.5);
    expect(fieldPassing(a), closeTo(fieldPassing(b), 0.5));
    expect(fieldPassing(a), greaterThan(600 * PipRun.runSpeed * 0.5));
    a.syncOutRun(600, paused: true);
    final at = fieldPassing(a);
    steps(a, 2);
    expect(fieldPassing(a), at, reason: 'his break: they stand');
    // Not out: by the ground, as before.
    a.syncOutRun(null, paused: false);
    expect(fieldPassing(a), a.run!.shift.floor() * 0.5);
  });

  test('the tavern, its table and bench drawn in its colours', () {
    for (final art in [PipSprites.tavern, PipSprites.table, PipSprites.bench]) {
      expect(art.every((r) => r.length == art.first.length), isTrue);
      for (final c in art.join().split('')) {
        if (c != '.') {
          expect(PipSprites.tavernColours.containsKey(c), isTrue, reason: c);
          expect(PipSprites.hutColours.containsKey(c), isTrue, reason: c);
        }
      }
    }
    expect(PipSprites.tavern.first.length, 33);
    // The sitting frames: legs tucked, his face as he is.
    expect(PipSprites.frames[PipFrame.sit]!.length,
        PipSprites.frames[PipFrame.tuck]!.length);
    expect(PipSprites.frames[PipFrame.chew], PipSprites.frames[PipFrame.tuck]);
  });
}
