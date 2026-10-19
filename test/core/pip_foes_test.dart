import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_run.dart';

/// What he fights on his day out (Round 73): bugs, bigger ones that take
/// more strikes, a boss once a day out; what he strikes down counted for
/// his XP while he's watched, the XP gained rising over it.
void main() {
  const out = (onBreak: false, breakDone: 0.0);

  PipBrain running({int seed = 1}) {
    final b = PipBrain(roomWidth: 200, random: math.Random(seed));
    b.step(PipBrain.landEnd);
    b.adventure(out, animate: false);
    b.takeBuzzes();
    return b;
  }

  void steps(PipBrain b, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      b.step(1 / 60);
    }
  }

  /// Steps till [foe] is struck down (or [seconds] pass): the strikes it
  /// took, and whether it ever came closer than his reach (into him).
  (int, bool) fight(PipBrain b, PipFoe foe, {double seconds = 20}) {
    final run = b.run!;
    expect(run.bugComing(hits: false, foe: foe), isTrue);
    var struck = 0;
    var left = run.foeHitsLeft;
    var past = false;
    for (var i = 0; i < seconds * 60 && b.bug != null; i++) {
      b.step(1 / 60);
      if (b.bug case (final x, _, _)) {
        // Struck at or staggering, it keeps about his reach away.
        past = past || x - (b.x + PipBrain.width) < PipBrain.reach - 1;
        if (run.foeHitsLeft < left) struck++;
        left = run.foeHitsLeft;
      }
    }
    return (struck, past);
  }

  test('a beetle takes two strikes, staggering back from the first', () {
    final b = running();
    final (struck, past) = fight(b, PipFoe.beetle);
    expect(struck, 1, reason: 'one strike it took standing');
    expect(past, isFalse, reason: 'never into him');
    expect(b.bug, isNull);
    expect(b.takeDefeats(), [PipFoe.beetle]);
  });

  test('a spider three; the boss six, each a medium buzz, a heavy last', () {
    final b = running();
    expect(fight(b, PipFoe.spider).$1, 2);
    expect(b.takeDefeats(), [PipFoe.spider]);
    b.takeBuzzes();
    final (struck, past) = fight(b, PipFoe.boss, seconds: 30);
    expect(struck, 5);
    expect(past, isFalse);
    expect(b.takeDefeats(), [PipFoe.boss]);
    final buzzes = b.takeBuzzes();
    expect(buzzes.where((z) => z == PipBuzz.medium).length, 5);
    expect(buzzes.last, PipBuzz.heavy);
    expect(b.run!.poofSize, greaterThan(2), reason: 'a bigger poof');
  });

  test('a bug: one strike, as before', () {
    final b = running();
    expect(fight(b, PipFoe.bug).$1, 0);
    expect(b.takeDefeats(), [PipFoe.bug]);
  });

  test('struck at, it flashes; the strikes left show', () {
    final b = running();
    final run = b.run!;
    run.bugComing(hits: false, foe: PipFoe.beetle);
    expect(run.foeHitsLeft, 2);
    var flashed = false;
    for (var i = 0; i < 60 * 10 && run.foeHitsLeft == 2; i++) {
      b.step(1 / 60);
    }
    for (var i = 0; i < 20; i++) {
      flashed = flashed || run.foeFlash;
      b.step(1 / 60);
    }
    expect(run.foeHitsLeft, 1);
    expect(flashed, isTrue);
  });

  test(
      'what comes: mostly bugs, now and then a beetle or a spider; the '
      'boss only while one may come, and once', () {
    for (final due in [false, true]) {
      final b = running(seed: 7);
      final run = b.run!;
      run.bossDue = due;
      b.bossDue = due;
      final seen = <PipFoe, int>{};
      var coming = false;
      for (var i = 0; i < 60 * 60 * 60; i++) {
        b.step(1 / 60);
        final now = b.bug != null && !(b.bug!.$3);
        if (now && !coming) seen[run.foe] = (seen[run.foe] ?? 0) + 1;
        coming = now;
      }
      final all = seen.values.fold(0, (a, n) => a + n);
      expect(all, greaterThan(300));
      expect(seen[PipFoe.bug]! / all, closeTo(0.7, 0.1));
      expect(seen[PipFoe.beetle]! / all, closeTo(0.22, 0.07));
      expect(seen[PipFoe.spider]! / all, closeTo(0.08, 0.05));
      expect(seen[PipFoe.boss] ?? 0, due ? 1 : 0, reason: 'due: $due');
      b.takeDefeats();
    }
  });

  test(
      'one that got him runs off and is gone, even once he runs again '
      '(it used to stay on the screen, and no other came)', () {
    final b = running();
    final run = b.run!;
    run.bugComing(hits: true);
    for (var i = 0; i < 60 * 8 && run.phase != RunPhase.knocked; i++) {
      b.step(1 / 60);
    }
    expect(b.bug!.$3, isTrue, reason: 'running off');
    for (var i = 0; i < 60 * 6 && b.bug != null; i++) {
      b.step(1 / 60);
    }
    expect(b.bug, isNull);
    // Then others come.
    var came = false;
    for (var i = 0; i < 60 * 10 && !came; i++) {
      b.step(1 / 60);
      came = b.bug != null && !b.bug!.$3;
    }
    expect(came, isTrue);
  });

  test('the boss never gets him first', () {
    final b = running();
    final run = b.run!;
    run.bugComing(hits: true, foe: PipFoe.boss);
    for (var i = 0; i < 60 * 30 && b.bug != null; i++) {
      b.step(1 / 60);
      expect(run.phase, isNot(RunPhase.knocked));
    }
  });

  test('the XP gained rises where the foe was, on the screen, then goes', () {
    final b = running();
    fight(b, PipFoe.bug);
    final poof = b.poof!.$1;
    b.showXp(2);
    final (xp, x, f) = b.run!.xpRising.single;
    expect((xp, x, f), (2, poof, 0));
    steps(b, 0.5);
    final (_, x2, f2) = b.run!.xpRising.single;
    expect(x2, x, reason: 'it stays put as the ground moves');
    expect(f2, greaterThan(0.3));
    steps(b, PipRun.xpPopTime);
    expect(b.run!.xpRising, isEmpty);
  });

  test(
      'fighting: out for real, running or fetching his sword; not in a '
      'preview, on skis or at his break', () {
    final b = running();
    expect(b.fighting, isTrue);
    b.run!.bugComing(hits: true);
    for (var i = 0; i < 60 * 8 && b.run!.phase != RunPhase.knocked; i++) {
      b.step(1 / 60);
    }
    expect(b.fighting, isTrue, reason: 'knocked, still out fighting');
    b.adventure((onBreak: true, breakDone: 0.0), animate: true);
    steps(b, 20);
    expect(b.run!.phase, RunPhase.sitting);
    expect(b.fighting, isFalse);

    final preview = PipBrain(roomWidth: 200, random: math.Random(1));
    preview.step(PipBrain.landEnd);
    expect(preview.previewAdventure(), isTrue);
    steps(preview, 8);
    expect(preview.fighting, isFalse);

    final ski = PipBrain(roomWidth: 200, random: math.Random(1))..skiing = true;
    ski.step(PipBrain.landEnd);
    ski.adventure(out, animate: false);
    expect(ski.fighting, isFalse);
  });

  test(
      "Pip Home's previews: a beetle in the adventure; the boss's own; "
      'nothing counted', () {
    final b = PipBrain(roomWidth: 200, random: math.Random(1));
    b.step(PipBrain.landEnd);
    b.bossDue = true;
    expect(b.previewAdventure(), isTrue);
    final foes = <PipFoe>{};
    for (var i = 0; i < 60 * PipBrain.previewLength; i++) {
      b.step(1 / 60);
      if (b.bug != null) foes.add(b.run!.foe);
      expect(b.takeDefeats(), isEmpty);
    }
    expect(foes, {PipFoe.bug, PipFoe.beetle});
    steps(b, 3);
    expect(b.activity, isNot(PipActivity.adventuring));

    expect(b.previewAdventure(boss: true), isTrue);
    var downed = false;
    for (var i = 0; i < 60 * PipBrain.previewLength; i++) {
      b.step(1 / 60);
      if (b.bug != null) expect(b.run!.foe, PipFoe.boss);
      downed = downed || (b.run?.poofSize ?? 0) > 2;
      expect(b.takeDefeats(), isEmpty);
    }
    expect(downed, isTrue, reason: 'beaten within the preview');
  });
}
