import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/models/people_layout.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/people_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/people_avatar.dart';

import '../helpers.dart';

/// The People page (Round 108, spec `docs/PEOPLE_SPEC.md`).
void main() {
  late ProviderContainer container;
  final now = DateTime(2026, 10, 27, 12);

  PeopleBook book() => container.read(peopleProvider);
  Person byName(String name) => book().people.firstWhere((p) => p.name == name);

  // Marko and Jelena, partners, Ana their daughter; Ivan on his own.
  final family = PeopleBook(
    people: const [
      Person(
          id: 'm',
          name: 'Marko',
          birthday: PersonDate(day: 12, month: 3, year: 1958),
          highlighted: true),
      Person(
          id: 'j',
          name: 'Jelena',
          gender: Gender.female,
          birthday: PersonDate(day: 3, month: 7, year: 1961),
          x: 160),
      Person(
          id: 'a',
          name: 'Ana',
          gender: Gender.female,
          birthday: PersonDate(day: 24, month: 10, year: 1995),
          x: 80,
          y: 260),
      Person(id: 'i', name: 'Ivan', x: 320, y: 0),
    ],
    relations: const [
      Relation(id: 'r1', kind: RelationKind.partner, from: 'm', to: 'j'),
      Relation(id: 'r2', kind: RelationKind.parent, from: 'm', to: 'a'),
      Relation(id: 'r3', kind: RelationKind.parent, from: 'j', to: 'a'),
    ],
    view: const BoardView(x: 80, y: 130),
  );

  Future<void> openPeople(WidgetTester tester,
      {PeopleBook? people, List<DateEntry> dates = const []}) async {
    container = await pumpApp(tester, clock: () => now, people: people);
    if (dates.isNotEmpty) {
      container.read(datesProvider.notifier).replaceAll(DateBook(dates));
    }
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('People'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    // The edit form scrolls: rows further down aren't built till then.
    final form = find.byKey(const Key('personForm'));
    if (find.byKey(Key(key)).evaluate().isEmpty && form.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(find.byKey(Key(key)), 80,
          scrollable: find
              .descendant(of: form, matching: find.byType(Scrollable))
              .first);
    }
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'empty: says so; only Add; a new person named, kept, on the board, '
      'their info after Done', (tester) async {
    await openPeople(tester);
    expect(find.byKey(const Key('peopleEmpty')), findsOneWidget);
    expect(find.text('0 people'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('peopleOptions')))
            .onPressed,
        isNull);

    await tapKey(tester, 'peopleAdd');
    expect(find.text('New person'), findsOneWidget);
    expect(book().people, isEmpty, reason: 'not kept without a name');
    await tester.enterText(find.byKey(const Key('personName')), 'Ana P');
    await tester.pumpAndSettle();
    expect(byName('Ana P').gender, Gender.male);
    await tapKey(tester, 'personGender');
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    expect(byName('Ana P').gender, Gender.female);
    expect(find.byKey(Key('person-${byName('Ana P').id}')), findsOneWidget);
    expect(find.text('Edit person'), findsOneWidget, reason: 'kept now');

    await tapKey(tester, 'personDone');
    expect(find.byKey(const Key('personInfo')), findsOneWidget);
    expect(find.byKey(const Key('personPanelTitle')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('personPanelTitle'))).data,
        'Ana P');
    await tapKey(tester, 'personClose');
    expect(find.text('1 person'), findsOneWidget);
  });

  testWidgets('a new person left without a name: nothing kept', (tester) async {
    await openPeople(tester);
    await tapKey(tester, 'peopleAdd');
    // Changed, but no name: still not kept.
    await tapKey(tester, 'personGender');
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    expect(book().people, isEmpty);
    await tapKey(tester, 'personDone');
    expect(book().people, isEmpty);
    expect(find.byKey(const Key('peopleAdd')), findsOneWidget);
  });

  testWidgets(
      'a tap selects and centres on them: their info, their relations (a '
      'tap on one goes there); the empty board deselects', (tester) async {
    await openPeople(tester, people: family);
    await tester.tap(find.byKey(const Key('person-a')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('personPanelTitle'))).data,
        'Ana');
    expect(find.text('Born 24 October 1995 · 31'), findsOneWidget);
    expect(find.text('Father'), findsOneWidget);
    expect(find.text('Mother'), findsOneWidget);
    // Centred: her box in the middle of the board.
    final board = tester.getRect(find.byKey(const Key('peopleBoard')));
    final box = tester.getRect(find.byKey(const Key('person-a')));
    expect((box.center - board.center).distance, lessThan(2));
    expect(book().view.x, 80, reason: 'the view kept');
    expect(book().view.y, 260);

    await tapKey(tester, 'relation-m');
    expect(tester.widget<Text>(find.byKey(const Key('personPanelTitle'))).data,
        'Marko');
    expect(find.text('Daughter'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);

    // The board above the panel, away from anyone.
    await tester.tapAt(board.topLeft + const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('peopleAdd')), findsOneWidget);
  });

  testWidgets(
      'a small drag moves only them; far, the family follows (the partner '
      'all the way); others never', (tester) async {
    await openPeople(tester, people: family);
    Offset at(String id) => Offset(byName(id).x, byName(id).y);
    final ivan = at('Ivan'), jelena = at('Jelena'), ana = at('Ana');

    await tester.drag(find.byKey(const Key('person-m')), const Offset(40, 0),
        touchSlopX: 0);
    await tester.pumpAndSettle();
    expect(at('Marko').dx, closeTo(40, 1));
    expect((at('Jelena') - jelena).distance, lessThan(5),
        reason: 'a small drag: barely'); // a partner follows soonest
    expect(at('Ana'), ana);

    await tester.drag(find.byKey(const Key('person-m')), const Offset(0, 500),
        touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(at('Marko').dy, closeTo(500, 1));
    expect(at('Jelena').dy, closeTo(jelena.dy + 500, 1),
        reason: 'his partner, all the way');
    expect(at('Ana').dy, greaterThan(ana.dy + 100),
        reason: 'his daughter follows');
    expect(at('Ivan'), ivan, reason: 'not family');
  });

  testWidgets('dragging the empty board pans it; the view is kept',
      (tester) async {
    await openPeople(tester, people: family);
    final before = tester.getRect(find.byKey(const Key('person-i'))).center;
    final board = tester.getRect(find.byKey(const Key('peopleBoard')));
    await tester.dragFrom(
        board.bottomRight - const Offset(90, 20), const Offset(-100, -50));
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byKey(const Key('person-i'))).center;
    expect(after.dx, closeTo(before.dx - 100, 25));
    expect(book().view.x, greaterThan(80));
    expect(byName('Ivan').x, 320, reason: 'nobody moved');
  });

  testWidgets(
      'edit: relations added (the picked one brought near), refused with '
      'why; removed', (tester) async {
    await openPeople(tester, people: family);
    await tester.tap(find.byKey(const Key('person-i')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'personEdit');
    await tapKey(tester, 'addRelation');
    await tapKey(tester, 'pickPerson-a');
    await tester.tap(find.text('Partner'));
    await tester.pumpAndSettle();
    final r = book().relations.last;
    expect((r.kind, r.from, r.to), (RelationKind.partner, 'i', 'a'));

    await tapKey(tester, 'addRelation');
    expect(find.byKey(const Key('pickPerson-a')), findsNothing,
        reason: 'related already: not offered');
    await tapKey(tester, 'pickPerson-m');
    await tester.tap(find.text('Other…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Kum');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(book().relations.last.label, 'Kum');
    expect(find.text('Kum'), findsWidgets);

    await tester.tap(find.byTooltip('Remove relation').last);
    await tester.pumpAndSettle();
    expect(book().relations.any((r) => r.label == 'Kum'), isFalse);
  });

  testWidgets('a third parent is refused, with why', (tester) async {
    await openPeople(tester, people: family);
    await tester.tap(find.byKey(const Key('person-a')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'personEdit');
    await tapKey(tester, 'addRelation');
    await tapKey(tester, 'pickPerson-i');
    await tester.tap(find.text('Their parent'));
    await tester.pumpAndSettle();
    expect(find.text('They already have two parents'), findsOneWidget);
    expect(book().relations, hasLength(3));
  });

  testWidgets(
      'highlighted and deceased shown on the board; the age stops at '
      'death', (tester) async {
    await openPeople(tester, people: family);
    await tester.tap(find.byKey(const Key('person-j')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'personEdit');
    await tapKey(tester, 'personDeceased');
    expect(byName('Jelena').deceased, isTrue);
    expect(find.text('† Jelena'), findsOneWidget);
    expect(find.byKey(const Key('personDiedOn')), findsOneWidget);
    await tapKey(tester, 'personHighlighted');
    expect(byName('Jelena').highlighted, isTrue);
  });

  testWidgets(
      'a birthday from Dates: taken over, renamed, no longer offered; '
      "there, it's locked and can't be deleted", (tester) async {
    await openPeople(tester, people: family, dates: const [
      DateEntry(
        id: 'd1',
        title: 'Ivan 🎂',
        type: DateType.birthday,
        day: 9,
        month: 4,
        year: 1990,
      ),
      DateEntry(
          id: 'd2', title: 'Exam', type: DateType.event, day: 1, month: 11),
    ]);
    await tester.tap(find.byKey(const Key('person-i')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'personEdit');
    await tapKey(tester, 'birthdayFromDates');
    expect(find.byKey(const Key('freeBirthday-d2')), findsNothing,
        reason: 'birthdays only');
    await tapKey(tester, 'freeBirthday-d1');
    expect(byName('Ivan').birthday,
        const PersonDate(day: 9, month: 4, year: 1990));
    final date = container.read(datesProvider).byId('d1')!;
    expect((date.title, date.personId), ('Ivan', 'i'));
    expect(find.byKey(const Key('birthdayFromDates')), findsNothing);

    // The year let go.
    await tapKey(tester, 'personYearKnown');
    expect(byName('Ivan').birthday!.year, isNull);
    expect(container.read(datesProvider).byId('d1')!.year, isNull);

    // In Dates: the People mark, the fields locked, no Delete.
    await tapKey(tester, 'personDone');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dates'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('datePerson-d1')), findsOneWidget);
    expect(find.byKey(const Key('datePerson-d2')), findsNothing);
    await tester.tap(find.text('Ivan'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('dateTitle'))).enabled,
        isFalse);
    expect(find.text('From People: edit it there'), findsOneWidget);
    expect(find.byKey(const Key('dateType-birthday')), findsNothing);
    expect(
        tester.widget<ActionChip>(find.byKey(const Key('dateDay'))).onPressed,
        isNull);
    expect(find.byKey(const Key('deleteDate')), findsNothing);
    // Round 109: its year known is People's too.
    expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('dateYearKnown')))
            .onChanged,
        isNull);
  });

  testWidgets(
      'Tidy, from the options, asks first and moves everyone; no toast '
      'after', (tester) async {
    await openPeople(tester, people: family);
    await tapKey(tester, 'peopleOptions');
    await tapKey(tester, 'choice-tidy');
    expect(find.textContaining('your own placing is lost'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(byName('Ivan').x, 320);

    await tapKey(tester, 'peopleOptions');
    await tapKey(tester, 'choice-tidy');
    await tester.tap(find.text('Tidy'));
    await tester.pumpAndSettle();
    final at = tidyLayout(family);
    expect((byName('Ivan').x, byName('Ivan').y), at['i']);
    expect((byName('Ana').x, byName('Ana').y), at['a']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Find: a name searched, picked, selected', (tester) async {
    await openPeople(tester, people: family);
    await tapKey(tester, 'peopleFind');
    await tester.enterText(find.byKey(const Key('pickPersonSearch')), 'iv');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pickPerson-m')), findsNothing);
    await tapKey(tester, 'pickPerson-i');
    expect(tester.widget<Text>(find.byKey(const Key('personPanelTitle'))).data,
        'Ivan');
  });

  testWidgets('deleted, asked first; no Undo toast after', (tester) async {
    await openPeople(tester, people: family);
    await tester.tap(find.byKey(const Key('person-a')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'personEdit');
    await tapKey(tester, 'deletePerson');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(book().byId('a'), isNull);
    expect(book().relations, hasLength(1));
    expect(find.byKey(const Key('peopleAdd')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  group('Round 109', () {
    Future<void> select(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(Key('person-$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('highlighted: the same size as anyone', (tester) async {
      await openPeople(tester, people: family);
      expect(tester.getSize(find.byKey(const Key('person-m'))),
          tester.getSize(find.byKey(const Key('person-i'))));
    });

    testWidgets(
        'a pinch, one finger lifted, the other moved on: no jump, and '
        'nobody grabbed', (tester) async {
      await openPeople(tester, people: family);
      final board = tester.getRect(find.byKey(const Key('peopleBoard')));
      final marko = tester.getRect(find.byKey(const Key('person-m'))).center;
      // One finger on the empty board, the other on Marko.
      final a =
          await tester.startGesture(board.bottomRight - const Offset(30, 30));
      final b = await tester.startGesture(marko, pointer: 2);
      await tester.pump();
      await a.moveBy(const Offset(20, 0));
      await b.moveBy(const Offset(-20, 0));
      await tester.pump();
      await b.up();
      await tester.pump();
      final before = tester.getRect(find.byKey(const Key('person-i'))).center;
      await a.moveBy(const Offset(0, 4));
      await tester.pump();
      await a.moveBy(const Offset(0, 4));
      await tester.pump();
      final after = tester.getRect(find.byKey(const Key('person-i'))).center;
      expect((after - before).distance, lessThan(20),
          reason: 'pans from where the finger is');
      await a.up();
      await tester.pumpAndSettle();
      expect((byName('Marko').x, byName('Marko').y), (0.0, 0.0),
          reason: 'not dragged');
    });

    testWidgets(
        'the main person: set in Edit, starred; the options center on them '
        'and highlight their family', (tester) async {
      await openPeople(tester, people: family);
      await tapKey(tester, 'peopleOptions');
      await tapKey(tester, 'choice-main');
      expect(find.text('No main person yet: set one in Edit'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await select(tester, 'a');
      await tapKey(tester, 'personEdit');
      await tapKey(tester, 'personMain');
      expect(book().mainId, 'a');
      await tapKey(tester, 'personDone');
      expect(find.byKey(const Key('mainStar')), findsOneWidget);
      // Round 111: on the box's corner, not the face's.
      final star = tester.getRect(find.byKey(const Key('mainStar')));
      final mainBox = tester.getRect(find.byKey(const Key('person-a')));
      expect(star.center.dx, greaterThan(mainBox.right - 12));
      expect(star.center.dy, lessThan(mainBox.top + 12));
      await tapKey(tester, 'personClose');

      await tapKey(tester, 'peopleOptions');
      await tapKey(tester, 'choice-family');
      expect(book().highlightFamily, isTrue);
      expect(book().familyShown, {'m', 'j', 'a'});
      await tapKey(tester, 'peopleOptions');
      expect(find.text('Stop highlighting family'), findsOneWidget);
      await tapKey(tester, 'choice-main');
      final board = tester.getRect(find.byKey(const Key('peopleBoard')));
      final box = tester.getRect(find.byKey(const Key('person-a')));
      expect((box.center - board.center).distance, lessThan(2));
    });

    testWidgets(
        'edit: back asks; Discard puts it all back (birthday and its date '
        'too); Done asks nothing', (tester) async {
      await openPeople(tester, people: family);
      await select(tester, 'm');
      await tapKey(tester, 'personEdit');
      await tester.enterText(find.byKey(const Key('personName')), 'Mark');
      await tester.pumpAndSettle();
      await tapKey(tester, 'personBirthday');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final dateId = byName('Mark').dateId!;
      expect(container.read(datesProvider).byId(dateId), isNotNull);

      // Out of the name field first, then asked.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Save changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(book().byId('m')!.name, 'Marko');
      expect(book().byId('m')!.dateId, isNull);
      expect(container.read(datesProvider).byId(dateId), isNull);
      expect(find.byKey(const Key('personInfo')), findsOneWidget);

      await tapKey(tester, 'personEdit');
      await tester.enterText(find.byKey(const Key('personName')), 'Mark');
      await tester.pumpAndSettle();
      await tapKey(tester, 'personDone');
      expect(find.text('Save changes?'), findsNothing);
      expect(book().byId('m')!.name, 'Mark');
    });

    testWidgets('a new person discarded is gone', (tester) async {
      await openPeople(tester, people: family);
      await tapKey(tester, 'peopleAdd');
      await tester.enterText(find.byKey(const Key('personName')), 'Zoe');
      await tester.pumpAndSettle();
      expect(book().people, hasLength(5));
      await tapKey(tester, 'personDiscard');
      expect(book().people, hasLength(4));
      expect(find.byKey(const Key('peopleAdd')), findsOneWidget);
    });

    testWidgets(
        'a birthday removed only after asking, its date with it; one made '
        'here has the usual reminders', (tester) async {
      await openPeople(tester, people: family);
      await select(tester, 'i');
      await tapKey(tester, 'personEdit');
      await tapKey(tester, 'personBirthday');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final dateId = byName('Ivan').dateId!;
      expect(container.read(datesProvider).byId(dateId)!.reminders,
          DateReminder.defaults);

      await tapKey(tester, 'clearBirthday');
      expect(find.textContaining('Their birthday in Dates goes too'),
          findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(byName('Ivan').birthday, isNotNull);
      await tapKey(tester, 'clearBirthday');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(byName('Ivan').birthday, isNull);
      expect(container.read(datesProvider).byId(dateId), isNull);
    });

    testWidgets('the birthdays from Dates scroll', (tester) async {
      await openPeople(tester, people: family, dates: [
        for (var i = 0; i < 20; i++)
          DateEntry(
              id: 'b$i',
              title: 'Friend $i',
              type: DateType.birthday,
              day: 1 + i,
              month: 5),
      ]);
      await select(tester, 'i');
      await tapKey(tester, 'personEdit');
      await tapKey(tester, 'birthdayFromDates');
      final list = find.byKey(const Key('freeBirthdays'));
      await tester.scrollUntilVisible(
          find.byKey(const Key('freeBirthday-b19')), 80,
          scrollable:
              find.descendant(of: list, matching: find.byType(Scrollable)));
      await tester.ensureVisible(find.byKey(const Key('freeBirthday-b19')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('freeBirthday-b19')));
      await tester.pumpAndSettle();
      expect(byName('Ivan').birthday!.day, 20);
    });

    testWidgets(
        'the note: last, written on its own page (Markdown); Done keeps, '
        'back asks and Discard puts it back; hidden by the setting',
        (tester) async {
      await openPeople(tester, people: family);
      await select(tester, 'm');
      Future<void> toNote() =>
          tester.scrollUntilVisible(find.byKey(const Key('personInfoEnd')), 80,
              scrollable: find
                  .descendant(
                      of: find.byKey(const Key('personInfo')),
                      matching: find.byType(Scrollable))
                  .first);
      await toNote();
      expect(find.text('Nothing written yet'), findsOneWidget);
      await tapKey(tester, 'personNoteEdit');
      await tester.enterText(
          find.byKey(const Key('personNoteField')), '**Likes** fishing');
      await tester.pumpAndSettle();
      expect(book().byId('m')!.note, '**Likes** fishing');
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      await toNote();
      expect(find.byKey(const Key('personNote')), findsOneWidget);

      await tapKey(tester, 'personNoteEdit');
      await tester.enterText(find.byKey(const Key('personNoteField')), 'x');
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      if (find.text('Save changes?').evaluate().isEmpty) {
        await tester.pageBack(); // out of the field first
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(book().byId('m')!.note, '**Likes** fishing');

      container.read(preferencesProvider.notifier).setHidePeopleNotes(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('personNote')), findsNothing);
      expect(find.byKey(const Key('personNoteEdit')), findsNothing);
    });

    testWidgets('viewing, a swipe down on the name closes the panel',
        (tester) async {
      await openPeople(tester, people: family);
      await select(tester, 'i');
      await tester.drag(
          find.byKey(const Key('personPanelTitle')), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('peopleAdd')), findsOneWidget);
    });

    testWidgets('zoomed out: names larger, faces smaller; no overflow',
        (tester) async {
      await openPeople(tester,
          people: family.copyWith(
            people: [
              for (final p in family.people)
                p.id == 'i' ? p.copyWith(name: 'Ivan Aleksandar Petrovic') : p,
            ],
            view: const BoardView(x: 80, y: 130, zoom: 0.3),
          ));
      double nameSize() => tester
          .widget<Text>(find.descendant(
              of: find.byKey(const Key('person-i')),
              matching: find.text('Ivan Aleksandar Petrovic')))
          .style!
          .fontSize!;
      expect(nameSize(), greaterThan(19));
      expect(tester.takeException(), isNull);
      // Round 111: the face not dwarfed by the name (near its full 78
      // board units), a long name on one line.
      final box = tester.getRect(find.byKey(const Key('person-i')));
      final face = tester.getRect(find.descendant(
          of: find.byKey(const Key('person-i')),
          matching: find.byType(PeopleAvatar)));
      expect(face.width / box.width * BoardSizes.boxWidth, greaterThan(72));
    });

    testWidgets(
        'the zoom handle: pulled down zooms out, up zooms in; a tap goes '
        'back to 100%; the view kept', (tester) async {
      await openPeople(tester, people: family);
      final handle = find.byKey(const Key('peopleZoom'));
      await tester.drag(handle, const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(book().view.zoom, lessThan(0.5));
      await tester.drag(handle, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(book().view.zoom, greaterThan(1));
      await tester.tap(handle);
      await tester.pumpAndSettle();
      expect(book().view.zoom, 1);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets(
        'moved, they spring: a little past the spot, then back; squashed '
        'the way they go, round again once still', (tester) async {
      await openPeople(tester, people: family);
      Rect ivan() => tester.getRect(find.byKey(const Key('person-i')));
      final start = ivan().center.dx;
      container.read(peopleProvider.notifier).move({'i': (420, 0)});
      var furthest = start;
      var squashed = false;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        furthest = math.max(furthest, ivan().center.dx);
        final t = tester.widget<Transform>(find
            .descendant(
                of: find.byKey(const Key('person-i')),
                matching: find.byType(Transform))
            .first);
        if (t.transform != Matrix4.identity()) squashed = true;
      }
      await tester.pumpAndSettle();
      final end = ivan().center.dx;
      expect(end - start, closeTo(100, 1));
      expect(furthest, greaterThan(end + 3), reason: 'past it, then back');
      expect(squashed, isTrue);
      final t = tester.widget<Transform>(find
          .descendant(
              of: find.byKey(const Key('person-i')),
              matching: find.byType(Transform))
          .first);
      expect(t.transform, Matrix4.identity());
    });
  });
}
