import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/counters_provider.dart';

import '../helpers.dart';

/// Other → Counters (O1, O2).
void main() {
  late ProviderContainer container;

  Map<String, int> values() =>
      {for (final c in container.read(countersProvider)) c.name: c.value};

  Future<void> openCounters(WidgetTester tester,
      {List<String> names = const []}) async {
    container = await pumpApp(tester);
    for (final name in names) {
      container.read(countersProvider.notifier).add(name);
    }
    await openTab(tester, 'Other');
    await tester.tap(find.text('Counters'));
    await tester.pumpAndSettle();
  }

  testWidgets('Other lists Counters; back returns to Other', (tester) async {
    await openCounters(tester);
    expect(appBarTitle('Counters'), findsOneWidget);
    expect(find.text('No counters'), findsOneWidget);

    await pressBack(tester);
    expect(appBarTitle('Other'), findsOneWidget);
  });

  testWidgets('+ adds a counter at 0', (tester) async {
    await openCounters(tester);
    await tester.tap(find.byTooltip('New counter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Push-ups');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(values(), {'Push-ups': 0});
    expect(find.text('Push-ups'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('the big buttons count up and down', (tester) async {
    await openCounters(tester, names: ['Push-ups', 'Coffee']);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Count up Push-ups'));
    }
    await tester.tap(find.byTooltip('Count down Coffee'));
    await tester.pump();

    expect(values(), {'Push-ups': 3, 'Coffee': -1});
    expect(find.text('3'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
  });

  testWidgets('while selecting, the buttons select instead of counting',
      (tester) async {
    await openCounters(tester, names: ['Push-ups']);
    await tester.longPress(find.text('Push-ups'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Count up Push-ups'), warnIfMissed: false);
    await tester.pump();

    expect(values(), {'Push-ups': 0});
  });

  testWidgets('selection: rename one, reset and delete with confirmation',
      (tester) async {
    await openCounters(tester, names: ['Pushups', 'Coffee', 'Water']);
    for (final name in ['Pushups', 'Coffee', 'Water']) {
      final id =
          container.read(countersProvider).firstWhere((c) => c.name == name).id;
      container.read(countersProvider.notifier).step(id, 5);
    }
    await tester.pump();

    // Rename: only with one selected.
    await tester.longPress(find.text('Pushups'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Push-ups');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(values(), {'Push-ups': 5, 'Coffee': 5, 'Water': 5});

    // Reset two.
    await tester.longPress(find.text('Push-ups'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Rename'), findsNothing);
    await tester.tap(find.byTooltip('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Reset 2 counters?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(values(), {'Push-ups': 0, 'Coffee': 0, 'Water': 5});

    // Delete one.
    await tester.longPress(find.text('Water'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(values(), {'Push-ups': 0, 'Coffee': 0});
  });
}
