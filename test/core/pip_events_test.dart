import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Round 52: his entrances, the things that happen in his field, his
/// screen's pictures, and the richer skies.
void main() {
  /// Pip up and about in a room [width] wide.
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

  /// Steps until he's no longer [doing] (at most [limit] seconds); the
  /// seconds it took.
  double until(PipBrain pip, PipActivity doing, {double limit = 60}) {
    var t = 0.0;
    for (; t < limit && pip.activity == doing; t += 1 / 60) {
      pip.step(1 / 60);
    }
    return t;
  }

  group('entrances', () {
    test(
        'from the sky: he drops from above the room, lands with a squash '
        'and dust, then stands', () {
      final pip = up()..enter(PipEntrance.sky);
      expect(pip.activity, PipActivity.falling);
      expect(pip.lift, greaterThan(59), reason: 'above the room');
      run(pip, 0.3);
      final higher = pip.lift;
      run(pip, 0.1);
      expect(pip.lift, lessThan(higher), reason: 'falling');
      // Landed: on the ground, squashed, dust either side.
      while (pip.lift > 0) {
        pip.step(1 / 60);
      }
      pip.step(0.05);
      expect(pip.landingDust, isNotNull);
      expect(pip.stretch.$1, greaterThan(1));
      expect(pip.stretch.$2, lessThan(1));
      until(pip, PipActivity.falling);
      expect(pip.activity, PipActivity.standing);
      expect(pip.landingDust, isNull);
    });

    test(
        'thrown in from the side: from beyond the left edge, tumbling, '
        'lands a third in, then angry (a scowl, a fist), then calm', () {
      final pip = up()..enter(PipEntrance.side);
      expect(pip.activity, PipActivity.thrown);
      expect(pip.x, lessThan(0), reason: 'beyond the edge');
      pip.step(0.05);
      expect(pip.x, lessThan(0), reason: 'still coming in from there');
      run(pip, PipBrain.throwTime / 2);
      expect(pip.spin, isNot(0), reason: 'tumbling');
      expect(pip.lift, greaterThan(4), reason: 'on an arc');
      until(pip, PipActivity.thrown);
      expect(pip.activity, PipActivity.angry);
      expect(pip.x, closeTo(140 * 0.3, 1));
      expect(pip.spin, 0);
      expect(pip.face, PipFace.angry);
      expect(pip.fist, isNotNull);
      final t = until(pip, PipActivity.angry);
      expect(t, closeTo(PipBrain.angryTime, 0.05));
      expect(pip.activity, PipActivity.standing);
      expect(pip.fist, isNull);
      expect(pip.face, PipFace.normal);
    });

    test('from the ground, as before', () {
      final pip = up()..enter(PipEntrance.ground);
      expect(pip.activity, PipActivity.spawning);
      expect(pip.freshSpawn, isTrue);
    });
  });

  group('things happening', () {
    test('only up and about: asleep, off, charging, mid-entrance: no', () {
      final events = [
        PipAnimation.bugs,
        PipAnimation.screen,
        PipAnimation.notified,
        PipAnimation.flower,
        PipAnimation.butterfly,
        PipAnimation.ball,
      ];
      for (final a in events) {
        expect(mayStart(PipActivity.standing, a), isTrue, reason: a.name);
        expect(mayStart(PipActivity.walking, a), isTrue, reason: a.name);
        for (final busy in [
          PipActivity.asleep,
          PipActivity.off,
          PipActivity.charging,
          PipActivity.falling,
          PipActivity.thrown,
          PipActivity.angry,
          PipActivity.bugHunt,
          PipActivity.showing,
          PipActivity.flower,
          PipActivity.butterfly,
          PipActivity.ball,
        ]) {
          expect(mayStart(busy, a), isFalse, reason: '${busy.name} ${a.name}');
        }
      }
    });

    test(
        'bugs: the sword pops in, each bug comes, is struck, goes poof; '
        'then he puts it away, proud', () {
      var most = 0;
      for (var seed = 0; seed < 6; seed++) {
        final pip = up(seed: seed);
        expect(pip.play(PipAnimation.bugs), isTrue);
        expect(pip.sword, isNotNull);
        expect(pip.sword!.$4, lessThan(0.5), reason: 'popping in');
        var poofs = 0;
        var wasPoof = false;
        var sawBug = false;
        for (var i = 0;
            i < 60 * 60 && pip.activity == PipActivity.bugHunt;
            i++) {
          pip.step(1 / 60);
          sawBug |= pip.bug != null;
          final poof = pip.poof != null;
          if (poof && !wasPoof) poofs++;
          wasPoof = poof;
          expect(pip.x, inInclusiveRange(0, 140 - PipBrain.width));
        }
        expect(pip.activity, PipActivity.standing, reason: 'seed $seed');
        expect(sawBug, isTrue);
        expect(poofs, inInclusiveRange(1, 3), reason: 'seed $seed');
        most = math.max(most, poofs);
        expect(pip.sword, isNull);
        expect(pip.bug, isNull);
      }
      expect(most, greaterThan(1), reason: 'sometimes more than one');
    });

    test('his screen: a picture a while, then his face again', () {
      final pip = up()..debugShow(PipScreen.heart);
      expect(pip.screenShow?.$1, PipScreen.heart);
      until(pip, PipActivity.showing);
      expect(pip.screenShow, isNull);
      expect(pip.play(PipAnimation.screen), isTrue);
      expect(pip.screenShow!.$1.notification, isFalse, reason: 'for fun');
    });

    test(
        'a notification: his screen shows one (with a hop), only if he '
        "isn't asleep or busy", () {
      final pip = up();
      expect(pip.notify(), isTrue);
      expect(pip.screenShow!.$1.notification, isTrue);
      pip.step(0.2);
      expect(pip.lift, greaterThan(0), reason: 'a hop');
      expect(pip.notify(), isFalse, reason: 'already showing one');
      final asleep = up()..show(PipShow.asleep);
      until(asleep, PipActivity.fallingAsleep);
      expect(asleep.notify(), isFalse);
    });

    test(
        'a flower: it comes up, he walks over, picks it, holds it, it '
        'fades', () {
      final pip = up(seed: 5);
      expect(pip.play(PipAnimation.flower), isTrue);
      final (fx, up0, grown, _) = pip.flower!;
      expect(up0, 0, reason: 'in the ground');
      expect(grown, lessThan(0.1), reason: 'just coming up');
      expect((fx - (pip.x + PipBrain.width / 2)).abs(), greaterThan(8),
          reason: 'a few steps away');
      for (var i = 0; i < 60 * 30 && pip.flowerHand == null; i++) {
        pip.step(1 / 60);
      }
      expect(pip.flowerHand, isNotNull, reason: 'picked, in his hand');
      expect(pip.flower!.$2, greaterThan(0), reason: 'off the ground');
      expect(pip.screenShow?.$1, PipScreen.happy);
      until(pip, PipActivity.flower);
      expect(pip.activity, PipActivity.standing);
      expect(pip.flower, isNull);
    });

    test('a butterfly flutters across; he turns to watch it', () {
      final pip = up(seed: 2)..x = 60;
      expect(pip.play(PipAnimation.butterfly), isTrue);
      final fromRight = pip.butterfly!.$1 > 70;
      final facings = <bool>{};
      for (var i = 0;
          i < 60 * 30 && pip.activity == PipActivity.butterfly;
          i++) {
        pip.step(1 / 60);
        facings.add(pip.facingRight);
      }
      expect(pip.activity, PipActivity.standing);
      expect(facings, {true, false}, reason: 'it passed him: he turned');
      expect(fromRight, isA<bool>());
    });

    test('a ball rolls in and stops; he walks up and kicks it away', () {
      final pip = up(seed: 7);
      expect(pip.play(PipAnimation.ball), isTrue);
      var kicked = false;
      for (var i = 0; i < 60 * 30 && pip.activity == PipActivity.ball; i++) {
        final before = pip.ball;
        pip.step(1 / 60);
        final after = pip.ball;
        if (before != null && after != null && after.$2 > 0) kicked = true;
      }
      expect(kicked, isTrue, reason: 'it flew off the ground');
      expect(pip.activity, PipActivity.standing);
      expect(pip.ball, isNull);
    });

    test('a narrow room: nothing comes in (no room to)', () {
      final pip = up(width: 50);
      expect(pip.play(PipAnimation.bugs), isFalse);
      expect(pip.play(PipAnimation.flower), isFalse);
      expect(pip.play(PipAnimation.ball), isFalse);
    });

    test(
        'they happen on their own now and then, not at bedtime or with the '
        'station up', () {
      final pip = up(seed: 11);
      final seen = <PipActivity>{};
      for (var i = 0; i < 60 * 60 * 20; i++) {
        pip.step(1 / 60);
        seen.add(pip.activity);
      }
      expect(
          seen.intersection({
            PipActivity.bugHunt,
            PipActivity.showing,
            PipActivity.flower,
            PipActivity.butterfly,
            PipActivity.ball,
          }),
          isNotEmpty);

      // Full, he ignores the station but stands about beside it: still no
      // bugs or flowers while it's up.
      final charging = up(seed: 11)
        ..segments = 3
        ..setPlugged(true, animate: false);
      final busy = <PipActivity>{};
      for (var i = 0; i < 60 * 60 * 5; i++) {
        charging.step(1 / 60);
        busy.add(charging.activity);
      }
      expect(busy.contains(PipActivity.bugHunt), isFalse);
      expect(busy.contains(PipActivity.flower), isFalse);
    });
  });

  group('pictures', () {
    test(
        "every screen picture is drawn on his screen, his size, unlike "
        'his face', () {
      final idle = PipSprites.frames[PipFrame.idle]!;
      for (final screen in PipScreen.values) {
        final frame = PipSprites.screenFrame(screen, 0.1);
        expect(frame.length, idle.length, reason: screen.name);
        expect(frame.map((r) => r.length).toSet(), {PipBrain.width});
        expect(frame, isNot(idle), reason: screen.name);
        for (final row in frame) {
          for (final c in row.split('')) {
            if (c != '.') {
              expect(PipSprites.colours.containsKey(c), isTrue,
                  reason: '${screen.name}: $c');
            }
          }
        }
      }
      expect(PipScreen.values.where((s) => s.notification), hasLength(3));
    });

    test('an angry face of his own', () {
      final angry = PipSprites.frameOf(PipFrame.idle, PipFace.angry);
      expect(angry, isNot(PipSprites.frames[PipFrame.idle]));
    });

    test("the field's things use known colours", () {
      for (final art in [
        PipSprites.bugUp,
        PipSprites.bugDown,
        PipSprites.sword,
        PipSprites.flower,
        PipSprites.butterflyUp,
        PipSprites.butterflyDown,
        ...PipSprites.ballFrames,
        ...PipSprites.crossWords,
      ]) {
        for (final row in art) {
          for (final c in row.split('')) {
            if (c != '.') {
              expect(PipSprites.fieldColours.containsKey(c), isTrue,
                  reason: '$art: $c');
            }
          }
        }
      }
    });
  });

  test('skies (Round 52): more hues than top and bottom, which they keep', () {
    for (final part in DayPart.values) {
      final stops = PipBackground.field.stopsAt(part);
      final (top, bottom) = PipBackground.field.skyAt(part);
      expect(stops.length, greaterThanOrEqualTo(5), reason: part.name);
      expect(stops.first, top);
      expect(stops.last, bottom);
      expect(stops.toSet(), hasLength(stops.length), reason: 'all different');
    }
    expect(
        PipColours.duskStops.length, greaterThan(PipColours.nightStops.length),
        reason: 'dusk the most colourful');
  });
}
