import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';

import 'helpers.dart';

void main() {
  const tabs = ['Notes', 'Shop', 'Planner', 'Other'];

  testWidgets('starts on Notes', (tester) async {
    await pumpApp(tester);
    expect(appBarTitle('Notes'), findsOneWidget);
  });

  for (final tab in tabs) {
    testWidgets('back twice on $tab closes the app', (tester) async {
      final exit = ExitRecorder(tester);
      await pumpApp(tester);
      await openTab(tester, tab);

      await pressBack(tester);
      expect(exit.exits, 0);
      expect(find.text('Press back again to exit'), findsOneWidget);

      await pressBack(tester);
      expect(exit.exits, 1);
    });

    testWidgets('Security opened from the $tab menu returns to $tab',
        (tester) async {
      final exit = ExitRecorder(tester);
      await pumpApp(tester);
      await openTab(tester, tab);

      await openMenu(tester);
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Security'), findsOneWidget);

      await pressBack(tester);

      expect(exit.exits, 0);
      expect(appBarTitle('Security'), findsNothing);
      expect(appBarTitle(tab), findsOneWidget);
      expect(find.byType(Drawer), findsNothing, reason: 'menu stays closed');
    });
  }

  testWidgets('Backup opened from the menu returns to the section',
      (tester) async {
    final exit = ExitRecorder(tester);
    await pumpApp(tester);
    await openTab(tester, 'Shop');
    await openMenu(tester);
    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Backup'), findsOneWidget);

    await pressBack(tester);

    expect(exit.exits, 0);
    expect(appBarTitle('Shop'), findsOneWidget);
  });

  testWidgets('back from a note returns to the notes list', (tester) async {
    final exit = ExitRecorder(tester);
    final container = await pumpApp(tester);
    container.read(notesProvider.notifier).addNote(title: 'Groceries');
    await tester.pump();

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Note'), findsOneWidget);

    await pressBack(tester);

    expect(exit.exits, 0);
    expect(appBarTitle('Notes'), findsOneWidget);
  });

  testWidgets('a second back after more than 2 seconds asks again',
      (tester) async {
    final exit = ExitRecorder(tester);
    await pumpApp(tester);

    await pressBack(tester);
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await pressBack(tester);

    expect(exit.exits, 0);
    expect(find.text('Press back again to exit'), findsOneWidget);

    await pressBack(tester);
    expect(exit.exits, 1);
  });

  testWidgets('back in selection mode only leaves selection mode',
      (tester) async {
    final exit = ExitRecorder(tester);
    final container = await pumpApp(tester);
    container.read(notesProvider.notifier).addNote(title: 'Groceries');
    await tester.pump();

    await tester.longPress(find.text('Groceries'));
    await tester.pump();
    await pressBack(tester);

    expect(exit.exits, 0);
    expect(find.textContaining('selected'), findsNothing);
    expect(appBarTitle('Notes'), findsOneWidget);
    expect(find.text('Press back again to exit'), findsNothing,
        reason: 'leaving selection mode is not a step towards exiting');

    await pressBack(tester);
    await pressBack(tester);
    expect(exit.exits, 1);
  });

  testWidgets('menu shows Security, Backup and the app version',
      (tester) async {
    await pumpApp(tester);
    await openMenu(tester);

    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Version $testAppVersion'), findsOneWidget);
  });

  testWidgets('back with the menu open closes the menu, not the app',
      (tester) async {
    final exit = ExitRecorder(tester);
    await pumpApp(tester);
    await openMenu(tester);

    await pressBack(tester);

    expect(exit.exits, 0);
    expect(find.byType(Drawer), findsNothing);
    expect(appBarTitle('Notes'), findsOneWidget);
    expect(find.text('Press back again to exit'), findsNothing);
  });

  testWidgets('Planner and Other show their placeholders', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Planner');
    expect(find.text('The planner is coming soon'), findsOneWidget);
    await openTab(tester, 'Other');
    expect(find.text('More tools are coming soon'), findsOneWidget);
  });

  testWidgets('a hidden tab in selection mode does not block back',
      (tester) async {
    final exit = ExitRecorder(tester);
    final container = await pumpApp(tester);
    container.read(notesProvider.notifier).addNote(title: 'Groceries');
    await tester.pump();

    await tester.longPress(find.text('Groceries'));
    await tester.pump();
    await openTab(tester, 'Shop');
    await pressBack(tester);
    expect(find.text('Press back again to exit'), findsOneWidget);
    await pressBack(tester);

    expect(exit.exits, 1);
  });
}
