import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

import '../helpers.dart';

/// Settings → Clear data (D7): pick sections, type RESET, enter the master
/// password (if set), and they're emptied; the rest stays.
void main() {
  const password = 'master password';
  late ProviderContainer container;

  final clearButton = find.byKey(const Key('clearData'));

  /// A note, a shop item, a task, a routine, a reminder and a counter.
  void seed() {
    container.read(notesProvider.notifier).addNote(title: 'Plain');
    container.read(shopProvider.notifier).addItem('Milk');
    final day = DateTime(2026, 10, 12);
    container
        .read(plannerProvider.notifier)
        .addTask(day, 'Gym', start: 480, end: 540);
    container.read(routinesProvider.notifier).add(
        title: 'Pills',
        start: 1200,
        end: 1205,
        weekdays: {1, 2, 3, 4, 5, 6, 7},
        from: day);
    container.read(pinsProvider.notifier).add(day, 'Call', time: 600);
    container.read(countersProvider.notifier).add('Push-ups');
  }

  Future<void> openClearData(WidgetTester tester,
      {bool withPassword = false}) async {
    container = await pumpApp(tester);
    if (withPassword) {
      await tester.runAsync(() =>
          container.read(securityProvider.notifier).setPassword(password));
    }
    seed();
    await openMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear data'));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String section) async {
    await tester.tap(find.byKey(Key('clear-$section')));
    await tester.pump();
  }

  /// Clear, then type RESET in the dialog and confirm.
  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('clearConfirm')), 'delete');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear').last);
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<ButtonStyleButton>(button).onPressed != null;

  testWidgets('Clear waits for a pick; counts show per section',
      (tester) async {
    await openClearData(tester);
    expect(enabled(tester, clearButton), isFalse);
    expect(find.textContaining('3 items'), findsOneWidget,
        reason: 'the planner counts its task, routine and reminder');
    await pick(tester, 'notes');
    expect(enabled(tester, clearButton), isTrue);
  });

  testWidgets('without a password: RESET clears only the picked sections',
      (tester) async {
    await openClearData(tester);
    await pick(tester, 'notes');
    await pick(tester, 'planner');
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    final dialogClear = find.widgetWithText(FilledButton, 'Clear').last;
    expect(enabled(tester, dialogClear), isFalse);
    await tester.enterText(find.byKey(const Key('clearConfirm')), 'nope');
    await tester.pump();
    expect(enabled(tester, dialogClear), isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(notesProvider), hasLength(1), reason: 'cancelled');

    await confirm(tester);

    expect(container.read(notesProvider), isEmpty);
    expect(container.read(plannerProvider), isEmpty);
    expect(container.read(routinesProvider).routines, isEmpty);
    expect(container.read(pinsProvider), isEmpty);
    expect(container.read(shopProvider), hasLength(1));
    expect(container.read(countersProvider), hasLength(1));
    expect(find.text('Cleared Notes, Planner'), findsOneWidget);
  });

  testWidgets('with a password: wrong keeps everything, right clears',
      (tester) async {
    await openClearData(tester, withPassword: true);
    await pick(tester, 'shop');
    await pick(tester, 'counters');
    await confirm(tester);
    expect(find.byKey(const Key('promptPassword')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('promptPassword')), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Clear').last);
    await tester.pump();
    await settleBusy(tester);
    expect(find.text('Wrong password'), findsOneWidget);
    expect(container.read(shopProvider), hasLength(1));

    await tester.enterText(find.byKey(const Key('promptPassword')), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear').last);
    await tester.pump();
    await settleBusy(tester);

    expect(container.read(shopProvider), isEmpty);
    expect(container.read(countersProvider), isEmpty);
    expect(container.read(notesProvider), hasLength(1));
    expect(container.read(plannerProvider), hasLength(1));
  });

  testWidgets('with a password: cancelling the prompt clears nothing',
      (tester) async {
    await openClearData(tester, withPassword: true);
    await pick(tester, 'notes');
    await confirm(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(container.read(notesProvider), hasLength(1));
  });
}
