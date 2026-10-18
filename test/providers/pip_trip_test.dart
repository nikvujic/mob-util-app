import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_adventure.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/providers/pip_trip.dart';

/// Pip's ski trips (Round 67): ski days, the bus there and back, snow.
void main() {
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2027, 1, day, hour, minute);

  // 20–24 January, 6 hours each way: the bus 06:00–12:00 on the 20th,
  // and 11:00–17:00 on the 25th.
  const ski = DateEntry(
    id: 'ski',
    title: 'Jahorina',
    type: DateType.holiday,
    day: 20,
    month: 1,
    year: 2027,
    yearly: false,
    days: 5,
    kind: DateKind.skiing,
    travelHours: 6,
  );
  const book = DateBook([ski]);

  test('on the bus there: which way and how far; snowy from 80%', () {
    expect(PipTrip.at(book, at(20, 5, 59)), noTrip);
    final mid = PipTrip.at(book, at(20, 9));
    expect(mid.leg, TripLeg.there);
    expect(mid.progress, 0.5);
    expect(mid.snowy, isFalse);
    expect(PipTrip.at(book, at(20, 10, 48)).snowy, isTrue, reason: '80%');
    expect(PipTrip.at(book, at(20, 12)).leg, isNull, reason: 'arrived');
  });

  test('at the resort: snowy; on the bus back, snowy till 20%', () {
    final there = PipTrip.at(book, at(22, 3));
    expect((there.leg, there.snowy), (null, true));
    final back = PipTrip.at(book, at(25, 12));
    expect(back.leg, TripLeg.back);
    expect(back.snowy, isTrue, reason: 'a sixth of the way');
    expect(PipTrip.at(book, at(25, 12, 13)).snowy, isFalse, reason: '20%');
    expect(PipTrip.at(book, at(25, 17)), noTrip);
  });

  test('ski days: all of 12:00–18:00 at the resort; not a bus day', () {
    expect(PipTrip.skiDay(book, at(20, 13)), isTrue,
        reason: 'arrived at 12:00 sharp: all of it at the resort');
    expect(PipTrip.busDay(book, at(20, 13)), isFalse,
        reason: 'it ended at 12:00 sharp');
    expect(PipTrip.skiDay(book, at(21, 13)), isTrue);
    expect(PipTrip.skiDay(book, at(24, 13)), isTrue);
    expect(PipTrip.busDay(book, at(25, 9)), isTrue, reason: 'back 11–17');
    expect(PipTrip.skiDay(book, at(25, 9)), isFalse);
    expect(PipTrip.at(book, at(21, 15)).skiing, isTrue);
  });

  test('a bus in the afternoon: a bus day, no skiing', () {
    final late = book.dates.single.copyWith(leaveAt: 9 * 60);
    final b = DateBook([late]);
    expect(PipTrip.busDay(b, at(20, 8)), isTrue, reason: '09:00–15:00');
    expect(PipTrip.skiDay(b, at(20, 8)), isFalse);
  });

  test('without travel: its days are snowy ski days, no bus', () {
    final b = DateBook([ski.copyWith(travelHours: 0)]);
    expect(PipTrip.at(b, at(20, 1)).snowy, isTrue);
    expect(PipTrip.at(b, at(24, 23)).snowy, isTrue);
    expect(PipTrip.at(b, at(25, 1)), noTrip);
    expect(PipTrip.skiDay(b, at(20, 13)), isTrue);
    expect(PipTrip.ridesNear(b, at(20, 1)), isEmpty);
  });

  test('another kind of holiday: nothing', () {
    final b = DateBook([ski.copyWith(kind: () => DateKind.beach)]);
    expect(PipTrip.at(b, at(21, 15)), noTrip);
  });

  group('his life on the trip', () {
    PipLifeNotifier pip({double energy = 2, DateTime? energyAt}) {
      final p = PipLifeNotifier(AppStorage.inMemory(), dates: () => book);
      p.replace(PipLife(
        born: DateTime(2026, 10, 1),
        energy: energy,
        energyAt: energyAt ?? at(20, 4),
        batteries: 1,
        nextBatteryAt: at(20, 7),
      ));
      return p;
    }

    test('on the bus he uses no energy', () {
      final p = pip();
      final before = p.levelAt(at(20, 6));
      expect(p.levelAt(at(20, 12)), before, reason: 'the whole ride');
      expect(p.levelAt(at(20, 14)),
          closeTo(before - 2 * PipEnergy.awakePerHour, 1e-9));
    });

    test('no battery on the bus; they pile up all the same', () {
      final p = pip();
      expect(p.refusalAt(at(20, 9)), PipRefusal.travelling);
      p.collect(at(20, 9));
      expect(p.state.batteries, 2);
    });

    test('a bus day: an adventurer gains the day\'s XP all the same', () {
      final p = pip(energy: 0, energyAt: at(25, 8));
      p.replace(p.state.copyWith(
        registeredAt: () => at(10, 14),
        outDay: () => '2027-01-24',
      ));
      p.collect(at(26, 9));
      expect(p.state.xp, PipAdventure.xpPerDay);
    });
  });
}
