import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/providers/medicine_provider.dart';

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
    // 08:00 has gone by (it's 08:03): late, in red (Round 17).
    expect(find.text('Not taken yet'), findsOneWidget);
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

  testWidgets('a second tap unmarks it (no undo needed)', (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine().add('Vitamin D', times: [480], from: today)!;
      medicine().toggleDose(id, today, 0);
    });
    await tester.tap(find.byKey(Key('dose-$id-0')));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).takenFor(id, today, 0), isNull);
    expect(find.text('Undo'), findsNothing);
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
    await tester.tap(find.byKey(const Key('medicineAddTime')));
    await tester.pump();
    expect(find.text('2 times a day, at'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final m = container.read(medicineProvider).medicines.single;
    expect(m.name, 'Pills 💊');
    expect(m.times, [480, 720], reason: 'a dose 4 hours after the last');

    await tester.tap(find.text('Pills 💊'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).medicines, isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).medicines, hasLength(1));
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

  testWidgets('history: each day, each dose with how it went', (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine()
          .add('Vitamin D', times: [480], from: DateTime(2026, 10, 10))!;
      medicine().toggleDose(id, today, 0);
    });
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('08:03'), findsOneWidget, reason: 'ticked at 08:03');
    expect(find.text('Sun, 11 Oct'), findsOneWidget);
    expect(find.text('Sat, 10 Oct'), findsOneWidget);
    expect(find.text('not set'), findsNWidgets(2));
    expect(find.text('Fri, 9 Oct'), findsNothing, reason: 'before it began');
  });

  testWidgets('history: a dose can be set missed, not sure or taken',
      (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine()
          .add('Vitamin D', times: [480], from: DateTime(2026, 10, 11))!;
    });
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    final yesterday = DateTime(2026, 10, 11);
    await tester.tap(find.byKey(Key('mark-$id-2026-10-11-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missed'));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).markFor(id, yesterday, 0)!.state,
        DoseState.missed);
    expect(find.text('missed'), findsOneWidget);

    await tester.tap(find.byKey(Key('mark-$id-2026-10-11-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taken'));
    await tester.pumpAndSettle();
    final mark = container.read(medicineProvider).markFor(id, yesterday, 0)!;
    expect((mark.state, mark.at), (DoseState.taken, null),
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

    testWidgets('a calendar day sets its dose', (tester) async {
      late String id;
      await openMedicine(tester, () {
        id = medicine()
            .add('Coffee', times: [480], from: DateTime(2026, 10, 10))!;
      });
      await openOwn(tester, 'Coffee');
      await tester.tap(find.byKey(const Key('calendar-2026-10-11')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not sure'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(medicineProvider)
            .markFor(id, DateTime(2026, 10, 11), 0)!
            .state,
        DoseState.unsure,
      );
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

  testWidgets('a dose whose time has come and not taken is red (Round 17)',
      (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine().add('Pills', times: [480, 1200], from: today)!;
    });
    // 08:03: the 08:00 dose is late, the 20:00 one isn't.
    final late = find.byKey(const Key('doseLate'));
    expect(late, findsOneWidget);
    expect(
      find.descendant(of: find.byKey(Key('dose-$id-0')), matching: late),
      findsOneWidget,
    );
    final danger =
        Theme.of(tester.element(late)).extension<AppPalette>()!.danger;
    expect(tester.widget<Text>(late).style!.color, danger);

    // Comes on its own as time passes.
    now = DateTime(2026, 10, 12, 20, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(late, findsNWidgets(2));

    // Taken: not red.
    await tester.tap(find.byKey(Key('dose-$id-0')));
    await tester.pumpAndSettle();
    expect(late, findsOneWidget);
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
    await tester.ensureVisible(find.byKey(const Key('followUp-0')));
    await tester.tap(find.byKey(const Key('followUp-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('medicineSubmit')));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).medicines.single.followUp, isNull);
  });
}
