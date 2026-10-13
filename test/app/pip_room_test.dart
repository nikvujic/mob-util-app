import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/providers/pip_provider.dart';

import '../helpers.dart';

/// Pip's room at the bottom of the menu (Round 26).
void main() {
  final room = find.byKey(const Key('pipRoom'));

  testWidgets('in the menu, under the items, above the version',
      (tester) async {
    final container = await pumpApp(tester);
    await openMenu(tester);
    expect(room, findsOneWidget);
    expect(tester.getTopLeft(room).dy,
        greaterThan(tester.getBottomLeft(find.text('Settings')).dy));
    expect(
        tester.getBottomLeft(room).dy,
        lessThanOrEqualTo(
            tester.getTopLeft(find.textContaining('Version')).dy));
    // Not moving (here, in tests): simply standing there.
    expect(container.read(pipBrainProvider).spawned, isTrue);
  });

  group('moving', () {
    late ProviderContainer container;
    PipBrain pip() => container.read(pipBrainProvider);

    Future<void> openMenuMoving(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Menu').first);
      // Frames by hand: he never settles.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> closeMenu(WidgetTester tester) async {
      await tester.tapAt(const Offset(780, 300)); // beside the menu
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets(
        'the first time the menu opens he comes out of the ground; the next '
        'time he is where he was', (tester) async {
      container = await pumpApp(tester, pipMoves: true);
      expect(pip().activity, PipActivity.spawning, reason: 'not yet seen');

      await openMenuMoving(tester);
      expect(pip().activity, PipActivity.spawning);
      expect(pip().roomWidth, greaterThan(PipBrain.width));
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(pip().spawned, isTrue, reason: 'out, after about 2 s');

      await closeMenu(tester);
      expect(room, findsNothing);
      final x = pip().x;
      await tester.pumpAndSettle(); // nothing moves while it's closed
      expect(pip().x, x);

      await openMenuMoving(tester);
      expect(pip().activity, isNot(PipActivity.spawning),
          reason: 'only the first time');
    });

    testWidgets('the phone set to remove animations: he just stands',
        (tester) async {
      container = await pumpApp(tester, pipMoves: true);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await openMenu(tester); // settles: nothing animates
      expect(pip().spawned, isTrue);
    });
  });
}
