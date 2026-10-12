import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/placard.dart';
import 'package:the_app/pages/other/placard.dart';
import 'package:the_app/providers/placard_provider.dart';

import '../helpers.dart';

/// Placard (O4): sideways, no bars; hold to inflate, shake and pop a count;
/// five taps in the corner for its settings; back turns upright first.
void main() {
  late ProviderContainer container;
  late List<(String, Object?)> calls;

  final sign = find.byKey(const Key('placardSign'));
  final corner = find.byKey(const Key('placardCorner'));
  Placard placard() => container.read(placardProvider);

  /// Records orientation and system bar requests.
  void recordSystem(WidgetTester tester) {
    calls = [];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method.startsWith('SystemChrome.')) {
        calls.add((call.method, call.arguments));
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  List<Object?> requests(String method) => [
        for (final (m, args) in calls)
          if (m == 'SystemChrome.$method') args,
      ];

  Future<void> openPlacard(WidgetTester tester) async {
    container = await pumpApp(tester);
    recordSystem(tester);
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Placard'));
    await tester.pumpAndSettle();
  }

  /// Holds the page for [time], then lets go.
  Future<void> hold(WidgetTester tester, Duration time) async {
    final finger = await tester.startGesture(tester.getCenter(sign));
    await tester.pump();
    await tester.pump(time);
    await finger.up();
    await tester.pumpAndSettle();
  }

  testWidgets('fresh: "Add text here!", count 1; sideways, no bars',
      (tester) async {
    await openPlacard(tester);
    expect(find.text(Placard.defaultText), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(requests('setPreferredOrientations').last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    expect(requests('setEnabledSystemUIMode').last,
        'SystemUiMode.immersiveSticky');
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('a long enough hold counts once; a short one doesn\'t',
      (tester) async {
    await openPlacard(tester);
    await hold(tester, const Duration(milliseconds: 400));
    expect(placard().count, 1, reason: 'let go too early');

    await hold(tester, PlacardPage.holdTime + const Duration(seconds: 2));
    expect(placard().count, 2, reason: 'one per hold, however long');
    expect(find.text('2'), findsOneWidget);

    await tester.tap(sign);
    await tester.pumpAndSettle();
    expect(placard().count, 2, reason: 'a tap doesn\'t count');
  });

  testWidgets('while held it inflates; let go early, it goes back',
      (tester) async {
    await openPlacard(tester);
    // The page's own transforms (the route's are at 1 by now).
    double scale() => tester
        .widgetList<Transform>(find.ancestor(
          of: find.byKey(const Key('placardText')),
          matching: find.byType(Transform),
        ))
        .map((t) => t.transform.getMaxScaleOnAxis())
        .reduce((a, b) => a * b);

    expect(scale(), moreOrLessEquals(1));
    final finger = await tester.startGesture(tester.getCenter(sign));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(scale(), greaterThan(1.05));
    await finger.up();
    await tester.pumpAndSettle();
    expect(scale(), moreOrLessEquals(1));
  });

  testWidgets('five taps in the corner open the settings; four don\'t',
      (tester) async {
    await openPlacard(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(corner);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('Text'), findsNothing);

    await tester.tap(corner);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placardTextField')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('placardTextField')), 'Why so quiet?');
    await tester.enterText(find.byKey(const Key('placardCountField')), '41');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((placard().text, placard().count), ('Why so quiet?', 41));
    expect(find.text('Why so quiet?'), findsOneWidget);
  });

  testWidgets('settings: Reset fills in 0; a blank text is the default',
      (tester) async {
    await openPlacard(tester);
    container.read(placardProvider.notifier).set(text: 'Hi', count: 9);
    for (var i = 0; i < 5; i++) {
      await tester.tap(corner);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(placard().count, 9, reason: 'only filled in, not applied');
    await tester.enterText(find.byKey(const Key('placardTextField')), '  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((placard().text, placard().count), (Placard.defaultText, 0));
  });

  testWidgets('back: turns upright first, then closes', (tester) async {
    await openPlacard(tester);
    await pressBack(tester);
    expect(requests('setPreferredOrientations').last,
        ['DeviceOrientation.portraitUp']);
    expect(find.byKey(const Key('placardText')), findsOneWidget,
        reason: 'still there while it turns');

    // The phone turns.
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placardText')), findsNothing);
    expect(find.byTooltip('Placard'), findsOneWidget);
    expect(requests('setPreferredOrientations').last, isEmpty);
    expect(requests('setEnabledSystemUIMode').last, 'SystemUiMode.edgeToEdge');
  });

  testWidgets('back: closes anyway if the phone doesn\'t turn', (tester) async {
    await openPlacard(tester);
    await pressBack(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placardText')), findsNothing);
  });
}
