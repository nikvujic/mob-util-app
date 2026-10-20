import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/providers/medicine_provider.dart';

import 'package:the_app/widgets/pull_down_list.dart';

import '../helpers.dart';

/// The medicine tracker (O6): one tap per dose, with the time; history.
void main() {
  late ProviderContainer container;
  late DateTime now;
  final today = DateTime(2026, 10, 12);

  MedicineNotifier medicine() => container.read(medicineProvider.notifier);
  String header(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('medicineToday'))).data!;

  Future<void> openMedicine(WidgetTester tester,
      [void Function()? seed]) async {
    now = DateTime(2026, 10, 12, 8, 3);
    container = await pumpApp(tester, clock: () => now);
    seed?.call();
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Medicine'));
    await tester.pumpAndSettle();
  }

  testWidgets('add one: once a day at 08:00 by default', (tester) async {
    await openMedicine(tester);
    expect(find.text('No medicines'), findsOneWidget);
    // The app's add button, like every page's (Round 39: it was grey).
    expect(
        tester
            .widget<FloatingActionButton>(find.ancestor(
                of: find.byTooltip('Add medicine'),
                matching: find.byType(FloatingActionButton)))
            .backgroundColor,
        isNull,
        reason: "the theme's add button colours");
    await tester.tap(find.byTooltip('Add medicine'));
    await tester.pumpAndSettle();
    final add = find.byKey(const Key('medicineSubmit'));
    expect(tester.widget<FilledButton>(add).onPressed, isNull,
        reason: 'no name yet');
    await tester.enterText(find.byKey(const Key('medicineName')), 'Vitamin D');
    await tester.pump();
    expect(find.text('Once a day, at'), findsOneWidget);
    await tester.tap(add);
    await tester.pumpAndSettle();

    final m = container.read(medicineProvider).medicines.single;
    expect((m.name, m.from, m.until), ('Vitamin D', today, null));
    expect(m.times, [480]);
    expect(header(tester), 'Today: 0 of 1 dose taken');
    expect(find.text('Tap when taken'), findsOneWidget);
  });

  testWidgets('one tap marks a dose taken, with the time', (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine().add('Vitamin D', times: [480], from: today)!;
    });
    await tester.tap(find.byKey(Key('dose-$id-0')));
    await tester.pumpAndSettle();
    expect(find.text('Taken 08:03'), findsOneWidget);
    expect(header(tester), 'Today: all taken');
    expect(container.read(medicineProvider).takenFor(id, today, 0)!.at,
        DateTime(2026, 10, 12, 8, 3));
  });

  testWidgets('a second tap unmarks it, after asking (Round 18)',
      (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine().add('Vitamin D', times: [480], from: today)!;
      medicine().toggleDose(id, today, 0);
    });
    await tester.tap(find.byKey(Key('dose-$id-0')));
    await tester.pumpAndSettle();
    expect(find.text('Mark as not taken?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).takenFor(id, today, 0), isNotNull,
        reason: 'a slip: kept');

    await tester.tap(find.byKey(Key('dose-$id-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not taken'));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).takenFor(id, today, 0), isNull);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('each card shows how many were taken in all (Round 18)',
      (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine()
          .add('Vitamin D', times: [480], from: DateTime(2026, 10, 1))!;
      medicine()
        ..setDose(id, DateTime(2026, 10, 1), 0, DoseState.taken)
        ..setDose(id, DateTime(2026, 10, 2), 0, DoseState.taken)
        ..setDose(id, DateTime(2026, 10, 3), 0, DoseState.missed);
    });
    final count = find.byKey(Key('medicineCount-$id'));
    expect(tester.widget<Text>(count).data, '2');
    // Level with the drag handle beside it (Round 20).
    expect(
        tester.getCenter(count).dy,
        moreOrLessEquals(tester.getCenter(find.byIcon(Icons.drag_handle)).dy,
            epsilon: 1));
    await tester.tap(find.byKey(Key('dose-$id-0')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(count).data, '3');
  });

  testWidgets('ticking plays the chime and buzzes; unticking doesn\'t',
      (tester) async {
    late String id;
    final calls = <String>[];
    await openMedicine(tester, () {
      id = medicine().add('Vitamin D', times: [480], from: today)!;
    });
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('the_app/sound'),
        (call) async {
      calls.add('sound:${call.method}');
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('buzz:${call.arguments}');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(
          const MethodChannel('the_app/sound'), null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.tap(find.byKey(Key('dose-$id-0')));
    await tester.pumpAndSettle();
    // Two pulses, like the gulp's two bloops (Round 17).
    expect(calls, [
      'buzz:HapticFeedbackType.mediumImpact',
      'sound:done',
      'buzz:HapticFeedbackType.lightImpact',
    ]);
    calls.clear();
    await tester.tap(find.byKey(Key('dose-$id-0')));
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('sound:done')));
  });

  testWidgets('several a day: each dose, "1 of 2"', (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine().add('Antibiotic', times: [480, 1200], from: today)!;
    });
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
    await tester.tap(find.byKey(Key('dose-$id-0')));
    await tester.pumpAndSettle();
    expect(header(tester), 'Today: 1 of 2 doses taken');
  });

  testWidgets('ones not on today are listed apart', (tester) async {
    await openMedicine(tester, () {
      medicine()
        ..add('Daily', times: [480], from: today)
        ..add('Later', times: [480], from: DateTime(2026, 10, 20))
        ..add('Over',
            times: [480],
            from: DateTime(2026, 10, 1),
            until: DateTime(2026, 10, 5));
    });
    expect(find.text('Not today'), findsOneWidget);
    expect(find.textContaining('from Tue, 20 Oct'), findsOneWidget);
    expect(find.textContaining('until Mon, 5 Oct'), findsOneWidget);
    expect(header(tester), 'Today: 0 of 1 dose taken');
  });

  testWidgets('its name opens Edit and Delete (with undo)', (tester) async {
    await openMedicine(tester, () {
      medicine().add('Pills', times: [480], from: today);
    });
    await tester.tap(find.text('Pills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('medicineName')), 'Pills 💊');
    // How many doses stays as it was (Round 32); their times can change.
    expect(find.byKey(const Key('medicineAddTime')), findsNothing);
    expect(find.byTooltip('Remove this dose'), findsNothing);
    expect(find.byKey(const Key('medicineDosesFixed')), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final m = container.read(medicineProvider).medicines.single;
    expect(m.name, 'Pills 💊');
    expect(m.times, [480]);

    // Its menu is open again, on the medicine as it now is (Round 24).
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Pills 💊'), findsNWidgets(2), reason: 'card and menu');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).medicines, isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).medicines, hasLength(1));
  });

  testWidgets('an important one: deleting asks to type DELETE (Round 32)',
      (tester) async {
    await openMedicine(tester, () {
      medicine().add('Heart', times: [480], from: today, important: true);
    });
    await tester.tap(find.text('Heart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    final delete = find.widgetWithText(FilledButton, 'Delete');
    expect(tester.widget<FilledButton>(delete).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('typeToConfirm')), 'delete');
    await tester.pump();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).medicines, isEmpty);
  });

  testWidgets('some days only (Round 40): picked in the sheet, shown',
      (tester) async {
    await openMedicine(tester);
    await tester.tap(find.byTooltip('Add medicine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('medicineName')), 'Iron');
    await tester.tap(find.byKey(const Key('medicineSomeDays')));
    await tester.pump();
    // The first day's weekday (Monday, the tests' today) is picked to
    // start with; switch it to Wednesday.
    expect(
        tester
            .widget<FilterChip>(find.byKey(const Key('medicineDay-1')))
            .selected,
        isTrue);
    await tester.tap(find.byKey(const Key('medicineDay-3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('medicineDay-1')));
    await tester.pump();
    // The last one can't be unpicked.
    await tester.tap(find.byKey(const Key('medicineDay-3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('medicineSubmit')));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).medicines.single.weekdays, {3});
    // Not on a Monday: listed under Not today, with its day.
    expect(find.text('Not today'), findsOneWidget);
    expect(find.textContaining('08:00 · Wed ·'), findsOneWidget);
  });

  testWidgets('the sheet keeps at least one dose', (tester) async {
    await openMedicine(tester);
    await tester.tap(find.byTooltip('Add medicine'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove this dose'), findsNothing);
    await tester.tap(find.byKey(const Key('medicineAddTime')));
    await tester.pump();
    expect(find.byTooltip('Remove this dose'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Remove this dose').first);
    await tester.pump();
    expect(find.text('Once a day, at'), findsOneWidget);
  });

  testWidgets('history: the medicines on top, each day a table (Round 18)',
      (tester) async {
    late String id;
    late String other;
    await openMedicine(tester, () {
      id = medicine()
          .add('Vitamin D', times: [480], from: DateTime(2026, 10, 10))!;
      other = medicine()
          .add('Iron', times: [480, 1200], from: DateTime(2026, 10, 11))!;
      medicine()
        ..toggleDose(id, today, 0)
        ..setDose(other, DateTime(2026, 10, 11), 1, DoseState.missed);
    });
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('historyOf-$id')), findsOneWidget);
    expect(find.byKey(Key('historyOf-$other')), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Sun, 11 Oct'), findsOneWidget);
    expect(find.text('Sat, 10 Oct'), findsOneWidget);
    expect(find.text('Fri, 9 Oct'), findsNothing, reason: 'before it began');
    // A row per medicine on its days.
    expect(find.byKey(Key('historyRow-$other-2026-10-11')), findsOneWidget);
    expect(find.byKey(Key('historyRow-$other-2026-10-10')), findsNothing,
        reason: 'Iron began on the 11th');
    final missed = find.descendant(
      of: find.byKey(Key('historyRow-$other-2026-10-11')),
      matching: find.byIcon(Icons.cancel),
    );
    expect(tester.widget<Icon>(missed).color, DoseColours.missed);
  });

  testWidgets('history: a medicine on top opens its own history',
      (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine()
          .add('Vitamin D', times: [480], from: DateTime(2026, 10, 10))!;
    });
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('historyOf-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('medicineTotal')), findsOneWidget);
    expect(appBarTitle('Vitamin D'), findsOneWidget);
  });

  testWidgets(
      'history: a row opens that medicine at that day, where a dose '
      'can be set missed, not sure or taken', (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine()
          .add('Vitamin D', times: [480], from: DateTime(2026, 7, 1))!;
    });
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    // A day far down the list.
    final row = find.byKey(Key('historyRow-$id-2026-09-01'));
    await tester.scrollUntilVisible(row, 500,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    final mark = find.byKey(Key('mark-$id-2026-09-01-0'));
    expect(mark.hitTestable(), findsOneWidget, reason: 'scrolled to it');

    final day = DateTime(2026, 9, 1);
    await tester.tap(mark);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missed'));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).markFor(id, day, 0)!.state,
        DoseState.missed);

    await tester.tap(mark);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taken'));
    await tester.pumpAndSettle();
    final set = container.read(medicineProvider).markFor(id, day, 0)!;
    expect((set.state, set.at), (DoseState.taken, null),
        reason: 'set afterwards: no time');
  });

  group('a medicine\'s own history (O13)', () {
    Future<void> openOwn(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
    }

    testWidgets('total, calendar strip, and filling in past days',
        (tester) async {
      late String id;
      await openMedicine(tester, () {
        id = medicine()
            .add('Coffee', times: [480], from: DateTime(2026, 9, 30))!;
        medicine().toggleDose(id, today, 0);
      });
      await openOwn(tester, 'Coffee');
      String total() =>
          tester.widget<Text>(find.byKey(const Key('medicineTotal'))).data!;
      expect(total(), '1 dose');
      expect(find.byKey(const Key('medicineCalendar')), findsOneWidget);
      expect(find.byKey(const Key('calendar-2026-10-12')), findsOneWidget,
          reason: 'today in view at the right');

      await tester.tap(find.byKey(const Key('fillPast')));
      await tester.pumpAndSettle();
      expect(total(), '13 doses', reason: '30 Sep–11 Oct, and today');
      expect(find.byKey(const Key('fillPast')), findsNothing);
      // It can be undone (Round 39).
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(total(), '1 dose');
    });

    testWidgets('ten or fewer not set: no "Mark past days taken" (Round 16)',
        (tester) async {
      await openMedicine(tester, () {
        medicine().add('Coffee', times: [480], from: DateTime(2026, 10, 2));
      });
      await openOwn(tester, 'Coffee');
      expect(find.byKey(const Key('fillPast')), findsNothing,
          reason: '2–11 Oct: 10 doses');
    });

    testWidgets(
        'a month calendar: weeks as rows, older months to the left '
        '(Round 16)', (tester) async {
      late String id;
      await openMedicine(tester, () {
        id = medicine()
            .add('Coffee', times: [480], from: DateTime(2026, 9, 28))!;
        medicine()
          ..setDose(id, DateTime(2026, 10, 1), 0, DoseState.taken)
          ..setDose(id, DateTime(2026, 10, 2), 0, DoseState.missed);
      });
      await openOwn(tester, 'Coffee');
      String month() =>
          tester.widget<Text>(find.byKey(const Key('calendarMonth'))).data!;
      expect(month(), 'October 2026');
      Finder day(String d) => find.byKey(Key('calendar-$d'));

      // A week is a row, Monday first: Mondays share a column, the next
      // week is below, and Thu 1 Oct sits right of Monday's column.
      expect(tester.getCenter(day('2026-10-05')).dx,
          moreOrLessEquals(tester.getCenter(day('2026-10-12')).dx));
      expect(tester.getCenter(day('2026-10-12')).dy,
          greaterThan(tester.getCenter(day('2026-10-05')).dy));
      expect(tester.getCenter(day('2026-10-01')).dx,
          greaterThan(tester.getCenter(day('2026-10-05')).dx));

      // Marked by how it went.
      final palette =
          Theme.of(tester.element(day('2026-10-01'))).extension<AppPalette>()!;
      Color? fill(String d) =>
          (tester.widget<Container>(day(d)).decoration as BoxDecoration).color;
      // The same colours in every theme (Round 18).
      expect(fill('2026-10-01'), DoseColours.taken);
      expect(fill('2026-10-02'), DoseColours.missed);
      expect(palette.accent, isNot(DoseColours.taken));
      expect(fill('2026-10-20'), isNull, reason: 'still to come');
      expect(find.byKey(const Key('calendarNewer')), findsOneWidget);
      expect(
          tester
              .widget<IconButton>(find.byKey(const Key('calendarNewer')))
              .onPressed,
          isNull,
          reason: 'nothing after this month');

      // Older: a swipe to the right (or ‹).
      await tester.fling(find.byKey(const Key('medicineCalendar')),
          const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(month(), 'September 2026');
      expect(fill('2026-09-28'), isNotNull, reason: 'its first day');
      expect(
          tester
              .widget<IconButton>(find.byKey(const Key('calendarOlder')))
              .onPressed,
          isNull,
          reason: 'nothing before it started');
      await tester.tap(find.byKey(const Key('calendarNewer')));
      await tester.pumpAndSettle();
      expect(month(), 'October 2026');
    });

    testWidgets(
        'a calendar day shows that day below; it changes nothing (Round 18)',
        (tester) async {
      late String id;
      await openMedicine(tester, () {
        id =
            medicine().add('Coffee', times: [480], from: DateTime(2026, 8, 1))!;
      });
      await openOwn(tester, 'Coffee');
      final mark = find.byKey(Key('mark-$id-2026-10-01-0'));
      expect(mark.hitTestable(), findsNothing, reason: 'far down');
      await tester.tap(find.byKey(const Key('calendar-2026-10-01')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing, reason: 'no sheet');
      expect(
          container
              .read(medicineProvider)
              .markFor(id, DateTime(2026, 10, 1), 0),
          isNull);
      expect(mark.hitTestable(), findsOneWidget, reason: 'shown, on screen');
    });
  });

  testWidgets('started in the past: offers to mark those days taken',
      (tester) async {
    await openMedicine(tester);
    await tester.tap(find.byTooltip('Add medicine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('medicineName')), 'Tea');
    await tester.pump();
    await tester.tap(find.byKey(const Key('medicineFrom')));
    await tester.pumpAndSettle();
    // Back to the 1st in the date picker.
    await tester.tap(find.text('1'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('medicineSubmit')));
    await tester.pumpAndSettle();

    expect(find.text('Mark the past days taken?'), findsOneWidget);
    await tester.tap(find.text('Mark taken'));
    await tester.pumpAndSettle();
    final book = container.read(medicineProvider);
    final id = book.medicines.single.id;
    expect(book.takenCount(id), 11, reason: '1–11 Oct');
    expect(book.markFor(id, today, 0), isNull, reason: 'not today');
  });

  testWidgets('started a few days back: not asked (Round 16)', (tester) async {
    await openMedicine(tester);
    await tester.tap(find.byTooltip('Add medicine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('medicineName')), 'Tea');
    await tester.pump();
    await tester.tap(find.byKey(const Key('medicineFrom')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('medicineSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Mark the past days taken?'), findsNothing);
  });

  group('handling (Round 14)', () {
    testWidgets('doses: two per row, the same width; one takes column 1',
        (tester) async {
      late String one, three;
      await openMedicine(tester, () {
        one = medicine().add('Once', times: [480], from: today)!;
        three = medicine().add('Thrice', times: [480, 720, 1200], from: today)!;
      });
      Rect dose(String id, int d) =>
          tester.getRect(find.byKey(Key('dose-$id-$d')));
      expect(dose(three, 0).width, dose(three, 1).width);
      expect(dose(three, 0).top, dose(three, 1).top, reason: 'one row');
      expect(dose(three, 2).top, greaterThan(dose(three, 0).top));
      expect(dose(three, 2).left, dose(three, 0).left, reason: 'column 1');
      expect(dose(one, 0).width, dose(three, 0).width, reason: 'not full');
    });

    testWidgets('a tap anywhere on a card opens it', (tester) async {
      late String id;
      await openMedicine(tester, () {
        id = medicine().add('Pills', times: [480], from: today)!;
      });
      final card = tester.getRect(find.byKey(Key('medicineCard-$id')));
      // Beside the dose, in the card's empty half.
      await tester.tapAt(Offset(card.right - 60, card.bottom - 20));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.textContaining('for good'), findsNothing);
      expect(find.text('08:00 · from Mon, 12 Oct'), findsOneWidget);
    });

    testWidgets('its buttons are on the right, whichever hand', (tester) async {
      now = DateTime(2026, 10, 12, 8, 3);
      container = await pumpApp(tester, clock: () => now);
      await openTab(tester, 'Hub');
      // The last touch on the left (a left hand), then open it without one.
      await tester.tapAt(const Offset(20, 300));
      await tester.pump();
      await tapAsScreenReader(tester, find.byTooltip('Medicine'));
      final width = tester.getSize(find.byType(MaterialApp)).width;
      expect(tester.getCenter(find.byTooltip('Add medicine')).dx,
          greaterThan(width / 2));
    });

    testWidgets('drag a card\'s handle to move it', (tester) async {
      await openMedicine(tester, () {
        medicine()
          ..add('First', times: [480], from: today)
          ..add('Second', times: [480], from: today);
      });
      // The first card's handle, dragged down past the second, in steps.
      final handle = find.byIcon(Icons.drag_handle).first;
      final drag = await tester.startGesture(tester.getCenter(handle));
      for (var i = 0; i < 12; i++) {
        await drag.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(container.read(medicineProvider).medicines.map((m) => m.name),
          ['Second', 'First']);
    });
  });

  testWidgets('remind again is set per medicine, in its sheet (Round 16)',
      (tester) async {
    await openMedicine(tester);
    await tester.tap(find.byTooltip('Add medicine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('medicineName')), 'Pills');
    await tester.pump();
    expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('followUp-0'))).selected,
        isTrue,
        reason: 'off by default');
    await tester.ensureVisible(find.byKey(const Key('followUp-120')));
    await tester.tap(find.byKey(const Key('followUp-120')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('medicineSubmit')));
    await tester.pumpAndSettle();
    final m = container.read(medicineProvider).medicines.single;
    expect(m.followUp, 120);

    // Its menu says so, and editing keeps it.
    await tester.tap(find.text('Pills'));
    await tester.pumpAndSettle();
    expect(find.textContaining('again after 2 h'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('followUp-120')))
            .selected,
        isTrue);
    // Clear of the Save button below (Round 40: the sheet grew).
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('followUp-0'))),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('followUp-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('medicineSubmit')));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).medicines.single.followUp, isNull);
  });

  testWidgets('back to top in the histories, once scrolled far (Round 20)',
      (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine()
          .add('Vitamin D', times: [480], from: DateTime(2026, 1, 1))!;
    });
    final button = find.byKey(const Key('backToTop'));
    double scale() => tester
        .widget<AnimatedScale>(
            find.ancestor(of: button, matching: find.byType(AnimatedScale)))
        .scale;
    for (final (open, top) in [
      (
        () => tester.tap(find.byTooltip('History')),
        find.byKey(Key('historyOf-$id')),
      ),
      (
        () async {
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Vitamin D'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('History'));
        },
        find.byKey(const Key('medicineTotal')),
      ),
    ]) {
      await open();
      await tester.pumpAndSettle();
      expect(scale(), 0, reason: 'at the top: not needed');
      final list = find.byType(Scrollable).first;
      await tester.drag(list, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(scale(), 0, reason: 'not far yet');
      for (var i = 0; i < 6; i++) {
        // With the left hand: the button stays on the right (Round 24).
        await tester.dragFrom(tester.getTopLeft(list) + const Offset(20, 300),
            const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(scale(), 1, reason: 'far down: there');
      final screen = tester.getSize(find.byType(MaterialApp));
      expect(tester.getCenter(button).dx, greaterThan(screen.width / 2));
      // Room at the end, so it doesn't cover the last entries.
      expect(
          tester
              .widget<PullDownList>(find.byType(PullDownList).last)
              .bottomSpace,
          greaterThanOrEqualTo(screen.height - tester.getRect(button).top));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(scale(), 0, reason: 'back at the top');
      expect(top.hitTestable(), findsOneWidget, reason: 'the top in view');
    }
  });
}
