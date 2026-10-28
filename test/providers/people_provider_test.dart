import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/models/people_layout.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/people_provider.dart';
import 'package:the_app/providers/section_data_provider.dart';

import '../helpers.dart';

/// People (Round 108): kept as changed, birthdays in step with Dates,
/// relations' rules, Undo, Tidy, Clear data, backups.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(overrides: [
      appStorageProvider.overrideWithValue(AppStorage.inMemory()),
      appVersionProvider.overrideWithValue('1.43.0 (106)'),
      backupFilesProvider.overrideWithValue(FakeBackupFiles()),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 27, 12)),
    ]);
    addTearDown(container.dispose);
  });

  PeopleNotifier people() => container.read(peopleProvider.notifier);
  PeopleBook book() => container.read(peopleProvider);
  DateBook dates() => container.read(datesProvider);

  Person add(String name, {PersonDate? birthday, double x = 0, double y = 0}) {
    final p = people()
        .draft(x: x, y: y)
        .copyWith(name: name, birthday: () => birthday);
    people().save(p);
    return book().byId(p.id)!;
  }

  group('a birthday is on the Dates page too', () {
    test('made with them: their name, a birthday every year, theirs', () {
      final ana = add('Ana',
          birthday: const PersonDate(day: 24, month: 10, year: 1995));
      final date = dates().byId(ana.dateId!)!;
      expect(date.title, 'Ana');
      expect(date.type, DateType.birthday);
      expect(
          (date.day, date.month, date.year, date.yearly), (24, 10, 1995, true));
      expect(date.personId, ana.id);
      expect(date.reminders, isNotEmpty, reason: "a date's usual reminder");
    });

    test(
        'renamed or moved with them; its reminders and note stay its own; '
        'gone when their birthday goes', () {
      final ana = add('Ana', birthday: const PersonDate(day: 24, month: 10));
      final dateId = ana.dateId!;
      container.read(datesProvider.notifier).save(
          dates().byId(dateId)!.copyWith(note: 'Tulips', reminders: const []));
      people().save(ana.copyWith(
        name: 'Ana Petrović',
        birthday: () => const PersonDate(day: 25, month: 10, year: 1995),
      ));
      final date = dates().byId(dateId)!;
      expect((date.title, date.day, date.year), ('Ana Petrović', 25, 1995));
      expect(date.note, 'Tulips');
      expect(date.reminders, isEmpty);

      people().save(book().byId(ana.id)!.copyWith(birthday: () => null));
      expect(dates().byId(dateId), isNull);
      expect(book().byId(ana.id)!.dateId, isNull);
    });

    test('nobody without a birthday gets a date', () {
      final ivan = add('Ivan');
      expect(ivan.dateId, isNull);
      expect(dates().dates, isEmpty);
    });

    test(
        'a birthday from Dates (Round 113): its day copied; the original '
        'left as it was; their own date beside it', () {
      container.read(datesProvider.notifier).save(const DateEntry(
            id: 'd1',
            title: 'Ana 🎂',
            type: DateType.birthday,
            day: 24,
            month: 10,
            year: 1995,
          ));
      container.read(datesProvider.notifier).save(const DateEntry(
            id: 'd2',
            title: 'Exam',
            type: DateType.event,
            day: 1,
            month: 11,
          ));
      expect(people().freeBirthdays().map((d) => d.id), ['d1']);
      final ana = add('Ana Petrović');
      final taken = people().takeBirthday(ana, 'd1');
      expect(taken.birthday, const PersonDate(day: 24, month: 10, year: 1995));
      expect(taken.dateId, isNot('d1'));
      final own = dates().byId(taken.dateId!)!;
      expect((own.title, own.personId, own.day, own.month, own.year),
          ('Ana Petrović', ana.id, 24, 10, 1995));
      final original = dates().byId('d1')!;
      expect((original.title, original.personId), ('Ana 🎂', null));
      expect(dates().dates, hasLength(3));
    });

    test('taken again: their own date changed, not another made', () {
      final ana = add('Ana', birthday: const PersonDate(day: 1, month: 1));
      final own = ana.dateId!;
      container.read(datesProvider.notifier).save(const DateEntry(
          id: 'd1', title: 'Ana', type: DateType.birthday, day: 24, month: 10));
      final taken = people().takeBirthday(ana, 'd1');
      expect(taken.dateId, own);
      expect(dates().byId(own)!.day, 24);
      expect(dates().dates.map((d) => d.id).toSet(), {own, 'd1'});
    });

    test('not shown in Dates: no date there; shown again, a new one', () {
      final ana = add('Ana', birthday: const PersonDate(day: 1, month: 1));
      final own = ana.dateId!;
      people().save(people().byId(ana.id)!.copyWith(inDates: false));
      expect(people().byId(ana.id)!.dateId, isNull);
      expect(dates().byId(own), isNull);
      expect(people().byId(ana.id)!.birthday, isNotNull, reason: 'kept here');
      expect(Person.fromJson(people().byId(ana.id)!.toJson()).inDates, isFalse);
      people().save(people().byId(ana.id)!.copyWith(inDates: true));
      final again = people().byId(ana.id)!.dateId;
      expect(again, isNotNull);
      expect(dates().byId(again!)!.personId, ana.id);
    });
  });

  group('relations', () {
    test('related; what makes no sense refused with why', () {
      final a = add('A'), b = add('B'), c = add('C');
      expect(people().relate(RelationKind.parent, a.id, c.id), isNull);
      expect(people().relate(RelationKind.parent, b.id, c.id), isNull);
      expect(book().parentsOf(c.id), [a.id, b.id]);
      expect(people().relate(RelationKind.partner, a.id, c.id),
          'They are already related');
      expect(people().relate(RelationKind.parent, c.id, a.id),
          'They are already related');
      expect(book().relations, hasLength(2));
    });

    test('a former partner, an Other with its word (trimmed)', () {
      final a = add('A'), b = add('B'), c = add('C');
      people().relate(RelationKind.partner, a.id, b.id, former: true);
      people().relate(RelationKind.other, a.id, c.id, label: ' Kum ');
      expect(book().relations[0].former, isTrue);
      expect(book().relations[1].label, 'Kum');
      // "former" only for partners, a word only for others.
      people().relate(RelationKind.sibling, b.id, c.id, label: 'x');
      expect(book().relations[2].label, '');
    });

    test('someone far away comes next to the one they are related to', () {
      final mum = add('Mum', x: 0, y: 0);
      final son = add('Son', x: 5000, y: 3000);
      final near = add('Near', x: 160, y: 0);
      people().relate(RelationKind.parent, mum.id, son.id);
      final moved = book().byId(son.id)!;
      expect((moved.x, moved.y), (0.0, BoardSizes.rowStep), reason: 'under');
      people().relate(RelationKind.partner, mum.id, near.id);
      expect(book().byId(near.id)!.x, 160, reason: 'near enough: stays');
      expect((book().byId(mum.id)!.x, book().byId(mum.id)!.y), (0.0, 0.0));
    });

    test('a parent far away comes over the child', () {
      final kid = add('Kid', x: 0, y: 1000);
      final dad = add('Dad', x: -4000, y: 0);
      people().relate(RelationKind.parent, dad.id, kid.id, bring: dad.id);
      final moved = book().byId(dad.id)!;
      expect((moved.x, moved.y), (0.0, 1000 - BoardSizes.rowStep));
    });

    test(
        "Round 114: a parent's child's brothers and sisters are their "
        'children too; only where it makes sense; said', () {
      final mum = add('Mum'), dad = add('Dad'), step = add('Step');
      final a = add('A'), b = add('B'), c = add('C');
      expect(people().relate(RelationKind.parent, mum.id, a.id), isNull);
      expect(people().relate(RelationKind.sibling, a.id, b.id), isNull);
      expect(book().parentsOf(b.id), [mum.id], reason: 'shares her');
      expect(people().lastAlso, [mum.id]);
      expect(people().relate(RelationKind.parent, mum.id, c.id), isNull);
      expect(book().childrenOf(mum.id).toSet(), {a.id, b.id, c.id});

      // Dad for A: B (a sibling) and C (by Mum) too.
      expect(people().relate(RelationKind.parent, dad.id, a.id), isNull);
      expect(people().lastAlso.toSet(), {b.id, c.id});
      expect(book().parentsOf(c.id).toSet(), {mum.id, dad.id});

      // A brother added from his side: he gets A's parents.
      final d = add('D');
      expect(people().relate(RelationKind.sibling, d.id, a.id), isNull);
      expect(book().parentsOf(d.id).toSet(), {mum.id, dad.id});

      // Two parents each now: a third is refused.
      expect(people().relate(RelationKind.parent, step.id, a.id),
          'They already have two parents');
      expect(people().lastAlso, isEmpty);
    });

    test('a child made with their own parent: no one is their own parent', () {
      final p = add('P'), k = add('K');
      people().relate(RelationKind.parent, p.id, k.id);
      people().relate(RelationKind.sibling, k.id, p.id);
      expect(book().parentsOf(p.id), isEmpty);
    });

    test('a relation removed', () {
      final a = add('A'), b = add('B');
      people().relate(RelationKind.partner, a.id, b.id);
      people().unrelate(book().relations.single.id);
      expect(book().relations, isEmpty);
    });
  });

  test(
      'deleted: their relations and their birthday go; Undo brings all '
      'back', () {
    final a = add('A', birthday: const PersonDate(day: 2, month: 3));
    final b = add('B');
    people().relate(RelationKind.partner, a.id, b.id);
    final removed = people().remove(a.id);
    expect(book().people.map((p) => p.name), ['B']);
    expect(book().relations, isEmpty);
    expect(dates().dates, isEmpty);
    people().undoRemove(removed);
    expect(book().people.map((p) => p.name), ['A', 'B']);
    expect(book().relations, hasLength(1));
    expect(dates().byId(a.dateId!)!.personId, a.id);
  });

  test('moved; the view kept; Tidy, and back', () {
    final a = add('A', x: 999, y: 999), b = add('B', x: 1100, y: 1000);
    people().relate(RelationKind.partner, a.id, b.id);
    people().move({a.id: (1.0, 2.0)});
    expect((book().byId(a.id)!.x, book().byId(a.id)!.y), (1.0, 2.0));
    people().setView(const BoardView(x: 5, y: 6, zoom: 0.5));
    expect(book().view.zoom, 0.5);
    final before = people().tidy();
    final at = tidyLayout(book());
    expect((book().byId(b.id)!.x, book().byId(b.id)!.y), at[b.id]);
    people().move(before);
    expect((book().byId(a.id)!.x, book().byId(a.id)!.y), (1.0, 2.0));
    expect((book().byId(b.id)!.x, book().byId(b.id)!.y), (1100.0, 1000.0));
  });

  test('Clear data: everyone, and their birthdays in Dates (only those)', () {
    add('A', birthday: const PersonDate(day: 2, month: 3));
    container.read(datesProvider.notifier).save(const DateEntry(
        id: 'd9', title: 'Exam', type: DateType.event, day: 1, month: 2));
    final data = container.read(sectionDataProvider);
    expect(data.countOf(HubTool.people), 1);
    expect(HubTool.people.clearable, isTrue);
    expect(HubTool.people.lockable, isTrue);
    data.clearOf(HubTool.people);
    expect(book().people, isEmpty);
    expect(dates().dates.map((d) => d.id), ['d9']);
  });

  group('backups', () {
    BackupImporter importer() => container.read(backupImporterProvider);
    RestorableBackup open(Backup backup) =>
        (importer().read(Uint8List.fromList(utf8.encode(backup.encode())))
                as PlainPick)
            .backup;

    Backup snapshot() => container.read(backupExporterProvider).snapshot();

    test('in a backup and back; one from before them leaves them be', () async {
      final a = add('A', birthday: const PersonDate(day: 2, month: 3));
      final b = add('B');
      people().relate(RelationKind.partner, a.id, b.id);
      final saved = snapshot();
      expect(saved.people!.people, hasLength(2));
      people().remove(a.id);
      await importer().restore(open(saved));
      expect(book().people.map((p) => p.name), ['A', 'B']);
      expect(book().relations, hasLength(1));
      expect(dates().byId(a.dateId!)!.personId, a.id);

      final before = Backup(
        createdAt: DateTime(2026, 10, 1),
        appVersion: '1.40.0 (100)',
        notes: const [],
        shopItems: const [],
      );
      expect(before.people, isNull);
      await importer().restore(open(before));
      expect(book().people, hasLength(2), reason: 'left as they are');
    });

    test(
        'part of one: the people picked, the relations between them, their '
        'birthdays made again; someone still here left as is', () async {
      final a = add('A', birthday: const PersonDate(day: 2, month: 3));
      final b = add('B');
      final c = add('C');
      people().relate(RelationKind.partner, a.id, b.id);
      people().relate(RelationKind.parent, a.id, c.id);
      final saved = snapshot();
      people().remove(a.id);
      people().remove(b.id);
      expect(dates().dates, isEmpty);

      final done = await importer().restorePart(open(saved), {
        BackupPart.people: {a.id, b.id, c.id},
      });
      expect(done!.added, 2);
      expect(done.skipped, 1, reason: 'C is still here');
      expect(book().people.map((p) => p.name), ['C', 'A', 'B']);
      expect(book().relations, hasLength(2));
      final back = book().byId(a.id)!;
      expect(dates().byId(back.dateId!)!.personId, a.id);
      expect(dates().dates, hasLength(1));
    });
  });
}
