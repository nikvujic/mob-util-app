import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/pages/hub/hold_to_take.dart';
import 'package:the_app/providers/medicine_provider.dart';

import '../helpers.dart';

/// Important medicines (Round 24): set in the sheet; a dose is taken only
/// by holding a button for 5 seconds.
void main() {
  late ProviderContainer container;
  final today = DateTime(2026, 10, 12);

  MedicineNotifier medicine() => container.read(medicineProvider.notifier);

  Future<void> openMedicine(WidgetTester tester,
      [void Function()? seed]) async {
    container =
        await pumpApp(tester, clock: () => DateTime(2026, 10, 12, 8, 3));
    seed?.call();
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Medicine'));
    await tester.pumpAndSettle();
  }

  final important = find.byKey(const Key('medicineImportant'));
  final hold = find.byKey(const Key('holdToTake'));

  /// How full the glass is, in percent.
  int full(WidgetTester tester) {
    final value =
        tester.getSemantics(find.byKey(const Key('holdToTakeFill'))).value;
    return int.parse(value.replaceAll('%', ''));
  }

  Future<void> showImportant(WidgetTester tester) async {
    await tester.scrollUntilVisible(important, 100,
        scrollable: find
            .descendant(
                of: find.byType(BottomSheet), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(important);
    await tester.pumpAndSettle();
  }

  group('the sheet', () {
    testWidgets('set important when adding; said what it does', (tester) async {
      await openMedicine(tester);
      await tester.tap(find.byTooltip('Add medicine'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('medicineName')), 'Iron');
      await showImportant(tester);
      expect(find.textContaining('held for 5 seconds'), findsOneWidget);
      expect(find.textContaining('red dot'), findsOneWidget);
      await tester.tap(important);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(important).value, isTrue);
      await tester.tap(find.byKey(const Key('medicineSubmit')));
      await tester.pumpAndSettle();
      expect(
          container.read(medicineProvider).medicines.single.important, isTrue);
    });

    testWidgets(
        'only back closes it, asking first once something changed; '
        'tapping outside does nothing', (tester) async {
      await openMedicine(tester);
      await tester.tap(find.byTooltip('Add medicine'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20)); // above the sheet
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('medicineName')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('medicineName')), 'Iron');
      await tester.pump();
      await tester.binding.handlePopRoute(); // the phone's back
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('medicineName')), findsNothing);
      expect(container.read(medicineProvider).medicines, isEmpty);
    });

    testWidgets('editing, closed without saving: its menu opens again',
        (tester) async {
      await openMedicine(tester, () {
        medicine().add('Iron', times: [480], from: today);
      });
      await tester.tap(find.text('Iron'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      // The phone's back; nothing changed: closes at once.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('taking a dose', () {
    late String id;

    Future<void> start(WidgetTester tester) => openMedicine(tester, () {
          id = medicine()
              .add('Iron', times: [480], from: today, important: true)!;
        });

    bool taken() =>
        container.read(medicineProvider).takenFor(id, today, 0) != null;

    testWidgets('a tap asks to hold; let go early, it drains, not taken',
        (tester) async {
      await start(tester);
      await tester.tap(find.byKey(Key('dose-$id-0')));
      await tester.pumpAndSettle();
      expect(find.text('Take Iron?'), findsOneWidget);
      expect(taken(), isFalse, reason: 'not by a tap');

      final gesture = await tester.startGesture(tester.getCenter(hold));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Keep holding'), findsOneWidget);
      expect(full(tester), 60);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Hold'), findsOneWidget);
      expect(full(tester), 0, reason: 'drained');
      expect(taken(), isFalse);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Take Iron?'), findsNothing);
      expect(taken(), isFalse);
    });

    testWidgets('held for 5 seconds: taken', (tester) async {
      await start(tester);
      await tester.tap(find.byKey(Key('dose-$id-0')));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(hold));
      await tester.pump();
      await tester.pump(holdToTakeTime - const Duration(milliseconds: 100));
      expect(taken(), isFalse, reason: 'not quite yet');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await gesture.up();
      expect(find.text('Take Iron?'), findsNothing);
      expect(taken(), isTrue);
    });

    testWidgets(
        'a second finger neither restarts nor stops it; one finger left '
        'keeps filling (Round 24)', (tester) async {
      await start(tester);
      await tester.tap(find.byKey(Key('dose-$id-0')));
      await tester.pumpAndSettle();
      final center = tester.getCenter(hold);
      final first = await tester.startGesture(center);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final second =
          await tester.startGesture(center + const Offset(10, 10), pointer: 7);
      await tester.pump(const Duration(seconds: 1));
      await second.up();
      await tester.pump(const Duration(seconds: 1));
      expect(full(tester), 60, reason: 'still filling, from where it was');
      await tester.pump(const Duration(seconds: 2, milliseconds: 100));
      await tester.pumpAndSettle();
      await first.up();
      expect(taken(), isTrue);
    });

    testWidgets('unticking asks as before, no hold', (tester) async {
      await start(tester);
      medicine().toggleDose(id, today, 0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('dose-$id-0')));
      await tester.pumpAndSettle();
      expect(find.text('Mark as not taken?'), findsOneWidget);
      expect(hold, findsNothing);
    });
  });
}
