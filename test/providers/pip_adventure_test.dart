import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_adventure.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/pip_life_provider.dart';

/// Pip's adventures (Round 63): registering, his days out, XP, energy.
void main() {
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 10, day, hour, minute);

  PipLifeNotifier hatched({double energy = 3, DateTime? energyAt}) {
    final pip = PipLifeNotifier(AppStorage.inMemory());
    pip.replace(PipLife(
      born: at(10, 9),
      energy: energy,
      energyAt: energyAt ?? at(18, 9),
      nextBatteryAt: at(30, 9),
      batteries: 3,
    ));
    return pip;
  }

  /// Batteries given him in the morning: full at [t].
  void fill(PipLifeNotifier pip, DateTime t) => pip
      .replace(pip.state.copyWith(energy: PipEnergy.full, energyAt: () => t));

  test('registering: only from 13:00 to 17:00, once; he goes out at once', () {
    final pip = hatched(energy: 1);
    expect(pip.register(at(18, 12, 30)), isFalse);
    expect(pip.register(at(18, 17)), isFalse);
    expect(pip.state.adventurer, isFalse);
    expect(pip.register(at(18, 13, 30)), isTrue);
    expect(pip.register(at(18, 14)), isFalse, reason: 'once');
    expect(pip.state.registeredAt, at(18, 13, 30));
    expect(pip.levelAt(at(18, 13, 30)), PipEnergy.full, reason: 'filled');
    expect(pip.outAt(at(18, 14)), isTrue);
    expect(pip.xpAt(at(18, 14)), 30);
    // Looked at again: still out since he registered.
    pip.collect(at(18, 14));
    pip.giveBattery(at(18, 14, 30));
    expect(pip.state.outFrom, at(18, 13, 30));
    expect(pip.xpAt(at(18, 20)), 270, reason: 'till 18:00');
    expect(pip.outAt(at(18, 18)), isFalse);
  });

  test('an egg can\'t register', () {
    final pip = PipLifeNotifier(AppStorage.inMemory());
    expect(pip.register(at(18, 14)), isFalse);
  });

  test('every day after, out at 12:00 by himself; XP banked', () {
    final pip = hatched();
    pip.register(at(18, 16));
    pip.collect(at(19, 11));
    expect(pip.state.xp, 120, reason: '16:00 to 18:00 banked');
    expect(pip.outAt(at(19, 11)), isFalse);
    fill(pip, at(19, 11));
    // Not looked at till 15:00: out since 12:00 all the same.
    pip.collect(at(19, 15));
    expect(pip.state.outFrom, at(19, 12));
    expect(pip.xpAt(at(19, 15)), 120 + 180);
    // Not looked at again till the next morning: the whole day.
    pip.collect(at(20, 9));
    expect(pip.state.xp, 120 + 360);
  });

  test('days not looked at at all: only the first is counted out', () {
    // His energy runs out in the days away; out only while it lasted.
    final pip = hatched();
    pip.register(at(18, 17 - 1));
    pip.collect(at(25, 9));
    expect(pip.state.xp, greaterThanOrEqualTo(120));
  });

  test('powered off at 12:00: no adventure, no XP', () {
    final pip = hatched(energy: 0.2, energyAt: at(19, 9));
    pip.replace(pip.state.copyWith(
      registeredAt: () => at(18, 14),
      outDay: () => '2026-10-18',
    ));
    pip.collect(at(19, 13));
    expect(pip.outAt(at(19, 13)), isFalse);
    expect(pip.xpAt(at(19, 13)), 0);
  });

  test('a battery before 17:00 sends him out; after, he idles', () {
    final pip = hatched(energy: 0, energyAt: at(19, 9));
    pip.replace(pip.state.copyWith(
      registeredAt: () => at(18, 14),
      outDay: () => '2026-10-18',
      offSeen: true,
    ));
    pip.collect(at(19, 14));
    expect(pip.giveBattery(at(19, 14)), isTrue);
    expect(pip.state.outFrom, at(19, 14));
    expect(pip.xpAt(at(19, 15)), 60);

    final late = hatched(energy: 0, energyAt: at(19, 9));
    late.replace(late.state.copyWith(
      registeredAt: () => at(18, 14),
      outDay: () => '2026-10-18',
      offSeen: true,
    ));
    expect(late.giveBattery(at(19, 17, 10)), isTrue);
    expect(late.outAt(at(19, 17, 10)), isFalse);
  });

  test('charging at 12:00 he goes out all the same', () {
    final pip = hatched(energy: 0.04, energyAt: at(19, 9));
    pip.replace(pip.state.copyWith(
      registeredAt: () => at(18, 14),
      outDay: () => '2026-10-18',
    ));
    pip.setCharging(true, at(19, 9));
    pip.collect(at(19, 13));
    expect(pip.state.outFrom, at(19, 12));
  });

  test('out, he can\'t power down; he does after 18:00', () {
    // Enough for about two hours (a segment lasts 4 hours awake).
    final pip = hatched(energy: 0.5, energyAt: at(19, 11, 59));
    pip.replace(pip.state.copyWith(
      registeredAt: () => at(18, 14),
      outDay: () => '2026-10-18',
    ));
    pip.collect(at(19, 12));
    expect(pip.outAt(at(19, 12)), isTrue);
    expect(pip.levelAt(at(19, 17)), greaterThan(0));
    expect(pip.showAt(at(19, 17)), PipShow.awake);
    expect(pip.xpAt(at(19, 18)), 360);
    expect(pip.showAt(at(19, 18, 1)), PipShow.powerOff);
  });

  test('his break: looked at between 14:00 and 16:00, once a day', () {
    final pip = hatched();
    pip.register(at(18, 13));
    pip.breakIfDue(at(18, 13, 50));
    expect(pip.state.breakAt, isNull, reason: 'before 14:00');
    pip.breakIfDue(at(18, 14, 10));
    expect(pip.state.breakAt, at(18, 14, 10));
    expect(pip.onBreakAt(at(18, 14, 30)), isTrue);
    expect(pip.onBreakAt(at(18, 14, 40)), isFalse);
    pip.breakIfDue(at(18, 15));
    expect(pip.state.breakAt, at(18, 14, 10), reason: 'once');
    // XP goes on through it.
    expect(pip.xpAt(at(18, 15)), 120);
    // The next day, a new break.
    fill(pip, at(19, 11));
    pip.collect(at(19, 14, 20));
    pip.breakIfDue(at(19, 14, 20));
    expect(pip.state.breakAt, at(19, 14, 20));
  });

  test('saved and read back (pip.json v3)', () {
    final pip = hatched();
    pip.register(at(18, 13));
    pip.breakIfDue(at(18, 14, 10));
    final json = pip.state.toJson();
    expect(PipLife.fromJson(json), pip.state);
    expect(json['adventure'], {
      'registeredAt': at(18, 13).toUtc().toIso8601String(),
      'xp': 0,
      'outDay': '2026-10-18',
      'outFrom': at(18, 13).toUtc().toIso8601String(),
      'breakAt': at(18, 14, 10).toUtc().toIso8601String(),
    });
    expect(PipLife(born: at(10, 9)).toJson().containsKey('adventure'), isFalse);
  });

  test('the level and title with his XP', () {
    expect(PipAdventure.levelFor(0), 1);
    expect(PipAdventure.titleFor(PipAdventure.levelFor(0)), 'Rookie');
  });

  test('plugged in, out on his adventure: he can have a battery (Round 65)',
      () {
    final pip = hatched(energy: 1, energyAt: at(19, 11, 59));
    pip.replace(pip.state.copyWith(
      registeredAt: () => at(18, 14),
      outDay: () => '2026-10-18',
    ));
    pip.setCharging(true, at(19, 11, 59));
    pip.collect(at(19, 13));
    expect(pip.outAt(at(19, 13)), isTrue);
    expect(pip.refusalAt(at(19, 13)), isNull);
    expect(pip.giveBattery(at(19, 13)), isTrue);
    // Back from it, plugged in, he's at his station again: not now.
    expect(pip.refusalAt(at(19, 19)), PipRefusal.charging);
  });
}
