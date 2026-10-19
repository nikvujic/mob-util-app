import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_adventure.dart';

/// Pip's adventures (Round 63): the levels, titles and times.
void main() {
  int levelAfterDays(double days) =>
      PipAdventure.levelFor((days * PipAdventure.xpPerDay).round());

  test('a full day out is 3600 XP (Round 73: ten a minute)', () {
    expect(PipAdventure.xpPerDay, 3600);
    expect(PipAdventure.minutesPerDay, 360);
  });

  test('levels hit the yearly targets: 90, 160, 230, 280, then 50 a year', () {
    expect(levelAfterDays(0), 1);
    expect(levelAfterDays(365), 90);
    expect(levelAfterDays(730), 160);
    expect(levelAfterDays(1095), 230);
    expect(levelAfterDays(1460), 280);
    expect(levelAfterDays(1825), 330);
  });

  test('early levels come fast: level 2 within two days, 13 in a month', () {
    expect(levelAfterDays(1), 1);
    expect(levelAfterDays(2), 2);
    expect(levelAfterDays(30), 13);
    expect(levelAfterDays(180), 51);
  });

  test('one level at a time, each costing at least as much as the one before',
      () {
    var cost = 0;
    for (var level = 1; level < 400; level++) {
      final next = PipAdventure.xpFor(level + 1) - PipAdventure.xpFor(level);
      expect(next, greaterThanOrEqualTo(cost - 1), reason: 'level $level');
      expect(next, greaterThan(0));
      cost = next;
      expect(PipAdventure.levelFor(PipAdventure.xpFor(level)), level);
      expect(PipAdventure.levelFor(PipAdventure.xpFor(level + 1) - 1), level);
    }
  });

  test('no cap', () {
    expect(levelAfterDays(365 * 20), greaterThan(1000));
  });

  test('the XP bar: how far into his level', () {
    final from = PipAdventure.xpFor(10);
    final to = PipAdventure.xpFor(11);
    expect(PipAdventure.progressFor(from), 0);
    expect(PipAdventure.progressFor((from + to) ~/ 2), closeTo(0.5, 0.01));
  });

  test('a title every 10 levels, up to 80', () {
    expect(PipAdventure.titleFor(1), 'Rookie');
    expect(PipAdventure.titleFor(9), 'Rookie');
    expect(PipAdventure.titleFor(10), 'Bug Squasher');
    expect(PipAdventure.titleFor(40), 'Knight');
    expect(PipAdventure.titleFor(79), 'Hero');
    expect(PipAdventure.titleFor(80), 'Legend');
    expect(PipAdventure.titleFor(500), 'Legend');
  });

  test('registering from 13:00 to 17:00', () {
    expect(PipAdventure.canRegisterAt(DateTime(2026, 10, 18, 12, 59)), isFalse);
    expect(PipAdventure.canRegisterAt(DateTime(2026, 10, 18, 13)), isTrue);
    expect(PipAdventure.canRegisterAt(DateTime(2026, 10, 18, 16, 59)), isTrue);
    expect(PipAdventure.canRegisterAt(DateTime(2026, 10, 18, 17)), isFalse);
  });

  test(
      'a break between 14:00 and 16:00; not while his setting off was '
      'seen (Round 66)', () {
    final noon = DateTime(2026, 10, 18, 12);
    expect(
        PipAdventure.breakDueAt(DateTime(2026, 10, 18, 13, 59), noon), isFalse);
    expect(PipAdventure.breakDueAt(DateTime(2026, 10, 18, 14), noon), isTrue);
    expect(PipAdventure.breakDueAt(DateTime(2026, 10, 18, 16), noon), isFalse);
    expect(
        PipAdventure.breakDueAt(DateTime(2026, 10, 18, 14, 30), noon,
            startSeen: true),
        isFalse);
  });
}
