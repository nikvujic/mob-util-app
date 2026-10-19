import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Round 77: waking him by three taps: at night once, for 15 minutes,
/// drowsy, one eye open first; from 07:00 for the day.
void main() {
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 10, day, hour, minute);

  group('the rules', () {
    test('the night a moment is in: its evening', () {
      expect(nightKey(at(18, 23, 30)), '2026-10-18');
      expect(nightKey(at(19, 2)), '2026-10-18');
      expect(nightKey(at(19, 7, 59)), '2026-10-18');
      expect(nightKey(at(19, 8)), '2026-10-19');
      expect(nightKey(DateTime(2026, 11, 1, 3)), '2026-10-31');
    });

    test('woken at night: up for 15 minutes, drowsy', () {
      final woken = at(19, 2);
      expect(PipEnergy.wokenAt(woken, at(19, 1, 59)), isFalse);
      expect(PipEnergy.wokenAt(woken, woken), isTrue);
      expect(PipEnergy.wokenAt(woken, at(19, 2, 14)), isTrue);
      expect(PipEnergy.wokenAt(woken, at(19, 2, 15)), isFalse);
      expect(PipEnergy.drowsyAt(woken, at(19, 2, 10)), isTrue);
      expect(PipEnergy.drowsyAt(woken, at(19, 2, 15)), isFalse);
      expect(PipEnergy.wokenAt(null, at(19, 2)), isFalse);
      expect(PipEnergy.drowsyAt(null, at(19, 2)), isFalse);
    });

    test('woken from 07:00: up till 08:00 (then up anyway), not drowsy', () {
      final woken = at(19, 7, 10);
      expect(PipEnergy.wokenAt(woken, at(19, 7, 40)), isTrue);
      expect(PipEnergy.wokenAt(woken, at(19, 7, 59)), isTrue);
      expect(PipEnergy.wokenAt(woken, at(19, 8)), isFalse);
      expect(PipEnergy.drowsyAt(woken, at(19, 7, 15)), isFalse);
      // Not tomorrow morning too.
      expect(PipEnergy.wokenAt(woken, at(20, 7, 30)), isFalse);
    });

    test('once a night; early, whatever the night had', () {
      expect(PipEnergy.mayWakeAt(null, at(18, 23, 30)), isTrue);
      expect(PipEnergy.mayWakeAt(null, at(19, 3)), isTrue);
      expect(PipEnergy.mayWakeAt(null, at(19, 12)), isFalse,
          reason: 'not his sleeping hours');
      expect(PipEnergy.mayWakeAt(null, at(19, 8)), isFalse);
      final night = at(18, 23, 30);
      expect(PipEnergy.mayWakeAt(night, at(18, 23, 40)), isFalse,
          reason: 'up already');
      expect(PipEnergy.mayWakeAt(night, at(19, 3)), isFalse,
          reason: 'this night he was');
      expect(PipEnergy.mayWakeAt(night, at(19, 7, 5)), isTrue,
          reason: 'early: for the day');
      expect(PipEnergy.mayWakeAt(night, at(19, 23, 30)), isTrue,
          reason: 'the next night');
      expect(PipEnergy.mayWakeAt(at(19, 3), at(19, 23, 30)), isTrue);
      expect(PipEnergy.mayWakeAt(at(19, 7, 5), at(19, 7, 30)), isFalse,
          reason: 'up already');
    });

    test('what to show: up while woken, asleep again after', () {
      PipShow show(DateTime now, DateTime? woken) => pipShowAt(now,
          level: 2, offSeen: false, sleepSeen: '2026-10-18', wokenAt: woken);
      expect(show(at(19, 2, 5), null), PipShow.asleep);
      expect(show(at(19, 2, 5), at(19, 2)), PipShow.awake);
      expect(show(at(19, 2, 15), at(19, 2)), PipShow.asleep);
      expect(show(at(18, 23, 20), at(18, 23, 10)), PipShow.awake);
      expect(show(at(19, 7, 50), at(19, 7, 5)), PipShow.awake);
      // Running out still wins.
      expect(
          pipShowAt(at(19, 2, 5), level: 0, offSeen: false, wokenAt: at(19, 2)),
          PipShow.powerOff);
    });
  });

  group('his life', () {
    PipLifeNotifier asleepPip() => PipLifeNotifier(AppStorage.inMemory())
      ..replace(PipLife(
        born: at(10, 9),
        energy: 2,
        energyAt: at(18, 22),
        nextBatteryAt: at(30, 9),
        batteries: 2,
        sleepSeen: '2026-10-18',
      ));

    test('woken at night once; a battery then; asleep again after 15 min', () {
      final pip = asleepPip();
      final now = at(19, 2);
      expect(pip.refusalAt(now), PipRefusal.asleep);
      expect(pip.mayWakeAt(now), isTrue);
      expect(pip.wake(now), isTrue);
      expect(pip.state.wokenAt, now);
      expect(pip.showAt(now), PipShow.awake);
      expect(pip.drowsyAt(now), isTrue);
      expect(pip.refusalAt(now), isNull, reason: 'he can be charged');
      expect(pip.giveBattery(at(19, 2, 5)), isTrue);
      expect(pip.showAt(at(19, 2, 15)), PipShow.asleep);
      expect(pip.drowsyAt(at(19, 2, 15)), isFalse);
      expect(pip.wake(at(19, 3)), isFalse, reason: 'once a night');
      expect(pip.mayWakeAt(at(19, 3)), isFalse);
      expect(pip.wake(at(19, 7, 10)), isTrue, reason: 'early, for the day');
      expect(pip.showAt(at(19, 7, 50)), PipShow.awake);
      expect(pip.drowsyAt(at(19, 7, 50)), isFalse);
    });

    test('not when he is up, off, or an egg', () {
      final pip = asleepPip();
      expect(pip.wake(at(19, 12)), isFalse);
      expect(pip.wake(at(18, 23, 10)), isTrue);
      expect(pip.wake(at(18, 23, 12)), isFalse, reason: 'up already');
      final off = asleepPip()
        ..replace(
            asleepPip().state.copyWith(energy: 0, energyAt: () => at(18, 22)));
      expect(off.wake(at(19, 2)), isFalse);
      expect(PipLifeNotifier(AppStorage.inMemory()).wake(at(19, 2)), isFalse);
    });

    test('kept, and read back (pip.json and backups)', () {
      final pip = PipLife(born: at(10, 9), wokenAt: at(19, 2, 3));
      final back = PipLife.fromJson(pip.toJson());
      expect(back.wokenAt, at(19, 2, 3));
      expect(back, pip);
      expect(
          PipLife.fromJson(PipLife(born: at(10, 9)).toJson()).wokenAt, isNull);
      expect(pip.copyWith(wokenAt: () => null).wokenAt, isNull);
      expect(pip.copyWith().wokenAt, at(19, 2, 3));
      expect(pip == PipLife(born: at(10, 9)), isFalse);
    });
  });

  group('in his room', () {
    PipBrain asleep() {
      final b = PipBrain(roomWidth: 200, random: math.Random(1));
      b.step(PipBrain.landEnd);
      expect(b.show(PipShow.asleep), isTrue);
      b.step(PipBrain.asleepEnd + 0.01);
      expect(b.activity, PipActivity.asleep);
      return b;
    }

    test(
        'woken: still lying there, one eye opens a moment, shuts, then he '
        'wakes as ever; drowsy after, as at one segment', () {
      final b = asleep();
      expect(b.play(PipAnimation.nightWake), isTrue);
      b.drowsy = true;
      expect(b.activity, PipActivity.stirring);
      final faces = <PipFace>[];
      for (var t = 0.0; t < PipBrain.stirEnd - 0.01; t += 0.05) {
        b.step(0.05);
        if (faces.isEmpty || faces.last != b.face) faces.add(b.face);
        expect(b.frame, PipFrame.tuck);
        expect(b.lift, -2, reason: 'down on the ground');
        expect(b.zs, isEmpty);
      }
      expect(faces, [PipFace.asleep, PipFace.peek, PipFace.asleep]);
      b.step(0.05);
      expect(b.activity, PipActivity.wakingUp);
      b.step(PipBrain.wakeHopEnd + 0.01);
      expect(b.activity, PipActivity.standing);
      expect(b.face, PipFace.veryTired);
      expect(b.pace, closeTo(PipBrain.speed * 0.45, 1e-9));
      b.drowsy = false;
      expect(b.face, PipFace.normal);
      expect(b.pace, PipBrain.speed);
    });

    test('Pip Home\'s list: he falls asleep, then is woken so', () {
      final b = PipBrain(roomWidth: 200, random: math.Random(1));
      b.step(PipBrain.landEnd);
      expect(b.play(PipAnimation.nightWake, demo: true), isTrue);
      final seen = <PipActivity>[];
      for (var i = 0; i < 60 * 12; i++) {
        b.step(1 / 60);
        if (seen.isEmpty || seen.last != b.activity) seen.add(b.activity);
      }
      expect(seen.take(5), [
        PipActivity.fallingAsleep,
        PipActivity.asleep,
        PipActivity.stirring,
        PipActivity.wakingUp,
        PipActivity.standing,
      ]);
      // Then a plain demo sleep wakes plainly again.
      b.play(PipAnimation.fallAsleep, demo: true);
      final again = <PipActivity>[];
      for (var i = 0; i < 60 * 8; i++) {
        b.step(1 / 60);
        if (again.isEmpty || again.last != b.activity) again.add(b.activity);
      }
      expect(again, isNot(contains(PipActivity.stirring)));
    });

    test('his face: one eye open, the other shut, the screen dimmed', () {
      final peek = PipSprites.frameOf(PipFrame.tuck, PipFace.peek);
      final shut = PipSprites.frameOf(PipFrame.tuck, PipFace.asleep);
      expect(peek, isNot(shut));
      int dark(List<String> rows) =>
          rows.join().split('').where((c) => c == 'K').length;
      expect(dark(peek), dark(shut) + 2, reason: 'one eye open: 2 more');
      expect(peek.join().contains('D'), isTrue, reason: 'dimmed');
    });
  });
}
