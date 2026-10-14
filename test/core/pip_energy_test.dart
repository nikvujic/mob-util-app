import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_energy.dart';

/// Pip's energy and sleep (Round 37), worked out from the clock.
void main() {
  DateTime at(int day, int h, [int m = 0]) => DateTime(2026, 10, day, h, m);

  group('asleep 23:00 to 8:00', () {
    test('by the hour', () {
      expect(PipEnergy.asleepAt(at(14, 22, 59)), isFalse);
      expect(PipEnergy.asleepAt(at(14, 23)), isTrue);
      expect(PipEnergy.asleepAt(at(15, 3)), isTrue);
      expect(PipEnergy.asleepAt(at(15, 7, 59)), isTrue);
      expect(PipEnergy.asleepAt(at(15, 8)), isFalse);
    });
  });

  group('energy used', () {
    test('awake: a segment every 8 hours (Round 45)', () {
      expect(PipEnergy.usedBetween(at(14, 9), at(14, 17)), closeTo(1, 1e-9));
    });

    test('asleep: much slower, a segment every 36 hours', () {
      expect(
          PipEnergy.usedBetween(at(14, 23), at(15, 8)), closeTo(9 / 36, 1e-9));
    });

    test('across the night: each part at its own rate', () {
      // 20:00 → 9:00: 3 h awake, 9 h asleep, 1 h awake.
      expect(PipEnergy.usedBetween(at(14, 20), at(15, 9)),
          closeTo(4 / 8 + 9 / 36, 1e-9));
    });

    test('a day: about two segments (Round 45)', () {
      final day = PipEnergy.usedBetween(at(14, 9), at(15, 9));
      expect(day, closeTo(15 / 8 + 9 / 36, 1e-9));
      expect(day, inInclusiveRange(2, 2.2));
    });

    test('the clock gone back: nothing used', () {
      expect(PipEnergy.usedBetween(at(15, 9), at(14, 9)), 0);
      expect(PipEnergy.levelAt(2, at(15, 9), at(14, 9)), 2);
    });

    test('never below empty', () {
      expect(PipEnergy.levelAt(1, at(14, 9), at(20, 9)), 0);
    });

    test('when it runs out', () {
      expect(PipEnergy.emptyAt(1, at(14, 9)), at(14, 17));
      // 2 at 20:00: 0.375 by 23:00, 0.25 overnight, 1.375 more from 8:00.
      expect(PipEnergy.emptyAt(2, at(14, 20)), at(15, 19));
      expect(PipEnergy.emptyAt(0, at(14, 9)), isNull);
      final empty = PipEnergy.emptyAt(3, at(14, 9))!;
      expect(PipEnergy.levelAt(3, at(14, 9), empty), closeTo(0, 0.01));
    });
  });

  test('segments: 3 above 2, 2 above 1, 1 above 0, 0 empty', () {
    expect(PipEnergy.segments(3), 3);
    expect(PipEnergy.segments(2.01), 3);
    expect(PipEnergy.segments(2), 2);
    expect(PipEnergy.segments(1.5), 2);
    expect(PipEnergy.segments(0.01), 1);
    expect(PipEnergy.segments(0), 0);
  });

  test(
      'batteries on the clock (Round 45): every 5 hours, piling up while '
      'away, at most 3', () {
    final next = at(14, 12);
    expect(PipEnergy.nextBattery(at(14, 7)), next);
    expect(PipEnergy.batteriesAt(0, next, at(14, 11)), (0, next),
        reason: 'not yet');
    expect(PipEnergy.batteriesAt(0, next, at(14, 12)), (1, at(14, 17)));
    // Eleven hours past: three came (12:00, 17:00, 22:00).
    expect(PipEnergy.batteriesAt(0, next, at(14, 23)), (3, at(15, 3)));
    // Held two already: only one more fits; the clock keeps going.
    expect(PipEnergy.batteriesAt(2, next, at(14, 23)), (3, at(15, 3)));
  });

  group('what to show', () {
    PipShow show(DateTime now,
            {double level = 2,
            bool offSeen = false,
            String? sleepSeen,
            String? wakeSeen}) =>
        pipShowAt(now,
            level: level,
            offSeen: offSeen,
            sleepSeen: sleepSeen,
            wakeSeen: wakeSeen);

    test('by day: awake', () {
      expect(show(at(14, 12)), PipShow.awake);
      expect(show(at(14, 22, 59)), PipShow.awake);
    });

    test('23:00 to 0:00: falls asleep once that night, then asleep', () {
      expect(show(at(14, 23, 10)), PipShow.fallAsleep);
      expect(show(at(14, 23, 40), sleepSeen: '2026-10-14'), PipShow.asleep);
      expect(show(at(15, 23, 10), sleepSeen: '2026-10-14'), PipShow.fallAsleep,
          reason: 'a new night');
    });

    test('after 0:00 he is simply asleep', () {
      expect(show(at(15, 0, 5)), PipShow.asleep);
      expect(show(at(15, 7, 59)), PipShow.asleep);
    });

    test('8:00 to 9:00: wakes up once that morning, then awake', () {
      expect(show(at(15, 8, 20)), PipShow.wakeUp);
      expect(show(at(15, 8, 40), wakeSeen: '2026-10-15'), PipShow.awake);
      expect(show(at(15, 9, 0)), PipShow.awake, reason: 'after 9: just awake');
    });

    test('ran out: he turns off, at night too; once seen, he is off', () {
      expect(show(at(14, 12), level: 0), PipShow.powerOff);
      expect(show(at(15, 2), level: 0), PipShow.powerOff,
          reason: 'power off wins at night');
      expect(show(at(14, 23, 10), level: 0), PipShow.powerOff);
      expect(show(at(14, 12), level: 0, offSeen: true), PipShow.off);
      expect(show(at(15, 2), level: 0, offSeen: true), PipShow.off);
    });
  });
}
