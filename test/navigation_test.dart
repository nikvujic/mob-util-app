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
    testWidgets('back on $tab closes the app', (tester) async {
      final exit = ExitRecorder(tester);
      await pumpApp(tester);
      await openTab(tester, tab);

      await pressBack(tester);

      expect(exit.exits, 1);
    });

    testWidgets('Settings opened from $tab returns to $tab on back',
        (tester) async {
      final exit = ExitRecorder(tester);
      await pumpApp(tester);
      await openTab(tester, tab);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Settings'), findsOneWidget);

      await pressBack(tester);

      expect(exit.exits, 0);
      expect(appBarTitle('Settings'), findsNothing);
      expect(appBarTitle(tab), findsOneWidget);
    });
  }

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
  });

  testWidgets('Settings lists Security and Backup', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
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

    expect(exit.exits, 1);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
