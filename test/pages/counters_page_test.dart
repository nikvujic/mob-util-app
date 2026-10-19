import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/providers/preferences_provider.dart';

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
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Counters'));
    await tester.pumpAndSettle();
  }

  testWidgets('Other lists Counters; back returns to Other', (tester) async {
    await openCounters(tester);
    expect(appBarTitle('Counters'), findsOneWidget);
    expect(find.text('No counters'), findsOneWidget);

    await pressBack(tester);
    expect(appBarTitle('Hub'), findsOneWidget);
  });

  testWidgets('+ adds a counter at 0', (tester) async {
    await openCounters(tester);
    await tester.tap(find.byTooltip('New counter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('counterName')), 'Push-ups');
    await tester.pump();
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

  testWidgets('selection: edit one, reset and delete with confirmation',
      (tester) async {
    await openCounters(tester, names: ['Pushups', 'Coffee', 'Water']);
    for (final name in ['Pushups', 'Coffee', 'Water']) {
      final id =
          container.read(countersProvider).firstWhere((c) => c.name == name).id;
      container.read(countersProvider.notifier).step(id, 5);
    }
    await tester.pump();

    // Edit: only with one selected.
    await tester.longPress(find.text('Pushups'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('counterName')), 'Push-ups');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(values(), {'Push-ups': 5, 'Coffee': 5, 'Water': 5});

    // Reset two.
    await tester.longPress(find.text('Push-ups'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit'), findsNothing);
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

  group('click and vibration (U6)', () {
    /// Platform calls for haptics and sounds, recorded.
    List<String> recordFeedback(WidgetTester tester) {
      final calls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.method);
        return null;
      });
      // The app's own click (not Android's touch sound, often off).
      const sound = MethodChannel('the_app/sound');
      messenger.setMockMethodCallHandler(sound, (call) async {
        calls.add('click');
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(sound, null);
      });
      return calls;
    }

    testWidgets('opening the page wakes the sound, silently (Round 18)',
        (tester) async {
      final sounds = <String>[];
      const sound = MethodChannel('the_app/sound');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(sound,
          (call) async {
        sounds.add(call.method);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(sound, null));
      await openCounters(tester, names: ['Push-ups']);
      expect(sounds, ['warm']);

      // Not with the feedback off.
      sounds.clear();
      container.read(preferencesProvider.notifier).setCounterFeedback(false);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Counters'));
      await tester.pumpAndSettle();
      expect(sounds, isEmpty);
    });

    testWidgets('each − / + clicks and vibrates', (tester) async {
      await openCounters(tester, names: ['Push-ups']);
      final calls = recordFeedback(tester);

      await tester.tap(find.byTooltip('Count up Push-ups'));
      await tester.tap(find.byTooltip('Count down Push-ups'));
      await tester.pump();

      expect(calls.where((c) => c == 'HapticFeedback.vibrate'), hasLength(2));
      expect(calls.where((c) => c == 'click'), hasLength(2));
      // Not Android's touch sound, which is silent with touch sounds off.
      expect(calls, isNot(contains('SystemSound.play')));
    });

    testWidgets('switched off in Settings: silent and still', (tester) async {
      await openCounters(tester, names: ['Push-ups']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openMenu(tester);
      // Round 70: below Internet Access, scrolled to on a short screen.
      await scrollMenuTo(tester, 'Settings');
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Counter click and vibration'));
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider).counterFeedback, isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await pressBack(tester); // the menu, still open behind Settings
      await tester.tap(find.byTooltip('Counters'));
      await tester.pumpAndSettle();
      final calls = recordFeedback(tester);

      await tester.tap(find.byTooltip('Count up Push-ups'));
      await tester.pump();

      expect(calls, isEmpty);
      expect(values(), {'Push-ups': 1}, reason: 'still counts');
    });
  });

  testWidgets('selection mode has no ✕: back leaves it', (tester) async {
    await openCounters(tester, names: ['Push-ups']);
    await tester.longPress(find.text('Push-ups'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.byTooltip('Cancel selection'), findsNothing);

    await pressBack(tester);
    expect(find.byTooltip('Delete'), findsNothing, reason: 'selection left');
    expect(find.text('Push-ups'), findsOneWidget, reason: 'still on Counters');
  });

  group('options (O5)', () {
    Future<void> fill(WidgetTester tester, String key, String text) =>
        tester.enterText(find.byKey(Key(key)), text);

    testWidgets('a new counter with a step, limits and a colour',
        (tester) async {
      await openCounters(tester);
      await tester.tap(find.byTooltip('New counter'));
      await tester.pumpAndSettle();
      await fill(tester, 'counterName', 'Pages');
      await fill(tester, 'counterStep', '5');
      await fill(tester, 'counterMin', '0');
      await fill(tester, 'counterMax', '10');
      await tester.tap(find.bySemanticsLabel('Colour: Teal'));
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final c = container.read(countersProvider).single;
      expect((c.step, c.min, c.max, c.color), (5, 0, 10, 'teal'));
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('−5'), findsOneWidget);
      expect(find.textContaining('0–10', findRichText: true), findsOneWidget);

      await tester.tap(find.byTooltip('Count up Pages by 5'));
      await tester.tap(find.byTooltip('Count up Pages by 5'));
      await tester.pump();
      expect(values(), {'Pages': 10});
      final up = tester.widget<IconButton>(find.ancestor(
        of: find.text('+5'),
        matching: find.byType(IconButton),
      ));
      expect(up.onPressed, isNull, reason: 'at its max');
    });

    testWidgets('Add waits for a name and sensible numbers', (tester) async {
      await openCounters(tester);
      await tester.tap(find.byTooltip('New counter'));
      await tester.pumpAndSettle();
      bool enabled() =>
          tester
              .widget<FilledButton>(find.byKey(const Key('counterSubmit')))
              .onPressed !=
          null;
      expect(enabled(), isFalse, reason: 'no name yet');
      await fill(tester, 'counterName', 'Laps');
      await tester.pump();
      expect(enabled(), isTrue);
      await fill(tester, 'counterStep', '0');
      await tester.pump();
      expect(enabled(), isFalse);
      expect(find.text('At least 1'), findsOneWidget);
      await fill(tester, 'counterStep', '2');
      await fill(tester, 'counterMin', '-');
      await tester.pump();
      expect(enabled(), isFalse, reason: 'a lone minus is no number');
    });

    testWidgets('editing shows its options', (tester) async {
      await openCounters(tester);
      container.read(countersProvider.notifier).add('Laps',
          options: (name: 'Laps', step: 2, color: 'pink', min: null, max: 40));
      await tester.pump();
      await tester.longPress(find.textContaining('Laps', findRichText: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      String field(String key) =>
          tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
      expect((field('counterStep'), field('counterMin'), field('counterMax')),
          ('2', '', '40'));
    });
  });

  group('look (Round 14)', () {
    testWidgets('every card the same height, limits or not', (tester) async {
      await openCounters(tester);
      container.read(countersProvider.notifier)
        ..add('Plain')
        ..add('Ruled',
            options: (name: 'Ruled', step: 5, color: 'teal', min: 0, max: 50));
      await tester.pump();
      double height(String name) => tester
          .getSize(find.ancestor(
            of: find.textContaining(name, findRichText: true),
            matching: find.byType(SelectableCard),
          ))
          .height;
      expect(height('Ruled'), height('Plain'));
    });

    testWidgets('− / + in the counter\'s vivid colour, else the app\'s grey',
        (tester) async {
      await openCounters(tester);
      container.read(countersProvider.notifier)
        ..add('Plain')
        ..add('Teal', options: (
          name: 'Teal',
          step: 1,
          color: 'teal',
          min: null,
          max: null
        ));
      await tester.pump();
      Color? background(String tooltip) => tester
          .widget<IconButton>(find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          ))
          .style!
          .backgroundColor!
          .resolve({});
      final palette = Theme.of(tester.element(find.byType(Scaffold).first))
          .extension<AppPalette>()!;
      expect(background('Count up Teal'), BlockColor.teal.stripe);
      expect(background('Count up Plain'), palette.menu);
    });

    testWidgets('Min and Max have no placeholder text', (tester) async {
      await openCounters(tester);
      await tester.tap(find.byTooltip('New counter'));
      await tester.pumpAndSettle();
      expect(find.text('none'), findsNothing);
    });
  });
}
