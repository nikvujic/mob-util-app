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

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(orientations.last, isEmpty, reason: 'back to any orientation');
    expect(find.byTooltip('Džoni'), findsOneWidget);
  });
}
