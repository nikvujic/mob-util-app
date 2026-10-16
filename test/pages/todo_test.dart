import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/todo_provider.dart';
import 'package:the_app/widgets/selection.dart';

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

  testWidgets(
      'Delete all, beside Completed: asked, then gone, no Undo (Round 33)',
      (tester) async {
    await start(tester, todo: const [
      TodoItem(id: 't1', text: 'Open'),
      TodoItem(id: 't2', text: 'Done', done: true),
    ]);
    await open(tester);
    final deleteAll = find.byKey(const Key('deleteCompleted'));
    expect(
        (tester.getCenter(deleteAll).dy -
                tester.getCenter(find.text('COMPLETED  ·  1')).dy)
            .abs(),
        lessThan(8),
        reason: 'on the header\'s line');
    await tester.tap(deleteAll);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(texts(), ['Open']);
    expect(find.text('Undo'), findsNothing, reason: 'it said it can\'t be');
  });

  testWidgets('none done: no Completed, no Delete all', (tester) async {
    await start(tester, todo: const [TodoItem(id: 't1', text: 'Open')]);
    await open(tester);
    expect(find.byKey(const Key('deleteCompleted')), findsNothing);
  });

  testWidgets('a done one can\'t be changed by holding it (Round 33)',
      (tester) async {
    await start(tester,
        todo: const [TodoItem(id: 't1', text: 'Done', done: true)]);
    await open(tester);
    await tester.longPress(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('+ looks like the other pages\' add button (Round 33)',
      (tester) async {
    await start(tester);
    await open(tester);
    final add = tester.widget<FloatingActionButton>(find.ancestor(
      of: find.byIcon(Icons.add),
      matching: find.byType(FloatingActionButton),
    ));
    expect(add.backgroundColor, isNull, reason: 'the theme\'s, as Notes');
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
    // Round 58: under Introduction after updates.
    expect(
        tester.getTopLeft(find.byKey(const Key('todoNote'))).dy,
        greaterThan(
            tester.getTopLeft(find.byKey(const Key('introOnUpdates'))).dy));
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

  group('options (Round 45)', () {
    Future<void> options(WidgetTester tester) async {
      await tester.tap(find.byTooltip('To-do options'));
      await tester.pumpAndSettle();
    }

    Finder handleOf(String id) => find.descendant(
        of: find.byKey(ValueKey(id)),
        matching: find.byType(ReorderOrSelectIndicator));

    bool waiting(String id) =>
        container.read(todoProvider).firstWhere((i) => i.id == id).waiting;

    testWidgets('a button beside Add; the Waiting list turned on and off',
        (tester) async {
      await start(tester, todo: const [TodoItem(id: 't1', text: 'One')]);
      await open(tester);
      expect(
          (tester.getCenter(find.byTooltip('To-do options')).dy -
                  tester.getCenter(find.byTooltip('Add a to-do')).dy)
              .abs(),
          lessThan(1),
          reason: 'beside it');
      expect(find.textContaining('WAITING'), findsNothing);
      await options(tester);
      await tester.tap(find.byKey(const Key('todoWaiting')));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).todoWaiting, isTrue);
      await tester.tapAt(const Offset(200, 100)); // closes the sheet
      await tester.pumpAndSettle();
      expect(find.text('WAITING  ·  0'), findsOneWidget);
      expect(find.text("Drag here what you're waiting on"), findsOneWidget);
    });

    testWidgets('dragged from To do into Waiting and back', (tester) async {
      await start(tester,
          todo: const [
            TodoItem(id: 't1', text: 'One'),
            TodoItem(id: 't2', text: 'Two'),
          ],
          preferences: const Preferences(todoWaiting: true));
      await open(tester);
      Future<void> drag(String id, Offset to) async {
        final from = tester.getCenter(handleOf(id));
        final gesture = await tester.startGesture(from);
        await tester.pump(const Duration(milliseconds: 100));
        for (var i = 1; i <= 10; i++) {
          await gesture
              .moveTo(Offset.lerp(from, Offset(from.dx, to.dy), i / 10)!);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(milliseconds: 500));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await drag(
          't1',
          tester.getBottomLeft(find.text('WAITING  ·  0')) +
              const Offset(0, 40));
      expect(waiting('t1'), isTrue);
      expect(waiting('t2'), isFalse);
      expect(find.text('WAITING  ·  1'), findsOneWidget);
      expect(find.byKey(const Key('waiting-t1')), findsOneWidget,
          reason: 'an hourglass');
      expect(tester.getTopLeft(find.text('One')).dy,
          greaterThan(tester.getTopLeft(find.text('WAITING  ·  1')).dy));

      // Back up, above Two.
      await drag(
          't1', tester.getTopLeft(find.text('Two')) - const Offset(0, 10));
      expect(waiting('t1'), isFalse);
      expect(texts(), ['One', 'Two']);
    });

    testWidgets('a tap on a waiting one still completes it', (tester) async {
      await start(tester,
          todo: const [TodoItem(id: 't1', text: 'Parcel', waiting: true)],
          preferences: const Preferences(todoWaiting: true));
      await open(tester);
      await tester.tap(find.text('Parcel'));
      await tester.pumpAndSettle();
      expect(find.text('COMPLETED  ·  1'), findsOneWidget);
      expect(find.text('WAITING  ·  0'), findsOneWidget);
    });

    testWidgets('the list off: waiting ones show with the rest, still marked',
        (tester) async {
      await start(tester, todo: const [
        TodoItem(id: 't1', text: 'One'),
        TodoItem(id: 't2', text: 'Parcel', waiting: true),
      ]);
      await open(tester);
      expect(find.text('TO DO  ·  2'), findsOneWidget);
      expect(find.textContaining('WAITING'), findsNothing);
      Finder hourglass(String id) => find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byIcon(Icons.hourglass_empty));
      expect(hourglass('t2'), findsOneWidget);
      expect(hourglass('t1'), findsNothing);
    });

    testWidgets("the card names one to do first, not one that's waiting",
        (tester) async {
      await start(tester, todo: const [
        TodoItem(id: 't1', text: 'Parcel', waiting: true),
        TodoItem(id: 't2', text: 'Call mum'),
      ]);
      expect(tester.widget<Text>(find.byKey(const Key('todoSummary'))).data,
          'Call mum');
      expect(tester.widget<Text>(find.byKey(const Key('todoCount'))).data, '2');
    });

    group('the lock', () {
      const password = 'password1';

      Future<void> withPassword(WidgetTester tester) async {
        await tester.runAsync(() async {
          await container.read(securityProvider.notifier).setPassword(password);
          await container.read(sessionProvider.notifier).unlock(password);
        });
        await tester.pumpAndSettle();
      }

      testWidgets('no master password: it says to set one', (tester) async {
        await start(tester);
        await open(tester);
        await options(tester);
        expect(find.text('Set a master password first'), findsOneWidget);
        await tester.tap(find.byKey(const Key('todoLock')));
        await tester.pumpAndSettle();
        expect(container.read(todoLockProvider), isFalse);
      });

      testWidgets(
          'locked, the app locking closes it; the card hides what it holds; '
          'the password opens it', (tester) async {
        await start(tester, todo: const [TodoItem(id: 't1', text: 'Secret')]);
        await withPassword(tester);
        await open(tester);
        await options(tester);
        await tester.tap(find.byKey(const Key('todoLock')));
        await tester.pumpAndSettle();
        expect(container.read(todoLockProvider), isTrue);
        expect(find.text('Secret'), findsOneWidget, reason: 'unlocked still');

        container.read(sessionProvider.notifier).lock();
        await tester.pumpAndSettle();
        expect(find.text('Secret'), findsNothing);
        expect(appBarTitle('To-do'), findsNothing, reason: 'closed, back home');
        expect(find.byKey(const Key('promptPassword')), findsNothing,
            reason: 'Round 61: no prompt left over the notes');
        expect(tester.widget<Text>(find.byKey(const Key('todoSummary'))).data,
            'Locked');
        expect(find.byKey(const Key('todoCount')), findsNothing);

        await open(tester);
        expect(find.text('To-do is locked'), findsOneWidget);
        expect(find.text('Secret'), findsNothing);
        // Round 61: it asks at once (the fingerprint first, if set).
        expect(find.byKey(const Key('promptPassword')), findsOneWidget);
        await tester.enterText(
            find.byKey(const Key('promptPassword')), password);
        await tester.tap(find.text('Unlock').last);
        await settleBusy(tester);
        expect(find.text('Secret'), findsOneWidget);
      });

      testWidgets('turned off again from the same switch', (tester) async {
        await start(tester);
        await withPassword(tester);
        container.read(todoLockProvider.notifier).lock();
        await open(tester);
        await options(tester);
        await tester.tap(find.byKey(const Key('todoLock')));
        await tester.pumpAndSettle();
        expect(container.read(todoLockProvider), isFalse);
      });
    });
  });
}
