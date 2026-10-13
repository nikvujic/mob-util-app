import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/todo_provider.dart';

import '../helpers.dart';

/// The to-do note (Round 28).
void main() {
  late ProviderContainer container;
  final tile = find.byKey(const Key('todoTile'));

  List<String> texts() =>
      container.read(todoProvider).map((i) => i.text).toList();

  Future<void> start(
    WidgetTester tester, {
    List<TodoItem> todo = const [],
    Preferences preferences = const Preferences(),
  }) async {
    container = await pumpApp(
      tester,
      introduction: true, // the app as started: its special notes show
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage.inMemory(
          initialTodo: todo,
          initialPreferences: preferences,
        )),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> add(WidgetTester tester, List<String> things) async {
    await tester.tap(find.byTooltip('Add a to-do'));
    await tester.pumpAndSettle();
    for (final thing in things) {
      await tester.enterText(find.byType(TextField), thing);
      await tester.tap(find.text('Add'));
      await tester.pump();
    }
    await tester.tapAt(const Offset(200, 100)); // closes the sheet
    await tester.pumpAndSettle();
  }

  testWidgets('under the Introduction (Round 30), above the notes',
      (tester) async {
    await start(tester, todo: const [
      TodoItem(id: 't1', text: 'Call the dentist'),
      TodoItem(id: 't2', text: 'Pay rent'),
      TodoItem(id: 't3', text: 'Done already', done: true),
    ]);
    container.read(notesProvider.notifier).addNote(title: 'A note');
    await tester.pumpAndSettle();
    final intro = find.byKey(const Key('introductionTile'));
    expect(tile, findsOneWidget);
    expect(tester.getTopLeft(intro).dy, lessThan(tester.getTopLeft(tile).dy));
    expect(tester.getTopLeft(tile).dy,
        lessThan(tester.getTopLeft(find.text('A note')).dy));
    // The first thing to do and how many are left.
    expect(tester.widget<Text>(find.byKey(const Key('todoSummary'))).data,
        'Call the dentist');
    expect(tester.widget<Text>(find.byKey(const Key('todoCount'))).data, '2');
  });

  testWidgets('empty: says so', (tester) async {
    await start(tester);
    expect(tester.widget<Text>(find.byKey(const Key('todoSummary'))).data,
        'Nothing to do');
    expect(find.byKey(const Key('todoCount')), findsNothing);
    await open(tester);
    expect(find.text('Nothing to do'), findsOneWidget);
  });

  testWidgets('no notes and the Introduction deleted: still there',
      (tester) async {
    await start(tester,
        preferences: const Preferences(
          introVersion: testAppVersion,
          introDeleted: true,
        ));
    expect(tile, findsOneWidget);
    expect(find.text('No notes'), findsNothing);
  });

  testWidgets('adding things puts them at the end, in order', (tester) async {
    await start(tester);
    await open(tester);
    await add(tester, ['Milk the cat', 'Feed the cow']);
    expect(texts(), ['Milk the cat', 'Feed the cow']);
    expect(find.text('Milk the cat'), findsOneWidget);
    expect(find.text('Feed the cow'), findsOneWidget);
  });

  testWidgets('tapping one moves it to Completed, and back again (Round 30)',
      (tester) async {
    await start(tester, todo: const [
      TodoItem(id: 't1', text: 'One'),
      TodoItem(id: 't2', text: 'Two'),
    ]);
    await open(tester);
    expect(find.text('COMPLETED  ·  1'), findsNothing);
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(find.text('TO DO  ·  1'), findsOneWidget);
    expect(find.text('COMPLETED  ·  1'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Two')).dy,
        greaterThan(tester.getTopLeft(find.text('COMPLETED  ·  1')).dy));
    expect(container.read(todoProvider).firstWhere((i) => i.id == 't2').done,
        isTrue);

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(find.text('TO DO  ·  2'), findsOneWidget);
    expect(find.text('COMPLETED  ·  1'), findsNothing);
  });

  testWidgets('Delete completed: asked, then gone, with Undo', (tester) async {
    await start(tester, todo: const [
      TodoItem(id: 't1', text: 'Open'),
      TodoItem(id: 't2', text: 'Done', done: true),
    ]);
    await open(tester);
    await tester.tap(find.byTooltip('Delete completed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(texts(), ['Open']);
    expect(find.text('1 completed to-do deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(texts(), ['Open', 'Done']);
  });

  testWidgets('Delete completed does nothing with none done', (tester) async {
    await start(tester, todo: const [TodoItem(id: 't1', text: 'Open')]);
    await open(tester);
    await tester.tap(find.byTooltip('Delete completed'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing, reason: 'no dialog');
  });

  testWidgets('its buttons on the side of the hand in use (Round 30)',
      (tester) async {
    await start(tester);
    // Opened with the left hand: the buttons on the left.
    await tester.tapAt(tester.getCenter(tile) - const Offset(300, 0));
    await tester.pumpAndSettle();
    final screen = tester.getSize(find.byType(MaterialApp)).width;
    expect(tester.getCenter(find.byTooltip('Add a to-do')).dx,
        lessThan(screen / 2));
  });

  testWidgets('holding one changes its text', (tester) async {
    await start(tester, todo: const [TodoItem(id: 't1', text: 'Typo')]);
    await open(tester);
    await tester.longPress(find.text('Typo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fixed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(texts(), ['Fixed']);
  });

  testWidgets('not part of selecting notes', (tester) async {
    await start(tester);
    container.read(notesProvider.notifier).addNote(title: 'A note');
    await tester.pumpAndSettle();
    await tester.longPress(find.text('A note'));
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(appBarTitle('To-do'), findsNothing);
  });

  testWidgets('Settings turns it off (its list kept) and on', (tester) async {
    await start(tester, todo: const [TodoItem(id: 't1', text: 'Kept')]);
    await openMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todoNote')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tile, findsNothing);
    expect(texts(), ['Kept']);

    await start(tester,
        todo: const [TodoItem(id: 't1', text: 'Kept')],
        preferences: const Preferences(todoNote: false));
    expect(tile, findsNothing);
  });
}
