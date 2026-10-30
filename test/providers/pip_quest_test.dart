import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_quest.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/pip_life_provider.dart';

/// Pip's quests (Round 125): starting one, its work minutes from the
/// clock (powered down, away), finishing.
void main() {
  DateTime at(int day, int hour, [int minute = 0, int month = 11]) =>
      DateTime(2026, month, day, hour, minute);

  PipLifeNotifier hatched({DateBook dates = DateBook.empty}) {
    final pip = PipLifeNotifier(AppStorage.inMemory(), dates: () => dates);
    pip.replace(PipLife(
      born: at(1, 9),
      energy: PipEnergy.full,
      energyAt: at(2, 9),
      nextBatteryAt: at(30, 9),
      batteries: 3,
    ));
    return pip;
  }

  /// Kept full: batteries at [t] (so power downs don't come into it).
  void fill(PipLifeNotifier pip, DateTime t) => pip
      .replace(pip.state.copyWith(energy: PipEnergy.full, energyAt: () => t));

  test('offered: the house, to an egg nothing', () {
    expect(PipLifeNotifier(AppStorage.inMemory()).questOffered, isNull);
    expect(hatched().questOffered, Quests.house);
  });

  test('started only in quest hours, once; it can\'t be started again', () {
    final pip = hatched();
    expect(pip.startQuest(at(2, 9, 59)), isFalse);
    expect(pip.startQuest(at(2, 12)), isFalse);
    expect(pip.state.questId, isNull);
    expect(pip.startQuest(at(2, 10, 20)), isTrue);
    expect(pip.state.questId, 'house');
    expect(pip.state.questFrom, at(2, 10, 20));
    expect(pip.questOffered, isNull, reason: 'one at a time');
    expect(pip.startQuest(at(2, 10, 30)), isFalse);
  });

  test('work minutes: only quest hours count, days not looked in on too', () {
    final pip = hatched();
    pip.startQuest(at(2, 10, 20));
    expect(pip.questAt(at(2, 10, 50))!.script.startOf(0), 0);
    fill(pip, at(2, 10, 50));
    pip.settleQuest(at(2, 15));
    expect(pip.state.questMinutes, 70, reason: '10:20–11:30');
    // The evening: 19:00 on.
    fill(pip, at(2, 19));
    pip.settleQuest(at(2, 19, 45));
    expect(pip.state.questMinutes, 115);
    // Read without settling: the same.
    fill(pip, at(2, 20));
    expect(
        pip.questAt(at(2, 22))!.into +
            pip.quest!.startOf(pip.questAt(at(2, 22))!.step),
        160);
  });

  test(
      'powered down: the minutes he\'s off don\'t count; a battery and he '
      'carries on', () {
    final pip = hatched();
    // Nearly empty at 10:00: a quarter of a segment is an hour.
    pip.replace(pip.state.copyWith(energy: 0.25, energyAt: () => at(2, 10)));
    pip.startQuest(at(2, 10));
    pip.settleQuest(at(2, 11, 30));
    expect(pip.state.questMinutes, 60, reason: 'off at 11:00');
    // Given a battery at 19:10: on again.
    pip.giveBattery(at(2, 19, 10));
    pip.settleQuest(at(2, 20, 30));
    expect(pip.state.questMinutes, 140);
  });

  test('away on a ski trip: no work', () {
    const ski = DateEntry(
      id: 'ski',
      title: 'Ski',
      type: DateType.holiday,
      day: 5,
      month: 11,
      year: 2026,
      yearly: false,
      days: 3,
      kind: DateKind.skiing,
    );
    final pip = hatched(dates: const DateBook([ski]));
    pip.startQuest(at(2, 10));
    for (var d = 2; d <= 9; d++) {
      fill(pip, at(d, 9));
      pip.settleQuest(at(d, 21));
    }
    // Eight days less the three away (5th–7th): five days.
    expect(pip.state.questMinutes, 5 * PipQuest.minutesPerDay);
  });

  test('the clock going back changes nothing', () {
    final pip = hatched();
    pip.startQuest(at(2, 10));
    fill(pip, at(2, 10));
    pip.settleQuest(at(2, 11));
    expect(pip.state.questMinutes, 60);
    pip.settleQuest(at(2, 10, 30));
    expect(pip.state.questMinutes, 60);
    expect(pip.state.questCountedTo, at(2, 11));
  });

  test(
      'finished: kept with when its last minute was worked; nothing more '
      'offered (for now)', () {
    final pip = hatched();
    pip.startQuest(at(2, 10));
    // Nearly done: a minute short of the end at 10:30.
    pip.replace(pip.state.copyWith(
        questMinutes: Quests.house.totalMinutes - 31,
        questCountedTo: () => at(2, 10, 30)));
    fill(pip, at(2, 10, 30));
    pip.settleQuest(at(2, 12));
    expect(pip.state.questId, isNull);
    expect(pip.state.questMinutes, 0);
    expect(pip.state.questsDone.single.id, 'house');
    expect(pip.state.questsDone.single.at, at(2, 11, 1));
    expect(pip.questOffered, isNull);
    expect(pip.questAt(at(2, 12)), isNull);
  });

  test('working at a moment: quest hours, on, a quest under way', () {
    final pip = hatched();
    expect(pip.questWorkingAt(at(2, 10, 10)), isFalse, reason: 'none yet');
    pip.startQuest(at(2, 10));
    fill(pip, at(2, 10));
    expect(pip.questWorkingAt(at(2, 10, 10)), isTrue);
    expect(pip.questWorkingAt(at(2, 12)), isFalse);
    pip.replace(pip.state.copyWith(energy: 0, energyAt: () => at(2, 19)));
    expect(pip.questWorkingAt(at(2, 19, 10)), isFalse, reason: 'off');
  });

  test('saved and read back with his quest', () {
    final pip = hatched();
    pip.startQuest(at(2, 10));
    fill(pip, at(2, 10));
    pip.settleQuest(at(2, 11));
    final again = PipLife.fromJson(pip.state.toJson());
    expect(again, pip.state);
  });
}
