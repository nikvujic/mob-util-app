import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/providers/subscriptions_provider.dart';

import '../helpers.dart';

/// Round 89: subscriptions' cards held and dragged to a new
/// place, as the Hub's tiles; their order is kept.
void main() {
  Subscription sub(String id) =>
      Subscription(id: id, name: id, price: 5, date: DateTime(2026, 11, 3));

  test('moveTo: one taken out and put at a place; out of range: nothing', () {
    final n = SubscriptionsNotifier(AppStorage.inMemory(
        initialSubscriptions:
            SubscriptionBook([sub('A'), sub('B'), sub('C'), sub('D')])));
    List<String> ids() => n.state.subscriptions.map((s) => s.id).toList();
    n.moveTo('A', 2);
    expect(ids(), ['B', 'C', 'A', 'D']);
    n.moveTo('D', 0);
    expect(ids(), ['D', 'B', 'C', 'A']);
    n.moveTo('B', 4);
    n.moveTo('B', 9);
    n.moveTo('B', -1);
    n.moveTo('nope', 0);
    expect(ids(), ['D', 'B', 'C', 'A']);
    // A new one goes last.
    n.save(sub('E'));
    expect(ids().last, 'E');
  });

  late ProviderContainer container;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container = await pumpApp(tester,
        clock: () => DateTime(2026, 10, 20, 12),
        subscriptions: SubscriptionBook(
            [sub('Grok'), sub('AWS'), sub('Claude'), sub('Spotify')]));
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Subscriptions'));
    await tester.pumpAndSettle();
  }

  List<String> order() => container
      .read(subscriptionsProvider)
      .subscriptions
      .map((s) => s.id)
      .toList();

  testWidgets('shown in their order (not by state), two to a row',
      (tester) async {
    await open(tester);
    final grok = tester.getRect(find.byKey(const ValueKey('Grok')));
    final aws = tester.getRect(find.byKey(const ValueKey('AWS')));
    final claude = tester.getRect(find.byKey(const ValueKey('Claude')));
    expect(aws.top, grok.top);
    expect(aws.left, greaterThan(grok.right));
    expect(claude.top, greaterThan(grok.bottom));
  });

  testWidgets(
      'held and dragged over another: takes its place; a tap still opens '
      'it', (tester) async {
    await open(tester);
    final from = tester.getCenter(find.byKey(const ValueKey('Grok')));
    final to = tester.getCenter(find.byKey(const ValueKey('Claude')));
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(Offset.lerp(from, to, 0.5)!);
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(order(), ['AWS', 'Claude', 'Grok', 'Spotify']);

    await tester.tap(find.byKey(const ValueKey('Spotify')));
    await tester.pumpAndSettle();
    expect(find.text('Subscription'), findsOneWidget, reason: 'its page');
  });

  testWidgets('screen readers: Move earlier / Move later', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    void act(String id, String label) {
      final node = tester.getSemantics(find.text(id));
      node.owner!.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(
              CustomSemanticsAction(label: label)));
    }

    act('AWS', 'Move later');
    await tester.pumpAndSettle();
    expect(order(), ['Grok', 'Claude', 'AWS', 'Spotify']);
    act('AWS', 'Move earlier');
    await tester.pumpAndSettle();
    expect(order(), ['Grok', 'AWS', 'Claude', 'Spotify']);
    semantics.dispose();
  });
}
