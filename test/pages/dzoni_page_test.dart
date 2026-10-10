import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/pages/other/dzoni.dart';
import 'package:the_app/providers/preferences_provider.dart';

import '../helpers.dart';

/// Other: the tool tiles (O3) and the "Džoni" page (O4).
void main() {
  late ProviderContainer container;

  /// Orientation requests the app makes, recorded.
  List<List<dynamic>> recordOrientations(WidgetTester tester) {
    final calls = <List<dynamic>>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        calls.add(call.arguments as List<dynamic>);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return calls;
  }

  testWidgets('tools are icon tiles, the first one in the bottom right',
      (tester) async {
    container = await pumpApp(tester);
    await openTab(tester, 'Other');

    final size = tester.getSize(find.byType(MaterialApp));
    final counters = tester.getRect(find.byTooltip('Counters'));
    final dzoni = tester.getRect(find.byTooltip('Džoni'));
    expect(counters.width, counters.height, reason: 'square');
    expect(counters.center.dx, greaterThan(size.width * 0.8));
    expect(counters.center.dy, greaterThan(size.height * 0.6));
    expect(dzoni.center.dx, lessThan(counters.center.dx),
        reason: 'next, leftwards');
    expect(find.text('Counters'), findsNothing, reason: 'no titles');
  });

  testWidgets('Džoni: sideways while open, holding counts up, kept',
      (tester) async {
    container = await pumpApp(tester);
    final orientations = recordOrientations(tester);
    await openTab(tester, 'Other');
    await tester.tap(find.byTooltip('Džoni'));
    await tester.pumpAndSettle();

    expect(find.text(DzoniPage.text), findsOneWidget);
    expect(orientations.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    expect(find.text('0'), findsOneWidget);

    // Anywhere on the page, one count per hold.
    await tester.longPressAt(const Offset(50, 300));
    await tester.pumpAndSettle();
    await tester.longPress(find.text(DzoniPage.text));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(container.read(preferencesProvider).dzoniCount, 2);

    // A tap doesn't count.
    await tester.tap(find.text(DzoniPage.text));
    await tester.pumpAndSettle();
    expect(container.read(preferencesProvider).dzoniCount, 2);

    expect(find.byType(AppBar), findsNothing, reason: 'no top bar');
    await pressBack(tester);
    expect(orientations.last, isEmpty, reason: 'back to any orientation');
    expect(find.byTooltip('Džoni'), findsOneWidget);
  });

  group('setting the count (triple tap in the top-right corner)', () {
    late DateTime now;
    final corner = find.byKey(const Key('dzoniCorner'));

    Future<void> openPage(WidgetTester tester) async {
      recordOrientations(tester);
      now = DateTime(2026, 10, 10, 12);
      container = await pumpApp(tester, clock: () => now);
      container.read(preferencesProvider.notifier).setDzoniCount(42);
      await openTab(tester, 'Other');
      await tester.tap(find.byTooltip('Džoni'));
      await tester.pumpAndSettle();
    }

    /// Taps the corner [times] times, [gap] apart.
    Future<void> tapCorner(WidgetTester tester, int times,
        {Duration gap = const Duration(milliseconds: 150)}) async {
      for (var i = 0; i < times; i++) {
        now = now.add(gap);
        await tester.tap(corner);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
    }

    Future<void> openSetCount(WidgetTester tester) async {
      await openPage(tester);
      await tapCorner(tester, 3);
    }

    int count() => container.read(preferencesProvider).dzoniCount;
    final field = find.byKey(const Key('dzoniCount'));

    testWidgets('the corner is the top right of the screen', (tester) async {
      await openPage(tester);
      final size = tester.getSize(find.byType(MaterialApp));
      final rect = tester.getRect(corner);
      expect(rect.right, size.width);
      expect(rect.top, lessThan(50));
      expect(rect.width, greaterThanOrEqualTo(48));
    });

    testWidgets('one or two taps, or slow ones, do nothing', (tester) async {
      await openPage(tester);
      await tapCorner(tester, 2);
      expect(find.text('Set count'), findsNothing);
      await tapCorner(tester, 3, gap: const Duration(milliseconds: 600));
      expect(find.text('Set count'), findsNothing);
      expect(count(), 42, reason: 'taps never count');
    });

    testWidgets('three quick taps open it; sets the count typed in',
        (tester) async {
      await openSetCount(tester);
      expect(tester.widget<TextField>(field).controller!.text, '42');

      await tester.enterText(field, '7');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(count(), 7);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('Reset fills in 0, applied only by Save', (tester) async {
      await openSetCount(tester);
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, '0');
      expect(count(), 42, reason: 'not yet');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(count(), 0);
    });

    testWidgets('Cancel and an empty field change nothing', (tester) async {
      await openSetCount(tester);
      await tester.enterText(field, '');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter a whole number, 0 or more'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(count(), 42);
    });

    testWidgets('holding the page still counts, even in the corner',
        (tester) async {
      await openPage(tester);
      await tester.longPress(find.text('42'));
      await tester.pumpAndSettle();
      await tester.longPress(corner);
      await tester.pumpAndSettle();
      expect(count(), 44);
      expect(find.text('Set count'), findsNothing);
    });
  });
}
