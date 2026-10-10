// Every data format the app has ever written must stay readable, so an
// update can never lose a user's data. The files in test/fixtures/ are
// frozen copies of real output; see test/fixtures/README.md.
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/routine.dart';
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

    test('v4 backup restores timed tasks and the Džoni count', () {
      final file = BackupFile.parse(
        File('test/fixtures/v4/backup-plain.json').readAsStringSync(),
      ) as PlainBackupFile;
      expectTimed(file.backup.plannerTasks);
      expect(file.backup.dzoniCount, 7);
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

  test('backups from before the planner restore with no tasks', () {
    for (final path in [
      'test/fixtures/v1/backup-plain.json',
      'test/fixtures/v2/backup-plain.json',
    ]) {
      final file =
          BackupFile.parse(File(path).readAsStringSync()) as PlainBackupFile;
      expect(file.backup.plannerTasks, isEmpty, reason: path);
      expect(file.backup.counters, isEmpty, reason: path);
      expect(file.backup.dzoniCount, 0, reason: path);
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
    };
    for (final MapEntry(key: path, value: hash) in expected.entries) {
      final digest = await Sha256().hash(File(path).readAsBytesSync());
      final hex =
          digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hex, hash, reason: '$path was changed');
    }
  });
}
