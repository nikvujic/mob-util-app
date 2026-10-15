import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Round 57: his hats (a birthday's party hat, those tried on), a slower
/// wake with a yawn, and every picture on his screen reading right.
void main() {
  PipBrain up({int seed = 3}) => PipBrain(
        roomWidth: 140,
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

  group('hats', () {
    test('a birthday: the party hat; none otherwise', () {
      final p = up();
      expect(p.hat, isNull);
      p.birthday = true;
      expect(p.hat, PipHat.party);
    });

    test('tried on: that one (or none), over the party hat; then back', () {
      final p = up()..birthday = true;
      p.tryOn(PipHat.crown);
      expect(p.hat, PipHat.crown);
      p.tryOn(null);
      expect(p.hat, isNull, reason: 'None, even on a birthday');
      p.stopTryingOn();
      expect(p.hat, PipHat.party);
    });

    test('none as an egg, or hatching', () {
      final egg = PipBrain(roomWidth: 140, hatched: false)..birthday = true;
      expect(egg.hat, isNull);
    });

    test('asleep: beside him; awake again: on', () {
      final p = asleep()..birthday = true;
      expect(p.hatBeside, isTrue);
      p.show(PipShow.wakeUp);
      run(p, PipBrain.yawnAt + 0.2);
      expect(p.hatBeside, isFalse, reason: 'up, yawning: back on');
      run(p, PipBrain.wakeHopEnd);
      expect(p.hatBeside, isFalse);
      expect(p.hat, PipHat.party);
    });

    test('each hat: on his head right of the antenna, above his casing', () {
      final frame = PipSprites.frameOf(PipFrame.idle, PipFace.normal);
      final antenna = frame.first.indexOf('A');
      for (final MapEntry(key: hat, value: art) in PipSprites.hats.entries) {
        expect(art.map((r) => r.length).reduce(math.max), lessThanOrEqualTo(8),
            reason: hat.name);
        expect(PipSprites.hatLeft, greaterThan(antenna));
        // Its bottom row on the row above his casing's top.
        expect(frame[PipSprites.hatBottom + 1].contains('L'), isTrue);
        for (final row in art) {
          for (final c in row.split('')) {
            if (c != '.') {
              expect(PipSprites.hatColours.containsKey(c), isTrue,
                  reason: '${hat.name} $c');
            }
          }
        }
      }
      expect(PipSprites.hats.keys.toSet(), PipHat.values.toSet());
    });
  });

  test('his birthday: the day he hatched each year after, not that day', () {
    final life = PipLife(born: DateTime(2026, 10, 13, 20, 30));
    expect(life.birthdayOn(DateTime(2026, 10, 13)), isFalse);
    expect(life.birthdayOn(DateTime(2027, 10, 13)), isTrue);
    expect(life.birthdayOn(DateTime(2027, 10, 14)), isFalse);
    expect(PipLife.egg.birthdayOn(DateTime(2027, 10, 13)), isFalse);
    final leap = PipLife(born: DateTime(2028, 2, 29, 12));
    expect(leap.birthdayOn(DateTime(2029, 2, 28)), isTrue);
    expect(leap.birthdayOn(DateTime(2032, 2, 29)), isTrue);
  });

  test(
      'waking: eyes shut a while, legs out, a yawn as he stretches up, a '
      'blink, then the hop; longer than before', () {
    final p = asleep()..show(PipShow.wakeUp);
    run(p, PipBrain.legsOutAt - 0.1);
    expect(p.frame, PipFrame.tuck);
    expect(p.face, PipFace.asleep);
    run(p, PipBrain.yawnAt - PipBrain.legsOutAt);
    expect(p.frame, PipFrame.blink, reason: 'legs out, eyes still shut');
    run(p, 0.6); // into the yawn
    expect(p.face, PipFace.yawn);
    expect(p.stretch.$2, greaterThan(1.05), reason: 'stretching up');
    expect(p.lift, lessThanOrEqualTo(0));
    run(p, PipBrain.yawnEnd - p.zsClock + 0.1);
    expect(p.face, isNot(PipFace.yawn));
    expect(p.frame, PipFrame.blink);
    run(p, PipBrain.wakeHopStart - p.zsClock + 0.2);
    expect(p.lift, greaterThan(0), reason: 'the hop');
    expect(PipBrain.wakeHopEnd, greaterThan(4));
    run(p, 0.6);
    expect(p.activity, isNot(PipActivity.wakingUp));
    // The yawn's face: eyes shut, mouth open wide.
    final yawn = PipSprites.frameOf(PipFrame.idle, PipFace.yawn);
    expect(yawn, isNot(PipSprites.frameOf(PipFrame.idle, PipFace.asleep)));
  });

  test(
      'every picture on his screen reads right facing left: charging ones '
      'too (the bolt), turned before he is mirrored', () {
    List<String> mirrored(List<String> f) =>
        [for (final r in f) r.split('').reversed.join()];
    const top = 4, left = 3;
    void readsRight(PipBrain p, List<String> picture) {
      p.facingRight = false;
      final drawn = mirrored(pipFrameOf(p));
      for (var y = top; y < top + PipSprites.screenRows; y++) {
        expect(drawn[y].substring(left, left + PipSprites.screenWidth),
            picture[y].substring(left, left + PipSprites.screenWidth));
      }
    }

    // Plugged in, charging: its screens (the bolt among them).
    final p = up()..segments = 2;
    p.setPlugged(true, animate: false);
    expect(p.activity, PipActivity.charging);
    for (var i = 0;
        i < 60 * 60 * 20 && p.chargeScreen?.$1 != ChargeScreen.bolt;
        i++) {
      p.step(1 / 60);
    }
    final (screen, t) = p.chargeScreen!;
    expect(screen, ChargeScreen.bolt);
    readsRight(p, PipSprites.chargingFrame(screen, t, lamp: p.stationLamp));
    // Something shown (a notification).
    final q = up()..debugShow(PipScreen.envelope);
    readsRight(q, PipSprites.screenFrame(PipScreen.envelope, q.screenShow!.$2));
    // His own face is mirrored as ever (he looks where he goes).
    final r = up()..facingRight = false;
    expect(pipFrameOf(r), PipSprites.frameOf(r.frame, r.face));
  });
}
