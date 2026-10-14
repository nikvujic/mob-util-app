import 'dart:convert';
import 'dart:typed_data';

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/pip_life_provider.dart';

import '../helpers.dart';

/// Pip, the pet (Round 34): hatched once, his age from his birthday.
void main() {
  test('an egg until hatched; hatched once, on that day', () {
    final pip = PipLifeNotifier(AppStorage.inMemory());
    expect(pip.state.hatched, isFalse);
    expect(pip.state.ageOn(DateTime(2026, 10, 14)), isNull);
    pip.hatch(DateTime(2026, 10, 14, 21, 30));
    pip.hatch(DateTime(2026, 10, 20)); // only once
    expect(pip.state.born, DateTime(2026, 10, 14, 21, 30));
    expect(pip.state.name, 'Pip');
  });

  test('his age in days: the day he hatched is day 1', () {
    final pip = PipLife(born: DateTime(2026, 10, 14, 23, 50));
    expect(pip.ageOn(DateTime(2026, 10, 14, 23, 59)), 1);
    expect(pip.ageOn(DateTime(2026, 10, 15, 0, 1)), 2);
    expect(pip.ageOn(DateTime(2027, 10, 14, 12)), 366);
    // Across a clock change (late October in Europe): still whole days.
    expect(
        PipLife(born: DateTime(2026, 10, 24, 12))
            .ageOn(DateTime(2026, 10, 26, 1)),
        3);
    expect(PipLife.ageText(1), '1 DAY');
    expect(PipLife.ageText(12), '12 DAYS');
  });

  test('renamed: trimmed, at most 6 letters; blank keeps his', () {
    final pip = PipLifeNotifier(AppStorage.inMemory());
    pip.rename('  Bip  ');
    expect(pip.state.name, 'Bip');
    pip.rename('   ');
    expect(pip.state.name, 'Bip');
    pip.rename('Abcdefghijklmnop');
    expect(pip.state.name, 'Abcdef');
  });

  group('in backups', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        appVersionProvider.overrideWithValue('1'),
        backupFilesProvider.overrideWithValue(FakeBackupFiles()),
      ]);
      addTearDown(container.dispose);
    });

    RestorableBackup open(Backup b) => (container
            .read(backupImporterProvider)
            .read(Uint8List.fromList(utf8.encode(b.encode()))) as PlainPick)
        .backup;

    test('restored with his birthday (so his real age), undone too', () async {
      container.read(pipLifeProvider.notifier).hatch(DateTime(2026, 10, 20));
      final saved = Backup(
        createdAt: DateTime(2026, 10, 21),
        appVersion: '1',
        notes: const [],
        shopItems: const [],
        pip: PipLife(born: DateTime(2026, 1, 1), name: 'Old'),
      );
      final undo =
          await container.read(backupImporterProvider).restore(open(saved));
      expect(container.read(pipLifeProvider).born, DateTime(2026, 1, 1));
      expect(container.read(pipLifeProvider).name, 'Old');
      await container.read(backupImporterProvider).undo(undo!);
      expect(container.read(pipLifeProvider).born, DateTime(2026, 10, 20));
    });

    test('a backup from before him leaves him as he is', () async {
      container.read(pipLifeProvider.notifier).hatch(DateTime(2026, 10, 20));
      await container.read(backupImporterProvider).restore(open(Backup(
            createdAt: DateTime(2026, 10, 21),
            appVersion: '1',
            notes: const [],
            shopItems: const [],
          )));
      expect(container.read(pipLifeProvider).hatched, isTrue);
    });
  });

  group('his energy and batteries (Round 37)', () {
    late DateTime now;
    PipLifeNotifier start({PipLife? pip}) {
      now = DateTime(2026, 10, 14, 9);
      return PipLifeNotifier(
        AppStorage.inMemory(initialPip: pip ?? PipLife.egg),
        clock: () => now,
        random: math.Random(4),
      );
    }

    test('hatched: full, no batteries, the first on its way', () {
      final pip = start()..hatch(DateTime(2026, 10, 14, 9));
      expect(pip.state.energy, 3);
      expect(pip.state.energyAt, DateTime(2026, 10, 14, 9));
      expect(pip.state.batteries, 0);
      final gap = pip.state.nextBatteryAt!.difference(pip.state.energyAt!);
      expect(gap.inMinutes, inInclusiveRange(270, 450));
    });

    test('a Pip from before: full from now on', () {
      final pip = start(pip: PipLife(born: DateTime(2026, 10, 1)));
      expect(pip.state.energyAt, now);
      expect(pip.state.nextBatteryAt, isNotNull);
      expect(pip.levelAt(now), 3);
    });

    test('a battery when the app is opened after its time; never piled up', () {
      final pip = start()..hatch(now);
      final due = pip.state.nextBatteryAt!;
      pip.collect(due.subtract(const Duration(minutes: 1)));
      expect(pip.state.batteries, 0, reason: 'not yet');
      // Away three days: still just the one.
      final later = due.add(const Duration(days: 3));
      pip.collect(later);
      expect(pip.state.batteries, 1);
      expect(pip.state.nextBatteryAt!.isAfter(later), isTrue,
          reason: 'the next timed from now');
      pip.collect(later);
      expect(pip.state.batteries, 1);
    });

    test('at most 3 held', () {
      final pip = start()..hatch(now);
      for (var i = 0; i < 5; i++) {
        pip.collect(pip.state.nextBatteryAt!);
      }
      expect(pip.state.batteries, PipEnergy.maxBatteries);
    });

    test('a battery: only when he has one, isn\'t full nor asleep', () {
      final pip = start(
        pip: PipLife(
          born: DateTime(2026, 10, 1),
          energyAt: DateTime(2026, 10, 14, 9),
          batteries: 1,
          nextBatteryAt: DateTime(2026, 10, 15),
        ),
      );
      expect(pip.refusalAt(now), PipRefusal.full);
      expect(pip.giveBattery(now), isFalse);
      // Ten hours on: two segments left.
      final later = DateTime(2026, 10, 14, 19);
      expect(PipEnergy.segments(pip.levelAt(later)), 2);
      expect(pip.giveBattery(later), isTrue);
      expect(pip.state.batteries, 0);
      expect(pip.levelAt(later), 3);
      expect(pip.refusalAt(DateTime(2026, 10, 15, 5)), PipRefusal.noBatteries);
    });

    test('asleep, no battery; off, one turns him back on', () {
      final asleep = start(
        pip: PipLife(
          born: DateTime(2026, 10, 1),
          energy: 1.5,
          energyAt: DateTime(2026, 10, 15, 1),
          batteries: 2,
          nextBatteryAt: DateTime(2026, 10, 16),
        ),
      );
      expect(asleep.refusalAt(DateTime(2026, 10, 15, 2)), PipRefusal.asleep);
      final off = start(
        pip: PipLife(
          born: DateTime(2026, 10, 1),
          energy: 0,
          energyAt: DateTime(2026, 10, 15, 1),
          batteries: 1,
          nextBatteryAt: DateTime(2026, 10, 16),
          offSeen: true,
        ),
      );
      final at = DateTime(2026, 10, 15, 2);
      expect(off.showAt(at), PipShow.off);
      expect(off.giveBattery(at), isTrue);
      expect(off.state.offSeen, isFalse);
      expect(off.levelAt(at), 1);
    });

    test('what was shown is remembered', () {
      final pip = start()..hatch(now);
      pip.shown(PipShow.fallAsleep, DateTime(2026, 10, 14, 23, 10));
      expect(pip.state.sleepSeen, '2026-10-14');
      expect(pip.showAt(DateTime(2026, 10, 14, 23, 30)), PipShow.asleep);
      pip.shown(PipShow.wakeUp, DateTime(2026, 10, 15, 8, 10));
      expect(pip.state.wakeSeen, '2026-10-15');
      expect(pip.showAt(DateTime(2026, 10, 15, 8, 30)), PipShow.awake);
    });

    test('ran out: shown off once; kept empty', () {
      final pip = start()..hatch(now);
      final later = DateTime(2026, 10, 16, 12);
      expect(pip.showAt(later), PipShow.powerOff);
      pip.shown(PipShow.powerOff, later);
      expect(pip.state.offSeen, isTrue);
      expect(pip.state.energy, 0);
      expect(pip.showAt(later), PipShow.off);
    });

    test('the link: collects, says what to show and how full', () {
      final container = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory(
          initialPip: PipLife(
            born: DateTime(2026, 10, 1),
            energy: 1.5,
            energyAt: DateTime(2026, 10, 14, 9),
            nextBatteryAt: DateTime(2026, 10, 14, 10),
          ),
        )),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 14, 12)),
        pipRandomProvider.overrideWithValue(math.Random(1)),
      ]);
      addTearDown(container.dispose);
      final link = container.read(pipLinkProvider);
      expect(link.look(), (PipShow.awake, 2));
      expect(container.read(pipLifeProvider).batteries, 1, reason: 'due');
      expect(link.giveBattery(), isTrue);
      expect(link.look().$2, 3);
    });

    test('restored: carries on from where the backup left him', () {
      final pip = start();
      pip.replace(PipLife(
        born: DateTime(2026, 10, 1),
        energy: 2,
        energyAt: DateTime(2026, 10, 14, 7),
        batteries: 2,
        nextBatteryAt: DateTime(2026, 10, 14, 12),
      ));
      // Two hours since the backup: one asleep (to 8:00), one awake.
      expect(pip.levelAt(now), closeTo(2 - 1 / 36 - 1 / 10, 1e-9));
      expect(pip.state.batteries, 2);
    });
  });
}
