import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_hats.dart';

/// Round 61: Pip's hats by the day: days of the year's, random ones.
void main() {
  test('days of the year: Santa at New Year, a witch, bunny ears, a heart', () {
    expect(seasonalHatOn(DateTime(2026, 12, 24)), isNull);
    expect(seasonalHatOn(DateTime(2026, 12, 25)), PipHat.santa);
    expect(seasonalHatOn(DateTime(2026, 12, 31)), PipHat.santa);
    expect(seasonalHatOn(DateTime(2027, 1, 2)), PipHat.santa);
    expect(seasonalHatOn(DateTime(2027, 1, 3)), isNull);
    expect(seasonalHatOn(DateTime(2026, 10, 31)), PipHat.witch);
    expect(seasonalHatOn(DateTime(2026, 10, 30)), isNull);
    expect(seasonalHatOn(DateTime(2027, 2, 14)), PipHat.heart);
    // Orthodox Easter: 20 Apr 2025, 12 Apr 2026, 2 May 2027.
    expect(orthodoxEaster(2025), DateTime(2025, 4, 20));
    expect(orthodoxEaster(2026), DateTime(2026, 4, 12));
    expect(orthodoxEaster(2027), DateTime(2027, 5, 2));
    expect(seasonalHatOn(DateTime(2026, 4, 12)), PipHat.bunny);
    expect(seasonalHatOn(DateTime(2026, 4, 13)), PipHat.bunny,
        reason: 'Easter Monday');
    expect(seasonalHatOn(DateTime(2026, 4, 14)), isNull);
  });

  test('a day of the year\'s hat wins over a random one', () {
    for (var seed = 0; seed < 20; seed++) {
      expect(pipHatOn(DateTime(2026, 12, 28), seed: seed), PipHat.santa);
    }
  });

  test(
      'random hat days: about 6-7 a month, everyday hats only, all of them; '
      'the same all day; each Pip his own', () {
    final start = DateTime(2027, 3, 1);
    var hatDays = 0;
    final seen = <PipHat>{};
    const days = 365 * 10;
    for (var i = 0; i < days; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      if (seasonalHatOn(day) != null) continue;
      final hat = pipHatOn(day, seed: 7);
      if (hat == null) continue;
      hatDays++;
      seen.add(hat);
      expect(hat.everyday, isTrue);
      expect(hat, isNot(PipHat.party));
      expect(pipHatOn(DateTime(day.year, day.month, day.day, 23, 59), seed: 7),
          hat,
          reason: 'the same all day');
    }
    final perMonth = hatDays / (days / 30.44);
    expect(perMonth, inInclusiveRange(5.5, 7.5));
    expect(seen, {
      for (final h in PipHat.values)
        if (h.everyday && h != PipHat.party) h,
    });
    // Another Pip: other days.
    var differ = 0;
    for (var i = 0; i < 200; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      if (pipHatOn(day, seed: 7) != pipHatOn(day, seed: 8)) differ++;
    }
    expect(differ, greaterThan(20));
  });

  test("the brain: a tried-on hat, then a birthday's, then today's", () {
    final p = PipBrain(roomWidth: 140, random: math.Random(1))
      ..step(PipBrain.landEnd);
    expect(p.hat, isNull);
    p.dayHat = PipHat.santa;
    expect(p.hat, PipHat.santa);
    p.birthday = true;
    expect(p.hat, PipHat.party, reason: 'a birthday comes first');
    p.tryOn(PipHat.cap);
    expect(p.hat, PipHat.cap);
    p.stopTryingOn();
    expect(p.hat, PipHat.party);
  });
}
