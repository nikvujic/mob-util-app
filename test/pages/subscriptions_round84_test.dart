import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/providers/subscriptions_alerts_provider.dart';

import '../helpers.dart';

/// Round 84 (Nikola): a card's expiry coloured on its subscription's
/// card: orange a week or less ahead, red once gone by. No notification.
void main() {
  final now = DateTime(2026, 10, 20, 12);
  final today = DateTime(2026, 10, 20);

  Subscription sub(String id, DateTime? expires, {String card = 'Visa'}) =>
      Subscription(
          id: id,
          name: id,
          price: 5,
          date: DateTime(2026, 11, 3),
          card: card,
          cardExpires: expires);

  test('how its card stands: fine, soon (a week or less), expired', () {
    CardExpiry on(DateTime? expires) => sub('a', expires).cardExpiryOn(now);
    expect(on(null), CardExpiry.fine);
    expect(on(DateTime(2026, 10, 28)), CardExpiry.fine, reason: '8 days');
    expect(on(DateTime(2026, 10, 27)), CardExpiry.soon, reason: 'a week');
    expect(on(today), CardExpiry.soon, reason: 'today');
    expect(on(DateTime(2026, 10, 19)), CardExpiry.expired);
  });

  test('its labels as before, the expiry its own part', () {
    final s = sub('a', DateTime(2026, 10, 25), card: 'Virtual 0912');
    expect(cardLabel(s, today), 'Virtual 0912 · expires 25 Oct');
    expect(cardExpiryLabel(s, today), 'expires 25 Oct');
    expect(cardExpiryLabel(sub('b', DateTime(2026, 10, 18)), today),
        'expired 18 Oct');
    expect(cardExpiryLabel(sub('c', null), today), isNull);
    expect(cardLabel(sub('d', null), today), 'Visa');
  });

  testWidgets('on the cards: the expiry orange soon, red expired, plain later',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await pumpApp(tester,
        clock: () => now,
        subscriptions: SubscriptionBook([
          sub('soon', DateTime(2026, 10, 25), card: 'Virtual 0912'),
          sub('gone', DateTime(2026, 10, 18)),
          sub('later', DateTime(2027, 3, 31)),
          sub('none', null),
        ]));
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Subscriptions'));
    await tester.pumpAndSettle();

    final colors = tester.element(find.byType(Scaffold).first).colors;
    Color? expiryColour(String id) {
      final text =
          tester.widget<Text>(find.byKey(Key('subscriptionCardExpiry-$id')));
      final parts = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(parts.first.text, id == 'soon' ? 'Virtual 0912 · ' : 'Visa · ');
      return parts.last.style!.color;
    }

    expect(expiryColour('soon'), SubscriptionColours.toCancel);
    expect(find.text('Virtual 0912 · expires 25 Oct', findRichText: true),
        findsOneWidget);
    expect(expiryColour('gone'), colors.danger);
    expect(find.byKey(const Key('subscriptionCardExpiry-later')), findsNothing);
    expect(find.text('Visa · expires 31 Mar 2027'), findsOneWidget);
    expect(find.text('Visa'), findsOneWidget, reason: 'no expiry: plain');
  });
}
