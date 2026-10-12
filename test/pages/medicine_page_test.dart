import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('a second tap unmarks it, with undo', (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine().add('Vitamin D', times: [480], from: today)!;
      medicine().toggleDose(id, today, 0);
    });
    await tester.tap(find.byKey(Key('dose-$id-0')));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).takenFor(id, today, 0), isNull);
    expect(find.text('Vitamin D: not taken'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(medicineProvider).takenFor(id, today, 0)!.at,
        DateTime(2026, 10, 12, 8, 3),
        reason: 'the first time, kept');
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

  testWidgets('history: each day, taken with its time or not', (tester) async {
    late String id;
    await openMedicine(tester, () {
      id = medicine()
          .add('Vitamin D', times: [480], from: DateTime(2026, 10, 10))!;
      medicine().toggleDose(id, today, 0);
    });
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('08:00 ✓ 08:03'), findsOneWidget);
    expect(find.text('Sun, 11 Oct'), findsOneWidget);
    expect(find.text('Sat, 10 Oct'), findsOneWidget);
    expect(find.text('08:00 not taken'), findsNWidgets(2));
    expect(find.text('Fri, 9 Oct'), findsNothing, reason: 'before it began');
  });
}
