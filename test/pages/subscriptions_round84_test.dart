import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/providers/subscriptions_alerts_provider.dart';

import '../helpers.dart';

/// Round 84: a card's expiry coloured on its subscription's
/// card: orange a week or less ahead, red once gone by. No notification.
/// Round 85: an expiry is a month (good through its last day).
void main() {
  final now = DateTime(2026, 10, 26, 12);
  final today = DateTime(2026, 10, 26);

  Subscription sub(String id, DateTime? expires, {String card = 'Visa'}) =>
      Subscription(
          id: id,
          name: id,
          price: 5,
          date: DateTime(2026, 11, 3),
          card: card,
          cardExpires: expires);

  test('how its card stands: fine, soon (a week or less), expired', () {
    // A card expiring in October 2026: good through the 31st.
    CardExpiry on(DateTime day) =>
        sub('a', DateTime(2026, 10)).cardExpiryOn(day);
    expect(sub('a', null).cardExpiryOn(now), CardExpiry.fine);
    expect(on(DateTime(2026, 10, 23, 12)), CardExpiry.fine, reason: '8 days');
    expect(on(DateTime(2026, 10, 24)), CardExpiry.soon, reason: 'a week');
    expect(on(DateTime(2026, 10, 31, 23)), CardExpiry.soon,
        reason: 'its last day');
    expect(on(DateTime(2026, 11, 1)), CardExpiry.expired);
  });

  test('its labels: the month as on cards, the expiry its own part', () {
    final s = sub('a', DateTime(2026, 10, 25), card: 'Virtual 0912');
    expect(cardLabel(s, today), 'Virtual 0912 · expires 10/26');
    expect(cardExpiryLabel(s, today), 'expires 10/26');
    expect(cardExpiryLabel(sub('b', DateTime(2026, 9, 18)), today),
        'expired 09/26');
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
          sub('soon', DateTime(2026, 10), card: 'Virtual 0912'),
          sub('gone', DateTime(2026, 9)),
          sub('later', DateTime(2027, 3)),
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
    expect(find.text('Virtual 0912 · expires\u00A010/26', findRichText: true),
        findsOneWidget);
    expect(expiryColour('gone'), colors.danger);
    expect(find.byKey(const Key('subscriptionCardExpiry-later')), findsNothing);
    expect(find.text('Visa · expires 03/27'), findsOneWidget);
    expect(find.text('Visa'), findsOneWidget, reason: 'no expiry: plain');
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets(
        'Round 85: its icons centred on their text\'s first line (text at '
        '$scale)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester,
          clock: () => now,
          subscriptions: SubscriptionBook([
            sub('a', DateTime(2027, 3)).copyWith(remindBefore: () => 2),
          ]));
      await openTab(tester, 'Hub');
      await tester.tap(find.byTooltip('Subscriptions'));
      await tester.pumpAndSettle();
      for (final (key, icon) in [
        ('subscriptionCard-a', Icons.credit_card),
        ('subscriptionRemind-a', Icons.notifications_none),
      ]) {
        final line = find.byKey(Key(key));
        final iconBox = tester
            .getRect(find.descendant(of: line, matching: find.byIcon(icon)));
        final text = tester.renderObject<RenderParagraph>(
            find.descendant(of: line, matching: find.byType(RichText)).last);
        final textTop = text.localToGlobal(Offset.zero).dy;
        final firstLine = text
            .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 1))
            .first;
        final lineMiddle = textTop + (firstLine.top + firstLine.bottom) / 2;
        expect(iconBox.center.dy, closeTo(lineMiddle, 1),
            reason: '$key at $scale');
      }
    });
  }
}
