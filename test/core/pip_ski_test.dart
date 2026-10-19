import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_adventure.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_bus.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_run.dart';

/// Pip's ski days and his trip's bus (Round 67).
void main() {
  const out = (onBreak: false, breakDone: 0.0);
  const riding =
      (leg: TripLeg.there, progress: 0.3, snowy: false, skiing: false);

  PipBrain standing({bool ski = false}) {
    final b = PipBrain(roomWidth: 200, random: math.Random(1));
    b.step(PipBrain.landEnd);
    b.snowy = ski;
    b.skiing = ski;
    return b;
  }

  void steps(PipBrain b, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      b.step(1 / 60);
    }
  }

  group('a ski day', () {
    test('a ski beanie (a birthday wins); his gear in its snowbank', () {
      final b = standing(ski: true);
      expect(b.hat, PipHat.skiBeanie);
      expect(b.gearInBank, isTrue);
      b.birthday = true;
      expect(b.hat, PipHat.party);
      expect(standing().gearInBank, isFalse);
    });

    test(
        'opened while out: skiing, gear on, the slope going by; no sword, '
        'no bugs', () {
      final b = standing(ski: true);
      b.adventure(out, animate: false);
      final run = b.run!;
      expect(run.skiing, isTrue);
      expect(run.geared, isTrue);
      expect(b.gearInBank, isFalse);
      expect(b.sword, isNull);
      steps(b, 6);
      expect(run.drop, greaterThan(30));
      expect(run.shift, 0, reason: 'the ground doesn\'t move');
      expect(run.slope, isNotEmpty);
      expect(b.bug, isNull);
      // Round 72: down the slope, a gentle slalom about the middle.
      expect(run.downhill, isTrue);
      expect((b.x - run.centre).abs(), lessThanOrEqualTo(5.01));
      // ...side to side, not straight down.
      final xs = <double>{};
      for (var i = 0; i < 80; i++) {
        steps(b, 0.1);
        xs.add(b.x.roundToDouble());
      }
      expect(xs.length, greaterThanOrEqualTo(5));
    });

    test(
        'the slope (Round 72): what he passes comes up from below him and '
        'shrinks away to the horizon; there from the start', () {
      final b = standing(ski: true);
      b.adventure(out, animate: false);
      final run = b.run!;
      expect(run.slope.length, greaterThan(5), reason: 'already dotted');
      steps(b, 3);
      final fresh = run.slope.where((s) => run.drop - s.at < 0);
      expect(fresh, isNotEmpty, reason: 'new ones still below him');
      expect(
          run.slope.every((s) => run.drop - s.at <= PipRun.farthest), isTrue);
      // Nearer, bigger and further out; far off, small, near the middle.
      expect(PipRun.nearness(-10), greaterThan(1));
      expect(PipRun.nearness(0), 1);
      expect(PipRun.nearness(PipRun.farthest), lessThan(0.15));
      // Clear of his lane at his feet.
      for (final s in run.slope) {
        expect(
            s.x <= run.centre - 14 || s.x >= run.centre + PipBrain.width + 10,
            isTrue);
      }
    });

    test(
        'seen setting off: to his gear, takes it, and down the slope '
        '(Round 72: not walked to the middle on skis)', () {
      final b = standing(ski: true);
      b.x = 120;
      b.adventure(out, animate: true);
      expect(b.run!.phase, RunPhase.toGear);
      var took = false;
      for (var i = 0; i < 60 * 20 && b.run!.phase != RunPhase.running; i++) {
        b.step(1 / 60);
        took = took || b.run!.phase == RunPhase.takeGear;
      }
      expect(took, isTrue);
      expect(b.run!.geared, isTrue);
      expect(b.run!.phase, RunPhase.running);
      expect(b.run!.downhill, isTrue);
    });

    test(
        'a fall: tumbling, a ski off beside him; he clicks back in where he '
        'is (Round 72: no walking over) and goes on', () {
      final b = standing(ski: true);
      b.adventure(out, animate: false);
      b.takeBuzzes();
      b.run!.fallNow();
      steps(b, 0.1);
      expect(b.run!.phase, RunPhase.skiFall);
      expect(b.spin, isNot(0));
      expect(b.takeBuzzes(), contains(PipBuzz.medium));
      steps(b, PipRun.fallTime);
      expect(b.run!.skiAt, greaterThan(b.x + PipBrain.width));
      var on = false;
      final where = b.x;
      for (var i = 0; i < 60 * 10 && b.run!.phase != RunPhase.running; i++) {
        b.step(1 / 60);
        on = on || b.run!.phase == RunPhase.skiOn;
        expect(b.run!.phase, isNot(RunPhase.toSki));
        expect(b.x, where);
      }
      expect(on, isTrue);
      expect(b.run!.skiAt, isNull);
      expect(b.run!.skisOn, isTrue);
    });

    test('falls every 40–90 seconds', () {
      expect(PipRun.fallFrom, 40);
      expect(PipRun.fallFrom + PipRun.fallSpread, 90);
    });

    test('a bump: a hop, a light buzz on landing', () {
      final b = standing(ski: true);
      b.adventure(out, animate: false);
      b.takeBuzzes();
      var hopped = false;
      for (var i = 0; i < 60 * 20; i++) {
        b.step(1 / 60);
        hopped = hopped || b.run!.lift > 1;
      }
      expect(hopped, isTrue);
      expect(b.takeBuzzes(), contains(PipBuzz.light));
    });

    test('his break: the hut, the mug emptying, his skis off', () {
      final b = standing(ski: true);
      b.adventure((onBreak: true, breakDone: 0.1), animate: false);
      expect(b.run!.phase, RunPhase.sitting);
      expect(b.run!.plateAt!.$3, closeTo(0.6, 1e-9));
      expect(b.run!.skisOn, isFalse);
    });

    test('at 18:00, seen: he stops and puts his gear back', () {
      final b = standing(ski: true);
      b.adventure(out, animate: false);
      b.adventure(null, animate: true);
      var put = false;
      for (var i = 0; i < 60 * 30 && b.run != null; i++) {
        b.step(1 / 60);
        put = put || b.run?.phase == RunPhase.putGear;
      }
      expect(put, isTrue);
      expect(b.activity, PipActivity.standing);
      expect(b.gearInBank, isTrue);
    });
  });

  group('the bus', () {
    test('opened on it: him in its window, no hat, nothing else', () {
      final b = standing();
      b.dayHat = PipHat.crown;
      b.ride(riding, animate: false);
      expect(b.activity, PipActivity.riding);
      expect(b.bus!.inside, isTrue);
      expect(b.hat, isNull);
      expect(b.x, b.bus!.busX + PipBus.seatX);
      b.snowy = true;
      expect(b.gearInBank, isFalse, reason: 'his gear goes with him');
      expect(b.canTakeBattery, isFalse);
      expect(b.eat(), isFalse);
      for (final a in PipAnimation.values) {
        expect(mayStart(PipActivity.riding, a), isFalse);
      }
      final road = b.bus!.road;
      steps(b, 1);
      expect(b.bus!.road - road, closeTo(PipBus.roadSpeed, 1));
    });

    test('at night he dozes in his seat', () {
      final b = standing();
      b.ride(riding, animate: false);
      expect(b.show(PipShow.asleep), isTrue);
      expect(b.face, PipFace.asleep);
      expect(b.zs, isNotEmpty);
      b.show(PipShow.awake);
      expect(b.face, isNot(PipFace.asleep));
    });

    test('seen leaving: it pulls in, the door opens, he gets on, it drives',
        () {
      final b = standing();
      b.ride(riding, animate: true);
      expect(b.bus!.phase, BusPhase.pullingIn);
      expect(b.bus!.inside, isFalse);
      var door = false;
      for (var i = 0; i < 60 * 20 && b.bus!.phase != BusPhase.riding; i++) {
        b.step(1 / 60);
        door = door || b.bus!.doorOpen;
      }
      expect(door, isTrue);
      expect(b.bus!.inside, isTrue);
    });

    test('seen arriving: it stops, he steps out, it drives off', () {
      final b = standing();
      b.ride(riding, animate: false);
      b.ride(noTrip, animate: true);
      for (var i = 0; i < 60 * 20 && b.bus != null; i++) {
        b.step(1 / 60);
      }
      expect(b.activity, PipActivity.standing);
    });

    test('unseen arriving: simply back', () {
      final b = standing();
      b.ride(riding, animate: false);
      b.ride(noTrip, animate: false);
      expect(b.activity, PipActivity.standing);
    });

    test('out on his adventure when the bus comes: on the bus', () {
      final b = standing();
      b.adventure(out, animate: false);
      b.ride(riding, animate: false);
      expect(b.activity, PipActivity.riding);
    });

    test('the preview: it drives a while and he gets off', () {
      final b = standing();
      expect(b.previewBus(), isTrue);
      for (var i = 0; i < 60 * 30 && b.bus != null; i++) {
        b.step(1 / 60);
      }
      expect(b.activity, PipActivity.standing);
    });
  });

  group('Pip Home\'s previews', () {
    test(
        'an adventure: set off, bugs, home by itself; his life can\'t end '
        'it early', () {
      final b = standing();
      expect(b.previewAdventure(), isTrue);
      expect(b.run!.skiing, isFalse);
      b.adventure(null, animate: true);
      expect(b.run!.phase, isNot(RunPhase.ending), reason: 'a preview');
      var bugs = false;
      for (var i = 0; i < 60 * 30 && b.run != null; i++) {
        b.step(1 / 60);
        bugs = bugs || b.bug != null;
      }
      expect(bugs, isTrue);
      expect(b.activity, PipActivity.standing);
    });

    test('skiing: snowing, his gear, a fall; then the snow\'s gone', () {
      final b = standing();
      expect(b.previewAdventure(ski: true), isTrue);
      expect(b.snowing, isTrue);
      expect(b.hat, PipHat.skiBeanie);
      var fell = false;
      for (var i = 0; i < 60 * 40 && b.run != null; i++) {
        b.step(1 / 60);
        fell = fell || b.run?.phase == RunPhase.skiFall;
      }
      expect(fell, isTrue);
      expect(b.snowing, isFalse);
    });

    test('stopped (back on his info card): at once', () {
      final b = standing();
      b.previewAdventure();
      b.stopPreviews();
      expect(b.activity, PipActivity.standing);
      b.previewBus();
      b.ride(noTrip, animate: false);
      expect(b.activity, PipActivity.riding, reason: 'a preview');
      b.stopPreviews();
      expect(b.activity, PipActivity.standing);
    });

    test('not while he\'s really out', () {
      final b = standing();
      b.adventure(out, animate: false);
      expect(b.previewAdventure(), isFalse);
      expect(b.previewBus(), isFalse);
    });
  });
}
