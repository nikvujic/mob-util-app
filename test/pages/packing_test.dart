import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/providers/packing_provider.dart';

import '../helpers.dart';

/// Hub → Packing (Round 94, Nikola): lists, a list's view mode (big
/// boxes, a tap ticks, Reset), edit mode, the shared sections, Copy list.
void main() {
  late ProviderContainer container;
  PackingBook book() => container.read(packingProvider);

  PackingBook sample() => PackingBook(
        sections: PackingBook.initial.sections,
        lists: [
          PackingList(id: 'l1', name: 'Ski trip', items: const [
            PackingItem(id: 'i1', name: 'Passport', sectionId: 'documents'),
            PackingItem(
                id: 'i2', name: 'Socks', sectionId: 'clothes', count: 5),
            PackingItem(
                id: 'i3',
                name: 'Charger',
                sectionId: 'electronics',
                packed: true),
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

  String text(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  testWidgets('no lists at first; a new one opens in edit mode',
      (tester) async {
    await openPacking(tester);
    expect(appBarTitle('Packing'), findsOneWidget);
    expect(find.text('No packing lists'), findsOneWidget);

    await tapTooltip(tester, 'New list');
    expect(appBarTitle('Edit list'), findsOneWidget);
    // Every section shown, the usual ones, Other last.
    for (final s in PackingBook.initial.sections) {
      expect(find.byKey(Key('packingAdd-${s.id}')), findsOneWidget);
    }
    await tester.enterText(find.byKey(const Key('packingName')), 'Beach');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Items added to Clothes, several in a row; no two of a name.
    await tester.tap(find.byKey(const Key('packingAdd-clothes')));
    await tester.pumpAndSettle();
    final field = find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.enterText(field, 'Swimsuit');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Hat');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'swimsuit');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('swimsuit is already in Clothes'), findsOneWidget);
    await pressBack(tester);

    final list = book().lists.single;
    expect(list.name, 'Beach');
    expect(list.items.map((i) => (i.name, i.sectionId)),
        [('Swimsuit', 'clothes'), ('Hat', 'clothes')]);

    await tapTooltip(tester, 'Done');
    expect(appBarTitle('Beach'), findsOneWidget);
    expect(text(tester, const Key('packingProgress')), '0 of 2 packed');
  });

  testWidgets('a new list left empty is dropped', (tester) async {
    await openPacking(tester);
    await tapTooltip(tester, 'New list');
    await tapTooltip(tester, 'Done');
    expect(book().lists, isEmpty);
    expect(find.text('No packing lists'), findsOneWidget);
  });

  testWidgets(
      'view mode: by section, empty ones left out; a tap anywhere on a '
      'row ticks it, in place; Reset unticks all, with Undo', (tester) async {
    await openPacking(tester, start: sample());
    expect(text(tester, const Key('packingListProgress-l1')), '1 of 3 packed');
    await tester.tap(find.text('Ski trip'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('packingSection-documents')), findsOneWidget);
    expect(find.byKey(const Key('packingSection-toiletries')), findsNothing,
        reason: 'nothing in it');
    expect(find.text('× 5'), findsOneWidget);
    expect(text(tester, const Key('packingProgress')), '1 of 3 packed');

    final socks = tester.getTopLeft(find.text('Socks'));
    // The row's far right, not the box or the name.
    final row = tester.getRect(find.byKey(const Key('packingTick-i2')));
    await tester.tapAt(Offset(row.right - 30, row.center.dy));
    await tester.pumpAndSettle();
    expect(book().byId('l1')!.items[1].packed, isTrue);
    expect(tester.getTopLeft(find.text('Socks')), socks,
        reason: "ticked ones don't move");
    expect(tester.widget<Icon>(find.byKey(const Key('packingBox-i2'))).icon,
        Icons.check_box);
    expect(text(tester, const Key('packingProgress')), '2 of 3 packed');

    await tester.tap(find.text('Socks'));
    await tester.pumpAndSettle();
    expect(book().byId('l1')!.items[1].packed, isFalse, reason: 'unticked');

    await tapTooltip(tester, 'Reset');
    expect(book().byId('l1')!.packedCount, 0);
    expect(find.text('All unticked'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().byId('l1')!.packedCount, 1);

    // All packed: said so.
    await tester.tap(find.text('Passport'));
    await tester.tap(find.text('Socks'));
    await tester.pumpAndSettle();
    expect(text(tester, const Key('packingProgress')), 'All 3 packed');
  });

  testWidgets(
      'edit mode: an item renamed, its count set, deleted (Undo); '
      'Discard changes goes back', (tester) async {
    await openPacking(tester, start: sample());
    await tester.tap(find.text('Ski trip'));
    await tester.pumpAndSettle();
    await tapTooltip(tester, 'Edit');

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    await choose(tester, 'count');
    await tester.tap(find.byKey(const Key('packingCountMore')));
    await tester.tap(find.byKey(const Key('packingCountMore')));
    await tester.pump();
    expect(text(tester, const Key('packingCountValue')), '3');
    await tester.tap(find.byKey(const Key('packingCountSet')));
    await tester.pumpAndSettle();
    expect(book().byId('l1')!.items.first.count, 3, reason: 'saved as made');

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    await choose(tester, 'rename');
    await tester.enterText(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.byType(TextField)),
        'Pasoš');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(book().byId('l1')!.items.first.name, 'Pasoš');

    await tester.tap(find.text('Socks'));
    await tester.pumpAndSettle();
    await choose(tester, 'delete');
    expect(book().byId('l1')!.items.map((i) => i.name), ['Pasoš', 'Charger']);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().byId('l1')!.items.map((i) => i.name),
        ['Pasoš', 'Socks', 'Charger']);

    await tapTooltip(tester, 'Discard changes');
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(book().byId('l1')!.items.first.name, 'Passport');
    expect(book().byId('l1')!.items.first.count, 1);
  });

  testWidgets('edit mode: an item dragged by its handle into another section',
      (tester) async {
    await openPacking(tester, start: sample());
    await tester.tap(find.text('Ski trip'));
    await tester.pumpAndSettle();
    await tapTooltip(tester, 'Edit');

    // Passport's handle, dragged down below Socks (into Clothes).
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

    final items = book().byId('l1')!.items;
    expect(items.firstWhere((i) => i.id == 'i1').sectionId, 'clothes');
  });

  testWidgets(
      'Copy list: a new name, only the sections picked, nothing ticked; '
      'it opens', (tester) async {
    await openPacking(tester, start: sample());
    await tester.tap(find.text('Ski trip'));
    await tester.pumpAndSettle();
    await tapTooltip(tester, 'More');
    await choose(tester, 'copy');

    expect(find.text('Ski trip (Copy)'), findsOneWidget);
    // Only the list's sections with something in them, all picked.
    expect(
        find.byKey(const Key('packingCopySection-documents')), findsOneWidget);
    expect(
        find.byKey(const Key('packingCopySection-toiletries')), findsNothing);
    await tester.enterText(find.byKey(const Key('packingCopyName')), 'Weekend');
    await tester.tap(find.byKey(const Key('packingCopySection-clothes')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('packingCopyGo')));
    await tester.pumpAndSettle();

    expect(book().lists.map((l) => l.name), ['Ski trip', 'Weekend']);
    final copy = book().lists.last;
    expect(copy.items.map((i) => i.name), ['Passport', 'Charger']);
    expect(copy.packedCount, 0);
    expect(appBarTitle('Weekend'), findsOneWidget);
  });

  testWidgets(
      'Sections: added (no two of a name), deleted with its '
      'items moved to Other (Undo); Other stays', (tester) async {
    await openPacking(tester, start: sample());
    await tapTooltip(tester, 'Sections');
    expect(appBarTitle('Sections'), findsOneWidget);
    expect(find.text('Always there, last'), findsOneWidget);

    await tapTooltip(tester, 'New section');
    final field = find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.enterText(field, 'Ski gear');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'clothes');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('clothes is already a section'), findsOneWidget);
    await pressBack(tester);
    expect(book().sections.map((s) => s.name).toList().reversed.take(2),
        ['Other', 'Ski gear'],
        reason: 'before Other');

    await tester.tap(find.text('Electronics'));
    await tester.pumpAndSettle();
    await choose(tester, 'delete');
    expect(find.text('Electronics deleted; its items moved to Other'),
        findsOneWidget);
    expect(book().byId('l1')!.items.last.sectionId, 'other');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(book().byId('l1')!.items.last.sectionId, 'electronics');

    // Other: no options.
    await tester.tap(find.byKey(const Key('packingSection-other')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('choice-delete')), findsNothing);
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
