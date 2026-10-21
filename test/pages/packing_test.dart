import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/providers/packing_provider.dart';

import '../helpers.dart';

/// Hub → Packing (Round 94, Nikola; Round 95: his changes): lists, a
/// list's view mode (rows of a normal size, a tap ticks, Reset asked),
/// edit mode (its own sections, + Add under each, hold to select and
/// delete, Save or Discard on back), Copy list, the default sections.
void main() {
  late ProviderContainer container;
  PackingBook book() => container.read(packingProvider);

  const sections = [
    PackingSection(id: 'documents', name: 'Documents'),
    PackingSection(id: 'clothes', name: 'Clothes'),
    PackingSection(id: 'gear', name: 'Ski gear'),
  ];

  PackingBook sample() => PackingBook(
        sections: PackingBook.defaults,
        lists: [
          PackingList(
              id: 'l1',
              name: 'Ski trip',
              sections: sections,
              items: const [
                PackingItem(id: 'i1', name: 'Passport', sectionId: 'documents'),
                PackingItem(
                    id: 'i2', name: 'Socks', sectionId: 'clothes', count: 5),
                PackingItem(
                    id: 'i3', name: 'Goggles', sectionId: 'gear', packed: true),
              ]),
        ],
      );

  Future<void> openPacking(WidgetTester tester, {PackingBook? start}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container = await pumpApp(tester, packing: start);
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Packing'));
    await tester.pumpAndSettle();
  }

  Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String value) async {
    await tester.tap(find.byKey(Key('choice-$value')));
    await tester.pumpAndSettle();
  }

  Future<void> openTrip(WidgetTester tester, {bool edit = false}) async {
    await tester.tap(find.text('Ski trip'));
    await tester.pumpAndSettle();
    if (edit) await tapTooltip(tester, 'Edit');
  }

  Finder sheetField() => find.descendant(
      of: find.byType(BottomSheet), matching: find.byType(TextField));

  String text(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  PackingList trip() => book().byId('l1')!;

  testWidgets(
      'a new list: "New list", the default sections, + Add under each; '
      'Done goes back to the lists, where it shows', (tester) async {
    await openPacking(tester);
    expect(find.text('No packing lists'), findsOneWidget);

    await tapTooltip(tester, 'New list');
    expect(appBarTitle('New list'), findsOneWidget);
    for (final s in PackingBook.defaults) {
      expect(find.byKey(Key('packingAdd-${s.id}')), findsOneWidget);
    }
    // Round 95: no room asked above the name, so typing doesn't bounce
    // the page into its reach space.
    final name = tester.widget<TextField>(find.byKey(const Key('packingName')));
    expect(name.scrollPadding.top, 0);
    await tester.enterText(find.byKey(const Key('packingName')), 'Beach');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Under Clothes, several in a row; no two of a name.
    await tester.tap(find.byKey(const Key('packingAdd-clothes')));
    await tester.pumpAndSettle();
    for (final thing in ['Swimsuit', 'Hat', 'swimsuit']) {
      await tester.enterText(sheetField(), thing);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
    }
    expect(find.text('swimsuit is already in Clothes'), findsOneWidget);
    await pressBack(tester);

    await tapTooltip(tester, 'Done');
    expect(appBarTitle('Packing'), findsOneWidget,
        reason: 'back on the lists, not its view');
    final list = book().lists.single;
    expect(list.name, 'Beach');
    expect(list.sections, PackingBook.defaults);
    expect(list.items.map((i) => (i.name, i.sectionId)),
        [('Swimsuit', 'clothes'), ('Hat', 'clothes')]);
    expect(find.text('0 of 2 packed'), findsOneWidget);
  });

  testWidgets(
      'a new list: Back asks Save or Discard once something is in it; '
      'Discard leaves nothing; left untouched, nothing asked', (tester) async {
    await openPacking(tester);
    await tapTooltip(tester, 'New list');
    await pressBack(tester); // the keyboard
    await pressBack(tester);
    expect(find.text('Save new list?'), findsNothing);
    expect(appBarTitle('Packing'), findsOneWidget);
    expect(book().lists, isEmpty);

    await tapTooltip(tester, 'New list');
    await tester.enterText(find.byKey(const Key('packingName')), 'Beach');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await pressBack(tester); // the keyboard
    await pressBack(tester);
    expect(find.text('Save new list?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Packing'), findsOneWidget);
    expect(book().lists, isEmpty);
  });

  testWidgets(
      'view mode: every section, empty ones too; normal rows; a tap '
      'anywhere ticks, in place; Reset asks, no toast', (tester) async {
    await openPacking(tester, start: sample());
    expect(find.text('1 of 3 packed'), findsOneWidget);
    await openTrip(tester);

    for (final s in sections) {
      expect(find.byKey(Key('packingSection-${s.id}')), findsOneWidget);
    }
    expect(find.text('× 5'), findsOneWidget);
    // Round 95: a normal row, as Shop's.
    expect(tester.getSize(find.byKey(const Key('packingTick-i1'))).height,
        lessThanOrEqualTo(56));

    final socks = tester.getTopLeft(find.text('Socks'));
    final row = tester.getRect(find.byKey(const Key('packingTick-i2')));
    await tester.tapAt(Offset(row.right - 30, row.center.dy));
    await tester.pumpAndSettle();
    expect(trip().items[1].packed, isTrue);
    expect(tester.getTopLeft(find.text('Socks')), socks,
        reason: "ticked ones don't move");
    expect(text(tester, const Key('packingProgress')), '2 of 3 packed');

    await tapTooltip(tester, 'Reset');
    expect(find.text('Reset the list?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(trip().packedCount, 2);
    await tapTooltip(tester, 'Reset');
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(trip().packedCount, 0);
    expect(find.byType(SnackBar), findsNothing, reason: 'no Undo toast');
  });

  testWidgets(
      'edit mode: a thing renamed and counted; held ones selected and '
      'deleted; Back asks, Discard puts it back', (tester) async {
    await openPacking(tester, start: sample());
    await openTrip(tester, edit: true);
    expect(appBarTitle('Edit list'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsNothing, reason: 'no Undo or Redo');

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('choice-delete')), findsNothing,
        reason: 'deleting is by holding');
    await choose(tester, 'count');
    await tester.tap(find.byKey(const Key('packingCountMore')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('packingCountSet')));
    await tester.pumpAndSettle();
    expect(trip().items.first.count, 2, reason: 'saved as made');

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    await choose(tester, 'rename');
    await tester.enterText(sheetField(), 'Pasoš');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(trip().items.first.name, 'Pasoš');

    await tester.longPress(find.text('Socks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goggles'));
    await tester.pumpAndSettle();
    await tapTooltip(tester, 'Delete selected');
    expect(trip().items.map((i) => i.name), ['Pasoš']);

    await pressBack(tester);
    expect(find.text('Save changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Ski trip'), findsOneWidget, reason: 'back to view');
    expect(trip().items.map((i) => (i.name, i.count)),
        [('Passport', 1), ('Socks', 5), ('Goggles', 1)]);
  });

  testWidgets(
      "edit mode: the list's own sections added, renamed, moved, deleted "
      'with their things (asked); the last one stays; Save keeps it',
      (tester) async {
    await openPacking(tester, start: sample());
    await openTrip(tester, edit: true);

    await tester.tap(find.byKey(const Key('packingAddSection')));
    await tester.pumpAndSettle();
    await tester.enterText(sheetField(), 'clothes');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('clothes is already a section'), findsOneWidget);
    await tester.enterText(sheetField(), 'Food');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(trip().sections.map((s) => s.name),
        ['Documents', 'Clothes', 'Ski gear', 'Food']);

    // Moved up, renamed.
    await tester.tap(find.byKey(const Key('packingSection-gear')));
    await tester.pumpAndSettle();
    await choose(tester, 'up');
    await tester.tap(find.byKey(const Key('packingSection-gear')));
    await tester.pumpAndSettle();
    await choose(tester, 'rename');
    await tester.enterText(sheetField(), 'Gear');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(trip().sections.map((s) => s.name),
        ['Documents', 'Gear', 'Clothes', 'Food']);

    // With a thing in it: asked, then gone with it.
    await tester.tap(find.byKey(const Key('packingSection-clothes')));
    await tester.pumpAndSettle();
    await choose(tester, 'delete');
    expect(find.text('Delete Clothes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(trip().sections.map((s) => s.name), ['Documents', 'Gear', 'Food']);
    expect(trip().items.map((i) => i.name), ['Passport', 'Goggles']);

    // Empty: not asked. Down to one: it stays.
    for (final id in ['food', 'gear']) {
      final section = trip()
          .sections
          .firstWhere((s) => s.id == id || s.name.toLowerCase() == id);
      await tester.tap(find.byKey(Key('packingSection-${section.id}')));
      await tester.pumpAndSettle();
      await choose(tester, 'delete');
      if (find.widgetWithText(FilledButton, 'Delete').evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
      }
    }
    expect(trip().sections.map((s) => s.name), ['Documents']);
    await tester.tap(find.byKey(const Key('packingSection-documents')));
    await tester.pumpAndSettle();
    await choose(tester, 'delete');
    expect(find.text('A list needs at least one section'), findsOneWidget);
    expect(trip().sections, hasLength(1));

    await pressBack(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Ski trip'), findsOneWidget);
    expect(trip().sections.map((s) => s.name), ['Documents']);
    // The defaults untouched.
    expect(book().sections, PackingBook.defaults);
  });

  testWidgets('edit mode: a thing dragged by its handle into another section',
      (tester) async {
    await openPacking(tester, start: sample());
    await openTrip(tester, edit: true);

    final passport = find.byKey(const Key('packingItem-i1'));
    final handle = Offset(
        tester.getRect(passport).right - 30, tester.getCenter(passport).dy);
    final below = tester.getRect(find.byKey(const Key('packingItem-i2')));
    final gesture = await tester.startGesture(handle);
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveTo(Offset(handle.dx, below.bottom + 4));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(trip().items.firstWhere((i) => i.id == 'i1').sectionId, 'clothes');
  });

  testWidgets(
      'Copy list: a name and the sections picked; back on the lists, with '
      'the copy', (tester) async {
    await openPacking(tester, start: sample());
    await openTrip(tester);
    await tapTooltip(tester, 'More');
    await choose(tester, 'copy');

    expect(find.text('Ski trip (Copy)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('packingCopyName')), 'Weekend');
    await tester.tap(find.byKey(const Key('packingCopySection-gear')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('packingCopyGo')));
    await tester.pumpAndSettle();

    expect(appBarTitle('Packing'), findsOneWidget);
    expect(book().lists.map((l) => l.name), ['Ski trip', 'Weekend']);
    final copy = book().lists.last;
    expect(copy.sections.map((s) => s.name), ['Documents', 'Clothes']);
    expect(copy.items.map((i) => i.name), ['Passport', 'Socks']);
    expect(copy.packedCount, 0);
  });

  testWidgets(
      'Default sections: what a new list starts with; added, deleted '
      '(Undo), one stays; the lists keep theirs', (tester) async {
    await openPacking(tester, start: sample());
    await tapTooltip(tester, 'Default sections');
    expect(appBarTitle('Default sections'), findsOneWidget);

    await tapTooltip(tester, 'New section');
    await tester.enterText(sheetField(), 'Ski gear');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.enterText(sheetField(), 'other');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('other is already a section'), findsOneWidget);
    await pressBack(tester);
    expect(book().sections.last.name, 'Ski gear');

    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await choose(tester, 'delete');
    expect(book().sections.map((s) => s.name), isNot(contains('Other')),
        reason: 'Other is like any other');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().sections.map((s) => s.name), contains('Other'));
    expect(trip().sections, sections);

    container
        .read(packingProvider.notifier)
        .restoreSections(const [PackingSection(id: 'only', name: 'Only')]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Only'));
    await tester.pumpAndSettle();
    await choose(tester, 'delete');
    expect(find.text('At least one section stays'), findsOneWidget);
    expect(book().sections, hasLength(1));
  });

  testWidgets('lists held to select, deleted after asking', (tester) async {
    await openPacking(tester, start: sample());
    await tester.longPress(find.text('Ski trip'));
    await tester.pumpAndSettle();
    await tapTooltip(tester, 'Delete');
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(book().lists, isEmpty);
  });
}
