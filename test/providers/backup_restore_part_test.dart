import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/counter.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/providers/todo_provider.dart';

import '../helpers.dart';

/// Restoring part of a backup (Round 28): only what's picked, added to
/// what's in the app.
void main() {
  late ProviderContainer container;
  late FakeBackupFiles files;

  setUp(() {
    files = FakeBackupFiles();
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory()),
        appVersionProvider.overrideWithValue('1.3.0 (34)'),
        backupFilesProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
  });

  BackupImporter importer() => container.read(backupImporterProvider);
  RestorableBackup open(Backup backup) =>
      (importer().read(Uint8List.fromList(utf8.encode(backup.encode())))
              as PlainPick)
          .backup;

  final day = DateTime(2026, 10, 14);
  Note note(String id, String title) => Note(
        id: id,
        title: title,
        content: '$title text',
        createdAt: DateTime(2026, 1, 1),
        modifiedAt: DateTime(2026, 1, 2),
      );

  final backup = Backup(
    createdAt: DateTime(2026, 10, 13, 9),
    appVersion: '1.2.1 (33)',
    notes: [note('n1', 'Wanted'), note('n2', 'Not wanted')],
    shopItems: const [
      ShopItem(id: 's1', name: 'Coffee'),
      ShopItem(id: 's2', name: 'Tea'),
    ],
    todo: const [TodoItem(id: 't1', text: 'Call mum')],
    plannerTasks: [
      PlannerTask(id: 'p1', title: 'Free slot', day: day, start: 600, end: 660),
      PlannerTask(id: 'p2', title: 'Clashes', day: day, start: 480, end: 540),
    ],
    routines: RoutineBook(
      routines: [
        Routine(
          id: 'r1',
          title: 'Walk',
          start: 1080,
          end: 1140,
          weekdays: {1, 2, 3, 4, 5},
          from: DateTime(2026, 10, 1),
        ),
      ],
      days: {
        RoutineDay.keyFor('r1', DateTime(2026, 10, 12)): RoutineDay(
            routineId: 'r1', day: DateTime(2026, 10, 12), done: true),
      },
    ),
    plannerPins: [PlannerPin(id: 'q1', title: 'Bins', day: day, time: 1200)],
    counters: const [Counter(id: 'c1', name: 'Push-ups', value: 40)],
    medicine: MedicineBook(
      medicines: [
        Medicine(id: 'm1', name: 'Iron', times: const [480], from: day),
      ],
      taken: [DoseTaken(medicine: 'm1', day: day, dose: 0)],
    ),
  );

  test('only what was picked comes back, next to what is there', () async {
    container.read(notesProvider.notifier).addNote(title: 'Current');
    container.read(shopProvider.notifier).addItem('Milk');
    final done = await importer().restorePart(open(backup), {
      BackupPart.notes: {'n1'},
      BackupPart.shop: {'s2'},
      BackupPart.todo: {'t1'},
      BackupPart.reminders: {'q1'},
      BackupPart.counters: {'c1'},
    });

    expect(container.read(notesProvider).map((n) => n.title),
        ['Wanted', 'Current'],
        reason: 'restored ones on top; the rest stays');
    expect(container.read(shopProvider).map((i) => i.name), ['Milk', 'Tea']);
    expect(container.read(todoProvider).map((i) => i.text), ['Call mum']);
    expect(container.read(pinsProvider).single.title, 'Bins');
    expect(container.read(countersProvider).single.value, 40);
    expect(container.read(plannerProvider), isEmpty, reason: 'not picked');
    expect(container.read(medicineProvider).medicines, isEmpty);
    expect((done!.added, done.copies, done.skipped), (5, 0, 0));
  });

  test('one still in the app comes back as a copy beside it', () async {
    container.read(notesProvider.notifier).replaceAll([
      note('n1', 'Wanted').copyWith(title: 'Wanted, edited since'),
    ]);
    container
        .read(shopProvider.notifier)
        .replaceAll(const [ShopItem(id: 's1', name: 'Coffee')]);
    final done = await importer().restorePart(open(backup), {
      BackupPart.notes: {'n1'},
      BackupPart.shop: {'s1'},
    });

    final notes = container.read(notesProvider);
    expect(notes.map((n) => n.title), ['Wanted', 'Wanted, edited since']);
    expect(notes.map((n) => n.id).toSet(), hasLength(2), reason: 'new id');
    expect(notes.first.content, 'Wanted text');
    final shop = container.read(shopProvider);
    expect(shop.map((i) => i.name), ['Coffee', 'Coffee']);
    expect(shop.map((i) => i.id).toSet(), hasLength(2));
    expect((done!.added, done.copies), (2, 2));
  });

  test('planner tasks whose time is taken, or still there, are left out',
      () async {
    container
        .read(plannerProvider.notifier)
        .addTask(day, 'Meeting', start: 450, end: 510);
    final done = await importer().restorePart(open(backup), {
      BackupPart.tasks: {'p1', 'p2'},
    });
    expect(container.read(plannerProvider).map((t) => t.title),
        ['Meeting', 'Free slot']);
    expect((done!.added, done.skipped), (1, 1));

    // Again: Free slot is there now.
    final again = await importer().restorePart(open(backup), {
      BackupPart.tasks: {'p1'},
    });
    expect(container.read(plannerProvider), hasLength(2));
    expect((again!.added, again.skipped), (0, 1));
  });

  test('a routine comes with its ticks; one that clashes is left out',
      () async {
    final done = await importer().restorePart(open(backup), {
      BackupPart.routines: {'r1'},
    });
    final book = container.read(routinesProvider);
    expect(book.routines.single.title, 'Walk');
    expect(book.dayOf('r1', DateTime(2026, 10, 12))!.done, isTrue);
    expect(done!.added, 1);

    container.read(routinesProvider.notifier).remove('r1');
    container.read(routinesProvider.notifier).add(
          title: 'Gym',
          start: 1100,
          end: 1200,
          weekdays: {1},
          from: DateTime(2026, 10, 1),
        );
    final clash = await importer().restorePart(open(backup), {
      BackupPart.routines: {'r1'},
    });
    expect(
        container.read(routinesProvider).routines.map((r) => r.title), ['Gym']);
    expect(clash!.skipped, 1);
  });

  test('a medicine comes with its history, as a copy if still there', () async {
    await importer().restorePart(open(backup), {
      BackupPart.medicines: {'m1'},
    });
    var book = container.read(medicineProvider);
    expect(book.medicines.single.name, 'Iron');
    expect(book.takenFor('m1', day, 0), isNotNull);

    await importer().restorePart(open(backup), {
      BackupPart.medicines: {'m1'},
    });
    book = container.read(medicineProvider);
    expect(book.medicines, hasLength(2));
    final copy = book.medicines.last;
    expect(copy.id, isNot('m1'));
    expect(book.takenFor(copy.id, day, 0), isNotNull, reason: 'its own');
    expect(book.taken, hasLength(2));
  });

  test('Undo puts everything back as it was', () async {
    container.read(notesProvider.notifier).addNote(title: 'Current');
    final done = await importer().restorePart(open(backup), {
      BackupPart.notes: {'n1', 'n2'},
      BackupPart.todo: {'t1'},
    });
    await importer().undo(done!.undo);
    expect(container.read(notesProvider).map((n) => n.title), ['Current']);
    expect(container.read(todoProvider), isEmpty);
  });

  group('locked notes', () {
    const password = 'master password';

    Future<Backup> withLockedNote() async {
      await container.read(securityProvider.notifier).setPassword(password);
      await container.read(sessionProvider.notifier).unlock(password);
      final notes = container.read(notesProvider.notifier);
      final id = notes.addNote(title: 'Bank', content: 'PIN 4711');
      await notes.lockNote(id, container.read(sessionProvider)!.dataKey);
      return container.read(backupExporterProvider).snapshot();
    }

    test('come back locked, and open; a copy is sealed for its new id',
        () async {
      final snapshot = await withLockedNote();
      final key = container.read(sessionProvider)!.dataKey;
      final bank = snapshot.notes.single;

      // Still there: a copy, sealed again (a note's seal names its id).
      await importer().restorePart(open(snapshot), {
        BackupPart.notes: {bank.id},
      });
      final notes = container.read(notesProvider);
      expect(notes, hasLength(2));
      expect(notes.every((n) => n.isLocked), isTrue);
      for (final n in notes) {
        expect(await NotesNotifier.openContent(n, key), 'PIN 4711');
      }

      // Gone from the app: back as it was.
      container.read(notesProvider.notifier).replaceAll(const []);
      await importer().restorePart(open(snapshot), {
        BackupPart.notes: {bank.id},
      });
      final back = container.read(notesProvider).single;
      expect(back.id, bank.id);
      expect(await NotesNotifier.openContent(back, key), 'PIN 4711');
    });
  });
}
