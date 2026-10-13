// Every data format the app has ever written must stay readable, so an
// update can never lose a user's data. The files in test/fixtures/ are
// frozen copies of real output; see test/fixtures/README.md.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/counter.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/notes_provider.dart';

void main() {
  const password = 'fixture password';

  /// A scratch copy of a fixture folder (loading may move files aside).
  Directory copyOf(String path) {
    final dir = Directory.systemTemp.createTempSync('compat');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final f in Directory(path).listSync().whereType<File>()) {
      f.copySync('${dir.path}/${f.uri.pathSegments.last}');
    }
    return dir;
  }

  group('v1', () {
    test('app data loads completely', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v1/storage'),
      );

      final notes = storage.initialNotes;
      expect(notes.map((n) => n.title), ['Groceries', 'Untitled']);
      expect(notes.first.content, 'milk\neggs\nčaj, ćevapi 🥙');
      expect(notes.first.modifiedAt, DateTime.utc(2026, 10, 8, 7, 30));
      // Local time without a zone, as the app writes it.
      expect(notes.last.modifiedAt, DateTime(2026, 10, 7, 21, 16, 30, 500));

      expect(
        storage.initialShopItems.map((i) => '${i.name}:${i.toBuy}'),
        ['Milk:true', 'Coffee:false'],
      );

      final verifier = storage.initialMasterPassword!;
      expect(await verifier.unlock(password), isNotNull);
      expect(await verifier.unlock('wrong'), isNull);
      // v1 master passwords had no data key; it's added on first unlock.
      expect(verifier.hasDataKey, isFalse);
    });

    test('nothing was moved aside as unreadable', () async {
      final dir = copyOf('test/fixtures/v1/storage');
      await AppStorage.open(directory: dir);
      final names = dir.listSync().map((f) => f.uri.pathSegments.last);
      expect(names.where((n) => n.contains('corrupt')), isEmpty);
    });

    test('plain backup restores', () {
      final file = BackupFile.parse(
        File('test/fixtures/v1/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expect(file.backup.notes, hasLength(2));
      expect(file.backup.shopItems, hasLength(2));
    });

    test('encrypted backup opens with its password', () async {
      final file = BackupFile.parse(
        File('test/fixtures/v1/backup-encrypted.json').readAsStringSync(),
      ) as EncryptedBackupFile;
      final backup = await file.open(password);
      expect(backup!.notes.first.title, 'Groceries');
      expect(await file.open('wrong'), isNull);
    });
  });

  group('v2', () {
    test('app data loads completely; the locked note opens', () async {
      final dir = copyOf('test/fixtures/v2/storage');
      final storage = await AppStorage.open(directory: dir);
      expect(
        dir.listSync().map((f) => f.uri.pathSegments.last),
        isNot(contains(contains('corrupt'))),
      );

      final notes = storage.initialNotes;
      expect(notes.map((n) => n.title), ['Groceries', 'Bank 🔒']);
      expect(notes.first.isLocked, isFalse);
      expect(notes.first.content, 'milk\neggs\nčaj, ćevapi 🥙');
      final locked = notes.last;
      expect(locked.isLocked, isTrue);
      expect(locked.content, isEmpty);
      expect(locked.modifiedAt, DateTime(2026, 10, 7, 21, 16, 30, 500));

      expect(
        storage.initialShopItems.map((i) => '${i.name}:${i.toBuy}'),
        ['Milk:true', 'Coffee:false'],
      );
      expect(
        storage.initialPlannerTasks.map((t) => (t.title, t.day, t.done)),
        [
          ('Gym 🏋️', DateTime(2026, 10, 12), true),
          ('Zubar (dentist)', DateTime(2026, 10, 13), false),
        ],
      );
      expect(
        storage.initialCounters.map((c) => (c.name, c.value)),
        [('Sklekovi (push-ups)', 42), ('Score', -3)],
      );

      final verifier = storage.initialMasterPassword!;
      final passwordKey = (await verifier.unlock(password))!;
      final dataKey = (await verifier.unwrapDataKey(passwordKey))!;
      expect(
        await NotesNotifier(storage).readContent(locked, dataKey),
        'PIN 4711\nšifra: žuta ćuprija',
      );
    });

    /// The locked note of a v2 backup opens with the key in its record.
    Future<void> expectLockedNoteOpens(Backup backup) async {
      final record = backup.masterPassword!;
      final dataKey = (await record.unwrapDataKey(
        (await record.unlock(password))!,
      ))!;
      final locked = backup.notes.singleWhere((n) => n.isLocked);
      expect(
        await NotesNotifier.openContent(locked, dataKey),
        'PIN 4711\nšifra: žuta ćuprija',
      );
    }

    test('plain backup restores; its locked note opens', () async {
      final file = BackupFile.parse(
        File('test/fixtures/v2/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expect(file.backup.notes.map((n) => n.title), ['Groceries', 'Bank 🔒']);
      expect(file.backup.shopItems, hasLength(2));
      await expectLockedNoteOpens(file.backup);
    });

    test('encrypted backup opens; its locked note opens', () async {
      final file = BackupFile.parse(
        File('test/fixtures/v2/backup-encrypted.json').readAsStringSync(),
      ) as EncryptedBackupFile;
      expect(await file.open('wrong'), isNull);
      await expectLockedNoteOpens((await file.open(password))!);
    });
  });

  group('v3', () {
    Future<void> expectComplete(Backup backup) async {
      expect(backup.notes.map((n) => n.title), ['Groceries', 'Bank 🔒']);
      expect(backup.shopItems, hasLength(2));
      expect(
        backup.plannerTasks.map((t) => (t.title, t.day, t.done)),
        [
          ('Gym 🏋️', DateTime(2026, 10, 12), true),
          ('Zubar (dentist)', DateTime(2026, 10, 13), false),
        ],
      );
      final record = backup.masterPassword!;
      final dataKey = (await record.unwrapDataKey(
        (await record.unlock(password))!,
      ))!;
      expect(
        await NotesNotifier.openContent(
          backup.notes.singleWhere((n) => n.isLocked),
          dataKey,
        ),
        'PIN 4711\nšifra: žuta ćuprija',
      );
    }

    test('plain backup restores, planner included', () async {
      final file = BackupFile.parse(
        File('test/fixtures/v3/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      await expectComplete(file.backup);
    });

    test('encrypted backup opens, planner included', () async {
      final file = BackupFile.parse(
        File('test/fixtures/v3/backup-encrypted.json').readAsStringSync(),
      ) as EncryptedBackupFile;
      await expectComplete((await file.open(password))!);
    });
  });

  test('v3 backup with counters restores them', () {
    final file = BackupFile.parse(
      File('test/fixtures/v3/backup-with-counters.json').readAsStringSync(),
    ) as PlainBackupFile;
    expect(
      file.backup.counters.map((c) => (c.name, c.value)),
      [('Sklekovi (push-ups)', 42), ('Score', -3)],
    );
    expect(file.backup.plannerTasks, hasLength(2));
  });

  group('v3 planner / v4 backup (timed tasks)', () {
    void expectTimed(List<PlannerTask> tasks) {
      expect(
        tasks.map((t) => (t.title, t.day, t.start, t.end, t.done)),
        [
          ('Teretana (gym)', DateTime(2026, 10, 12), 480, 540, true),
          ('Late call', DateTime(2026, 10, 12), 1410, 1440, false),
        ],
      );
    }

    test('planner.json with times loads', () async {
      final dir = copyOf('test/fixtures/v3/storage');
      final storage = await AppStorage.open(directory: dir);
      expectTimed(storage.initialPlannerTasks);
      expect(
        dir.listSync().map((f) => f.uri.pathSegments.last),
        isNot(contains(contains('corrupt'))),
      );
    });

    test('v4 backup restores timed tasks', () {
      final file = BackupFile.parse(
        File('test/fixtures/v4/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectTimed(file.backup.plannerTasks);
      expect(file.backup.counters, hasLength(2));
    });

    test('tasks from before times have none (still shown, marked)', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v2/storage'),
      );
      expect(
        storage.initialPlannerTasks.every((t) => !t.hasTime),
        isTrue,
      );
    });
  });

  group('planner v4 / routines v1 / v5 backup (routines, colours)', () {
    void expectSample(List<PlannerTask> tasks, RoutineBook book) {
      expect(tasks.map((t) => '${t.title}:${t.color}'),
          ['Dentist:blue', 'Groceries:null']);
      expect(book.routines.map((r) => r.title), ['Gym', 'Read 📚']);
      final gym = book.routines.first;
      expect((gym.start, gym.end), (1080, 1140));
      expect(gym.weekdays, {1, 3, 5});
      expect((gym.from, gym.until, gym.color),
          (DateTime(2026, 10, 1), null, 'green'));
      expect(book.routines.last.until, DateTime(2026, 12, 31));
      final monday = DateTime(2026, 10, 12);
      expect(book.dayOf('r1', monday)!.skipped, isTrue);
      expect(book.dayOf('r2', monday)!.done, isTrue);
    }

    test('planner.json with colours and routines.json load', () async {
      final dir = copyOf('test/fixtures/v5/storage');
      final storage = await AppStorage.open(directory: dir);
      expectSample(storage.initialPlannerTasks, storage.initialRoutines);
      final names = dir.listSync().map((f) => f.uri.pathSegments.last);
      expect(names.where((n) => n.contains('corrupt')), isEmpty);
    });

    test('v5 backup restores tasks and routines', () {
      final file = BackupFile.parse(
        File('test/fixtures/v5/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.plannerTasks, file.backup.routines);
    });

    test('older backups and data have no routines', () async {
      final file = BackupFile.parse(
        File('test/fixtures/v4/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expect(file.backup.routines.isEmpty, isTrue);
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v3/storage'),
      );
      expect(storage.initialRoutines.isEmpty, isTrue);
    });
  });

  group('pins v1 / v6 backup (reminders)', () {
    void expectSample(List<PlannerPin> pins) {
      expect(
        pins.map((p) => '${p.title} ${p.day.day}/${p.day.month} ${p.time}'),
        ['Call mum 12/10 630', 'Take out the bins 🗑 13/10 1200'],
      );
    }

    test('pins.json loads', () async {
      final dir = copyOf('test/fixtures/v6/storage');
      final storage = await AppStorage.open(directory: dir);
      expectSample(storage.initialPins);
      final names = dir.listSync().map((f) => f.uri.pathSegments.last);
      expect(names.where((n) => n.contains('corrupt')), isEmpty);
    });

    test('v6 backup restores reminders with the tasks', () {
      final file = BackupFile.parse(
        File('test/fixtures/v6/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.plannerPins);
      expect(file.backup.plannerTasks.single.title, 'Work');
    });

    test('older backups and data have no reminders', () async {
      final file = BackupFile.parse(
        File('test/fixtures/v5/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expect(file.backup.plannerPins, isEmpty);
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v5/storage'),
      );
      expect(storage.initialPins, isEmpty);
    });
  });

  group('planner v5 / routines v2 / v7 backup (descriptions)', () {
    void expectSample(List<PlannerTask> tasks, RoutineBook book) {
      expect(
          tasks.map((t) => t.description), ['Bring the X-ray.\nFloor 2', null]);
      final pills = book.routines.single;
      expect((pills.title, pills.end - pills.start, pills.description),
          ('Pills 💊', 5, 'One with water'));
    }

    test('planner.json and routines.json with descriptions load', () async {
      final dir = copyOf('test/fixtures/v7/storage');
      final storage = await AppStorage.open(directory: dir);
      expectSample(storage.initialPlannerTasks, storage.initialRoutines);
      final names = dir.listSync().map((f) => f.uri.pathSegments.last);
      expect(names.where((n) => n.contains('corrupt')), isEmpty);
    });

    test('v7 backup restores descriptions', () {
      final file = BackupFile.parse(
        File('test/fixtures/v7/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.plannerTasks, file.backup.routines);
    });

    test('older data has no descriptions', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v5/storage'),
      );
      expect(storage.initialPlannerTasks.map((t) => t.description),
          everyElement(isNull));
    });
  });

  group('shop v3 / v8 backup (quantities)', () {
    void expectSample(List<ShopItem> items) {
      expect(
        items.map((i) => (i.name, i.quantity, i.count, i.grams)),
        [
          ('Milk', Quantity.count, 2, 200.0),
          ('Flour', Quantity.weight, 1, 1500.0),
          ('Saffron 🌼', Quantity.weight, 4, 0.5),
          ('Bread', null, 3, 200.0),
        ],
      );
      expect(items.last.toBuy, isFalse);
    }

    test('shop.json with quantities loads', () async {
      final dir = copyOf('test/fixtures/v8/storage');
      final storage = await AppStorage.open(directory: dir);
      expectSample(storage.initialShopItems);
      final names = dir.listSync().map((f) => f.uri.pathSegments.last);
      expect(names.where((n) => n.contains('corrupt')), isEmpty);
    });

    test('v8 backup restores quantities', () {
      final file = BackupFile.parse(
        File('test/fixtures/v8/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.shopItems);
    });

    test('layout.json (Other\'s order, O9) loads', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v8/storage'),
      );
      expect(storage.initialLayout.hub.first, HubTool.counters);
      expect(storage.unreadable, isEmpty);
    });

    test('older shop items have none', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v2/storage'),
      );
      expect(storage.initialShopItems.map((i) => i.quantity),
          everyElement(isNull));
      expect(storage.initialShopItems.map((i) => (i.count, i.grams)),
          everyElement((1, 200.0)));
    });
  });

  group('placard v1 / v9 backup (Placard, O4)', () {
    test('placard.json loads', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v9/storage'),
      );
      expect((storage.initialPlacard.text, storage.initialPlacard.count),
          ('Why so quiet? 🤐', 41));
      expect(storage.unreadable, isEmpty);
    });

    test('v9 backup restores Placard', () {
      final file = BackupFile.parse(
        File('test/fixtures/v9/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expect((file.backup.placard.text, file.backup.placard.count),
          ('Why so quiet? 🤐', 41));
      expect(file.backup.counters.single.value, 12);
    });

    test('older backups have a fresh one (the old Džoni count is ignored)', () {
      for (final path in [
        'test/fixtures/v4/backup-plain.json',
        'test/fixtures/v8/backup-plain.json',
      ]) {
        final file =
            BackupFile.parse(File(path).readAsStringSync()) as PlainBackupFile;
        expect(file.backup.placard.isSet, isFalse, reason: path);
      }
    });
  });

  group('counters v3 / v10 backup (counter options, O5)', () {
    void expectSample(List<Counter> counters) {
      expect(
        counters.map((c) => (c.name, c.value, c.step, c.color, c.min, c.max)),
        [
          ('Push-ups', 12, 1, null, null, null),
          ('Water 💧', 750, 250, 'blue', 0, 3000),
          ('Floor', -2, 1, null, -3, null),
        ],
      );
    }

    test('counters.json with options loads', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v10/storage'),
      );
      expectSample(storage.initialCounters);
      expect(storage.unreadable, isEmpty);
    });

    test('v10 backup restores counter options', () {
      final file = BackupFile.parse(
        File('test/fixtures/v10/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.counters);
    });

    test('older counters count by 1, with no limits', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v2/storage'),
      );
      expect(storage.initialCounters, isNotEmpty);
      expect(
        storage.initialCounters.map((c) => (c.step, c.color, c.min, c.max)),
        everyElement((1, null, null, null)),
      );
    });
  });

  group('medicine v1 / v11 backup (medicine tracker, O6)', () {
    void expectSample(MedicineBook book) {
      expect(book.medicines.map((m) => (m.name, m.dosesADay, m.until)), [
        ('Vitamin D 💊', 1, null),
        ('Antibiotic', 2, DateTime(2026, 10, 16)),
      ]);
      final day = DateTime(2026, 10, 11);
      expect(book.takenFor('m1', day, 0)!.at, DateTime(2026, 10, 11, 8, 4));
      expect(book.takenFor('m2', day, 1)!.at, DateTime(2026, 10, 11, 20, 31));
      expect(book.takenFor('m2', day, 0), isNull);
    }

    test('medicine.json loads', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v11/storage'),
      );
      expectSample(storage.initialMedicine);
      expect(storage.unreadable, isEmpty);
    });

    test('v11 backup restores the medicine tracker', () {
      final file = BackupFile.parse(
        File('test/fixtures/v11/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.medicine);
    });

    test('older backups have none', () {
      final file = BackupFile.parse(
        File('test/fixtures/v10/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expect(file.backup.medicine.medicines, isEmpty);
    });
  });

  group('medicine v2 / v12 backup (dose states, O13)', () {
    void expectSample(MedicineBook book) {
      DoseTaken? mark(int month, int day) =>
          book.markFor('m1', DateTime(2026, month, day), 0);
      expect((mark(7, 1)!.state, mark(7, 1)!.at), (DoseState.taken, null),
          reason: 'filled in: no time');
      expect(mark(7, 2)!.state, DoseState.missed);
      expect(mark(7, 3)!.state, DoseState.unsure);
      expect(mark(10, 12)!.at, DateTime(2026, 10, 12, 7, 55));
      expect(book.takenCount('m1'), 2);
    }

    test('medicine.json version 2 loads', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v12/storage'),
      );
      expectSample(storage.initialMedicine);
      expect(storage.unreadable, isEmpty);
    });

    test('v12 backup restores dose states', () {
      final file = BackupFile.parse(
        File('test/fixtures/v12/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.medicine);
    });

    test('version 1 doses read as taken, with their time', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v11/storage'),
      );
      final mark =
          storage.initialMedicine.markFor('m1', DateTime(2026, 10, 11), 0)!;
      expect((mark.state, mark.at),
          (DoseState.taken, DateTime(2026, 10, 11, 8, 4)));
    });
  });

  group('medicine v3 / v13 backup (remind again per medicine, Round 16)', () {
    void expectSample(MedicineBook book) {
      final [iron, vitaminC] = book.medicines;
      expect((iron.name, iron.followUp), ('Iron 🩸', 240));
      expect(vitaminC.followUp, isNull);
      expect(book.markFor('m1', DateTime(2026, 10, 12), 0)!.at,
          DateTime(2026, 10, 12, 8, 2));
    }

    test('medicine.json version 3 loads', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v13/storage'),
      );
      expectSample(storage.initialMedicine);
      expect(storage.unreadable, isEmpty);
    });

    test('v13 backup restores it', () {
      final file = BackupFile.parse(
        File('test/fixtures/v13/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.medicine);
    });

    test('version 2 medicines have none', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v12/storage'),
      );
      expect(storage.initialMedicine.medicines.single.followUp, isNull);
    });
  });

  group('medicine v4 / v14 backup (important medicines, Round 24)', () {
    void expectSample(MedicineBook book) {
      final [heart, vitaminC] = book.medicines;
      expect((heart.name, heart.important), ('Heart pills ❤️', true));
      expect(vitaminC.important, isFalse);
      expect(book.markFor('m1', DateTime(2026, 10, 12), 0)!.at,
          DateTime(2026, 10, 12, 8, 1));
    }

    test('medicine.json version 4 loads', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v14/storage'),
      );
      expectSample(storage.initialMedicine);
      expect(storage.unreadable, isEmpty);
    });

    test('v14 backup restores it', () {
      final file = BackupFile.parse(
        File('test/fixtures/v14/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.medicine);
    });

    test('version 3 medicines are not important', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v13/storage'),
      );
      expect(storage.initialMedicine.medicines.map((m) => m.important),
          everyElement(isFalse));
    });
  });

  group('todo.json v1 / v15 backup (the to-do note, Round 28)', () {
    void expectSample(List<TodoItem> items) {
      expect(items.map((i) => (i.id, i.text)), [
        ('t1', 'Call the dentist 🦷'),
        ('t2', 'Pay the bills, šta god'),
        ('t3', 'Water the plants'),
      ]);
    }

    test('todo.json version 1 loads', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v15/storage'),
      );
      expectSample(storage.initialTodo);
      expect(storage.unreadable, isEmpty);
    });

    test('v15 backup restores it', () {
      final file = BackupFile.parse(
        File('test/fixtures/v15/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.todo);
    });

    test('older backups and storage have none', () async {
      final file = BackupFile.parse(
        File('test/fixtures/v14/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expect(file.backup.todo, isEmpty);
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v14/storage'),
      );
      expect(storage.initialTodo, isEmpty);
    });
  });

  group('todo.json v2 / v16 backup (done to-dos, Round 30)', () {
    void expectSample(List<TodoItem> items) {
      expect(items.map((i) => (i.text, i.done)), [
        ('Call the dentist 🦷', false),
        ('Pay the bills, šta god', true),
        ('Water the plants', false),
      ]);
    }

    test('todo.json version 2 loads', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v16/storage'),
      );
      expectSample(storage.initialTodo);
      expect(storage.unreadable, isEmpty);
    });

    test('v16 backup restores it', () {
      final file = BackupFile.parse(
        File('test/fixtures/v16/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.todo);
    });

    test('version 1 things are not done', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v15/storage'),
      );
      expect(storage.initialTodo.map((i) => i.done), everyElement(isFalse));
    });
  });

  test('notifications.json version 1 (Round 31) loads', () async {
    final storage = await AppStorage.open(
      directory: copyOf('test/fixtures/v16/storage'),
    );
    final log = storage.initialNotificationLog;
    expect(log.scheduled.map((n) => (n.title, n.kind, n.target)), [
      ('Iron 🩸', 'medicine', 'medicine'),
      ('Zubar, čet', 'planner', 'planner|2026-10-13|660'),
    ]);
    expect(log.scheduled.last.at.toUtc(), DateTime.utc(2026, 10, 13, 8, 50));
    expect(log.scheduled.last.body, 'In 10 min · 11:00–12:00');
    expect(log.clearedAt!.toUtc(), DateTime.utc(2026, 10, 12, 19));
    expect(storage.unreadable, isEmpty);
  });

  group('pip.json v1 / v17 backup (Pip, the pet, Round 34)', () {
    void expectSample(PipLife? pip) {
      expect(pip!.name, 'Bip 2');
      expect(pip.born!.toUtc(), DateTime.utc(2026, 10, 13, 20, 30));
      expect(pip.hatched, isTrue);
    }

    test('pip.json version 1 loads', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v17/storage'),
      );
      expectSample(storage.initialPip);
      expect(storage.unreadable, isEmpty);
    });

    test('v17 backup restores him', () {
      final file = BackupFile.parse(
        File('test/fixtures/v17/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectSample(file.backup.pip);
    });

    test('before him: an egg; older backups leave him be', () async {
      final storage = await AppStorage.open(
        directory: copyOf('test/fixtures/v16/storage'),
      );
      expect(storage.initialPip, PipLife.egg);
      final file = BackupFile.parse(
        File('test/fixtures/v16/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expect(file.backup.pip, isNull);
    });
  });

  test('settings.json with page locks (O7, Round 21) loads them', () async {
    final storage = await AppStorage.open(
      directory: copyOf('test/fixtures/v13/storage'),
    );
    expect(storage.initialSectionLocks, {AppSection.shop});
    expect(storage.initialPageLocks, {HubTool.placard, HubTool.medicine});
  });

  test('backups from before the planner restore with no tasks', () {
    for (final path in [
      'test/fixtures/v1/backup-plain.json',
      'test/fixtures/v2/backup-plain.json',
    ]) {
      final file =
          BackupFile.parse(File(path).readAsStringSync()) as PlainBackupFile;
      expect(file.backup.plannerTasks, isEmpty, reason: path);
      expect(file.backup.counters, isEmpty, reason: path);
    }
  });

  test('a file from a newer format is kept aside, not misread', () async {
    final dir = Directory.systemTemp.createTempSync('compat_newer');
    addTearDown(() => dir.deleteSync(recursive: true));
    final newer =
        jsonEncode({'version': AppStorage.formatVersion + 1, 'notes': []});
    File('${dir.path}/notes.json').writeAsStringSync(newer);

    final storage = await AppStorage.open(directory: dir);

    expect(storage.initialNotes, isEmpty);
    final kept = dir
        .listSync()
        .whereType<File>()
        .singleWhere((f) => f.path.contains('notes.json.corrupt-'));
    expect(kept.readAsStringSync(), newer, reason: 'kept intact');
  });

  test('the fixtures are the frozen originals', () async {
    // Guards against "fixing" a fixture instead of the code: these are the
    // SHA-256 hashes of the files as first written.
    const expected = {
      'test/fixtures/v1/backup-encrypted.json':
          '2869f75b7b564146048f266de1ee33a77f30d71f97faba4e4a4abe3a5076aeb4',
      'test/fixtures/v1/backup-plain.json':
          'fa73019263647212a988a8a4f9c9aa00bd49f923e1b7248adf1cf6fff43b49f8',
      'test/fixtures/v1/storage/notes.json':
          '275102f2b322a18baca21c6a44f3ebc4332c01be0b3da0ce6ed4d8481f5e5f6e',
      'test/fixtures/v1/storage/security.json':
          '60a13aad885197272595c40c3ff4b9dec427abe0db9c9c47ba6fa9467c9522de',
      'test/fixtures/v1/storage/shop.json':
          '7188622d7ea03d5c34f3215938067caf037f3085d17d252c173585420e4b0c6b',
      'test/fixtures/v2/backup-encrypted.json':
          '3506088d05c89d7a56ad408e4cd0b0e063ec5929c26841cb76633bef8f83a39c',
      'test/fixtures/v2/backup-plain.json':
          'dd8e5281208d99ba28c63a85f6f32d28af3441c94e7ceb577c673005e35c349f',
      'test/fixtures/v3/storage/planner.json':
          '2a2c5aaa83ce538d08e4d969612f95d6d5d3acd49687e00b09559d3047f75a0d',
      'test/fixtures/v4/backup-plain.json':
          '20376e060b09d9df4f0fcf1758f3af32095be6603dd040abc10a0c111c6e8425',
      'test/fixtures/v2/storage/counters.json':
          'aa7cc75ffd4476327da6f0b82a1f6b06e580777033d159ab45311ad989d09a47',
      'test/fixtures/v3/backup-with-counters.json':
          '3caa3fc9fe9a61f7055ee2091c9c658eeb75e392aaaa3e6bca6226318b3428ff',
      'test/fixtures/v2/storage/planner.json':
          'a3928ad12d0fe19977f0f049343a1584ec4b954f67dbb946d9eaa19ac608a57e',
      'test/fixtures/v3/backup-encrypted.json':
          'af41612a6763d3e61c017c4de4c13ec405847c85d2d3541e38e08fb83015a6e7',
      'test/fixtures/v3/backup-plain.json':
          'd3ce39c714e6e9751105d91fa676d54d7a2473a84abe2e7ec0403e08ea411f01',
      'test/fixtures/v2/storage/notes.json':
          '551f9ec617ceb9cf43e39e113c49bc993347433187abb956733f52655c92d535',
      'test/fixtures/v2/storage/security.json':
          '977d67f7aad3bb708b27b54f969c4af5a49323950ae93af0ff9d14a29d4f467b',
      'test/fixtures/v2/storage/shop.json':
          '759bf01a1403bed48cdbcdd8324f10eea13bfd96c0ceebe5dea7e5e34a078271',
      'test/fixtures/v5/storage/planner.json':
          '032c424c3e1e80d13e47caa00edf6f794a3bdbfa11dbad352f42ce417d79ed6b',
      'test/fixtures/v5/storage/routines.json':
          '9d4ea183f1974569b55854aec71011324efd98f3d0c154fcf31450de647b99cc',
      'test/fixtures/v5/backup-plain.json':
          '334cd0ea01e4a29a0c53eb7fd2c1f32944a085ff3f51c0156da2b2f4eb3c2d2b',
      'test/fixtures/v6/storage/pins.json':
          'a4462a5a94d563eccfb85a17d059949d61b8c94343ae37eb804d42f381c0258f',
      'test/fixtures/v6/backup-plain.json':
          'fb141bdd6b34ef8791a9ed76d42cd85335f95fe37a94a900716af07d8a569627',
      'test/fixtures/v7/storage/planner.json':
          'c8f94175dc1691f1f6481559b8ecadd8afb5dc830951cede751b37309ddf15de',
      'test/fixtures/v7/storage/routines.json':
          '369f0338c403827369a6ab1d18eb2c023d0cebb3cbe73a2be4aa435e64ef4d4e',
      'test/fixtures/v7/backup-plain.json':
          '41628bbf3f82d529236ff34fa2886191bb92a3ac8902334a15c92586c4889052',
      'test/fixtures/v8/storage/shop.json':
          '833cc85385498b4ee601e343f9b7a04aefec2a30c6e3d680997ee86f6754d2a4',
      'test/fixtures/v8/backup-plain.json':
          '70a4f3dc35e9ef3a315b3a6c7d195b6aa3eb1183e51db186f765b3c420860742',
      'test/fixtures/v9/storage/placard.json':
          '110be31666a8ed658f5f7a38a3a6229b263dfd2f80f5f6c38d001ce2740b7e0b',
      'test/fixtures/v9/backup-plain.json':
          'bbd720bb1a8a58ab221289e9a894019a3f52e20282a078907a752f83bdf7432f',
      'test/fixtures/v10/storage/counters.json':
          '781da94fbe27d818356cd2f787e0ab094c2e6098565261b24d74eb7e559551dd',
      'test/fixtures/v10/backup-plain.json':
          '97bd4e11044a5f26bff2521c246ac49b87da5ec1f76d5e7514bb7116f12f873d',
      'test/fixtures/v11/storage/medicine.json':
          'f0a34c25e1e843a90eca8b6f3b3573413d4850552471a44e27b55f17d6d40ce2',
      'test/fixtures/v11/backup-plain.json':
          '957ea75a7409465f13e48a2a20db9929fb8c05b72eceb6c838904e66db9ff4a9',
      'test/fixtures/v12/storage/medicine.json':
          '82811a307c040ee98ae347c8793c3aa2cf1656a5e7201abea59f5119d87b2c30',
      'test/fixtures/v12/backup-plain.json':
          '2ba01bb04b33e1a5c16a76224d7339a44e5c9f8b5f8124716de10c7d9ef52e75',
      'test/fixtures/v13/storage/medicine.json':
          '42e2e740aa34861e8564a1eb1552ffcc4ab18fe2f826fdf9ce8e5d10257dbe5a',
      'test/fixtures/v13/backup-plain.json':
          '56b1a7cd9dc07d1e48fa76fc906ea9b94c3f0a8332acb3b35e2fb6c40d25174e',
      'test/fixtures/v14/storage/medicine.json':
          '363069098653b44771ddd73f008f6522b53b5663ac21065869fe85416e5b1e8c',
      'test/fixtures/v14/backup-plain.json':
          '8ab0ceded332cfb23f5dc0694161259b46527fd943c5748127099bb7e37b8dac',
      'test/fixtures/v15/storage/todo.json':
          '08cbf1c49b60b341d5c9c55756a77f63340a649b1e8b89222dc5876d96953a7b',
      'test/fixtures/v15/backup-plain.json':
          '7b152eb6450c34821620cf5fc0518aba22231334aa423f298e734a65c6720965',
      'test/fixtures/v16/storage/todo.json':
          '49ac46bdc944294b55e21d4edec324a21e06441a74eba602a21084431219f873',
      'test/fixtures/v16/backup-plain.json':
          '7fe387a63e7fe6fcfec32b8529001e29e1bfece45683b49be9b3bd19b7d97bef',
      'test/fixtures/v16/storage/notifications.json':
          '1157e0d44eaaa195391bd23e526b6ee8df8372925bbbf127e8a7228063fbe565',
      'test/fixtures/v17/storage/pip.json':
          '42af9cbe1b6e4f6787bf7b551c2662e736698733ea8e4855a8479791bffc8524',
      'test/fixtures/v17/backup-plain.json':
          'b9bfd92486de0d507b725942431714bdd522a299bfa978514abb2106a44e79bf',
      'test/fixtures/v13/storage/settings.json':
          '1e242bfd16f75d65ac0703ef0d59a66ab08de645eb59e67e0fb378df5cf8b717',
      'test/fixtures/v8/storage/layout.json':
          'ea1852cc78ae61fb3570df641bd63de23c59f96b1d37f127c404b25466a551a6',
    };
    for (final MapEntry(key: path, value: hash) in expected.entries) {
      final digest = await Sha256().hash(File(path).readAsBytesSync());
      final hex =
          digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hex, hash, reason: '$path was changed');
    }
  });
}
