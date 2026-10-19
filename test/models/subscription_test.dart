import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/providers/subscriptions_alerts_provider.dart';

/// Subscriptions (Round 79, `docs/SUBSCRIPTIONS_SPEC.md`).
void main() {
  /// Monday, 19 October 2026.
  final today = DateTime(2026, 10, 19);
  DateTime day(int month, int d, [int year = 2026]) => DateTime(year, month, d);

  Subscription sub(
    String name, {
    double? price = 20,
    bool about = false,
    String currency = '€',
    SubscriptionEvery every = SubscriptionEvery.month,
    SubscriptionState state = SubscriptionState.active,
    DateTime? date,
    int? remindBefore,
  }) =>
      Subscription(
        id: name,
        name: name,
        price: price,
        about: about,
        currency: currency,
        every: every,
        state: state,
        date: date,
        remindBefore: remindBefore,
      );

  group('its date', () {
    test('renewing: moves on a month (or a year) once gone by', () {
      final s = sub('Claude', date: day(9, 3));
      expect(s.dateOn(today), day(11, 3));
      expect(s.dateOn(day(11, 3)), day(11, 3), reason: 'today: today');
      expect(s.dateOn(day(11, 4)), day(12, 3));
      expect(s.dateOn(day(9, 1)), day(9, 3), reason: 'not yet: as set');
      final yearly =
          sub('Domain', every: SubscriptionEvery.year, date: day(3, 5));
      expect(yearly.dateOn(today), day(3, 5, 2027));
    });

    test('the 31st: the last day of a shorter month, then back', () {
      final s = sub('Gym', date: day(1, 31));
      expect(s.dateOn(day(2, 1)), day(2, 28));
      expect(s.dateOn(day(3, 1)), day(3, 31));
      expect(s.dateOn(day(4, 2)), day(4, 30));
    });

    test('to cancel: moves on too (it renewed); cancelled: as set', () {
      expect(
          sub('Grok', state: SubscriptionState.toCancel, date: day(10, 17))
              .dateOn(today),
          day(11, 17));
      final gpt =
          sub('ChatGPT', state: SubscriptionState.cancelled, date: day(11, 13));
      expect(gpt.dateOn(today), day(11, 13));
      expect(gpt.dateOn(day(12, 1)), day(11, 13));
      expect(sub('Spotify', state: SubscriptionState.inactive).dateOn(today),
          isNull);
    });

    test('cancelled: ended once its last day has gone by', () {
      final gpt =
          sub('ChatGPT', state: SubscriptionState.cancelled, date: day(11, 13));
      expect(gpt.endedOn(day(11, 13)), isFalse);
      expect(gpt.runningOn(day(11, 13)), isTrue);
      expect(gpt.endedOn(day(11, 14)), isTrue);
      expect(gpt.runningOn(day(11, 14)), isFalse);
      expect(sub('A', date: day(1, 1)).endedOn(today), isFalse);
      expect(sub('S', state: SubscriptionState.inactive).runningOn(today),
          isFalse);
    });
  });

  test('a month: a year\'s price ÷ 12; totals by currency, ~ if any is', () {
    expect(sub('Y', price: 120, every: SubscriptionEvery.year).perMonth, 10);
    expect(sub('N', price: null).perMonth, isNull);
    final book = SubscriptionBook([
      sub('Claude'),
      sub('Grok', price: 16, state: SubscriptionState.toCancel),
      sub('AWS', price: 5, about: true),
      sub('ChatGPT', price: 23, state: SubscriptionState.cancelled),
      sub('Spotify', price: 6, state: SubscriptionState.inactive),
      sub('Netflix', price: 12, currency: r'$'),
      sub('Domain', price: 24, every: SubscriptionEvery.year),
      sub('Free', price: null),
    ]);
    expect(book.monthly(), [
      (currency: '€', amount: 43.0, about: true),
      (currency: r'$', amount: 12.0, about: false),
    ]);
    expect(const SubscriptionBook([]).monthly(), isEmpty);
  });

  test('the order: to cancel, active, cancelled, inactive and ended', () {
    final book = SubscriptionBook([
      sub('Spotify', state: SubscriptionState.inactive),
      sub('Old', state: SubscriptionState.cancelled, date: day(10, 1)),
      sub('ChatGPT', state: SubscriptionState.cancelled, date: day(11, 13)),
      sub('b Claude', date: day(11, 3)),
      sub('AWS', date: day(11, 1)),
      sub('a Claude', date: day(11, 3)),
      sub('Grok', state: SubscriptionState.toCancel, date: day(11, 17)),
    ]);
    expect(book.ordered(today).map((s) => s.name), [
      'Grok',
      'AWS',
      'a Claude',
      'b Claude',
      'ChatGPT',
      'Old',
      'Spotify',
    ]);
  });

  test('to cancel soon (within its reminder): the red dot', () {
    final grok =
        sub('Grok', state: SubscriptionState.toCancel, date: day(10, 21));
    expect(grok.cancelDueOn(day(10, 18)), isFalse);
    expect(grok.cancelDueOn(day(10, 19)), isTrue, reason: '2 days by default');
    expect(grok.cancelDueOn(day(10, 21)), isTrue);
    expect(
        grok.copyWith(remindBefore: () => 7).cancelDueOn(day(10, 14)), isTrue);
    expect(sub('A', date: day(10, 20)).cancelDueOn(today), isFalse);
  });

  test('kept as written, and read back; copied', () {
    final s = Subscription(
      id: 'x',
      name: 'Grok',
      price: 16,
      currency: '€',
      about: true,
      every: SubscriptionEvery.year,
      state: SubscriptionState.toCancel,
      date: DateTime(2026, 11, 17, 15),
      card: 'Virtual',
      note: 'real ~30€',
      remindBefore: 3,
    );
    expect(s.date, day(11, 17), reason: 'a day');
    final back = Subscription.fromJson(s.toJson());
    expect(back, s);
    expect(back.hashCode, s.hashCode);
    final plain = Subscription(id: 'y', name: 'Plain');
    expect(plain.toJson(), {
      'id': 'y',
      'name': 'Plain',
      'currency': '€',
      'every': 'month',
      'state': 'active',
    });
    expect(Subscription.fromJson(plain.toJson()), plain);
    expect(s.copyWith(price: () => null, date: () => null).toJson(),
        isNot(contains('price')));
    expect(s.copyWith(name: 'G').name, 'G');
    expect(s.copyWith() == s, isTrue);
    expect(s.copyWith(note: '') == s, isFalse);
    final book = SubscriptionBook([s, plain]);
    expect(SubscriptionBook.fromJson(book.toJson()).subscriptions, [s, plain]);
    expect(book.byId('y'), plain);
    expect(SubscriptionState.fromId('nope'), SubscriptionState.active);
    expect(SubscriptionEvery.fromId(null), SubscriptionEvery.month);
  });

  test('Round 80: its card\'s expiry: kept; before it renews, it runs out', () {
    final s = Subscription(
      id: 'g',
      name: 'Grok',
      date: day(11, 17),
      card: 'Virtual',
      cardExpires: DateTime(2026, 11, 10, 18),
    );
    expect(s.cardExpires, day(11, 10), reason: 'a day');
    expect(Subscription.fromJson(s.toJson()), s);
    expect(s.toJson()['cardExpires'], '2026-11-10');
    expect(Subscription(id: 'x', name: 'x').toJson(),
        isNot(contains('cardExpires')));
    expect(s.copyWith(cardExpires: () => null).cardExpires, isNull);
    expect(s == s.copyWith(cardExpires: () => day(12, 1)), isFalse);
    expect(s.cardRunsOutOn(today), isTrue);
    expect(s.copyWith(cardExpires: () => day(11, 17)).cardRunsOutOn(today),
        isFalse,
        reason: 'on the day: still good');
    expect(s.copyWith(cardExpires: () => null).cardRunsOutOn(today), isFalse);
    expect(s.copyWith(state: SubscriptionState.cancelled).cardRunsOutOn(today),
        isFalse,
        reason: 'it won\'t renew');
    expect(s.copyWith(state: SubscriptionState.toCancel).cardRunsOutOn(today),
        isTrue);
    // Its label on the card.
    expect(cardLabel(s, today), 'Virtual · expires 10 Nov');
    expect(cardLabel(s, day(11, 11)), 'Virtual · expired 10 Nov');
    expect(cardLabel(s.copyWith(card: ''), today), 'Card · expires 10 Nov');
    expect(cardLabel(s.copyWith(cardExpires: () => null), today), 'Virtual');
    expect(cardLabel(s.copyWith(card: '', cardExpires: () => null), today),
        'Card unknown');
  });

  group('what it says', () {
    test('its price, state and reminder', () {
      expect(priceLabel(sub('A', price: 5, about: true)), '~5€');
      expect(priceLabel(sub('A', price: 4.99, currency: r'$')), r'4.99$');
      expect(priceLabel(sub('A', price: null)), isNull);
      expect(
          stateLabel(sub('A', date: day(11, 3)), today), 'Renews Tue, 3 Nov');
      expect(
          stateLabel(
              sub('G', state: SubscriptionState.toCancel, date: day(11, 17)),
              today),
          'Cancel by Tue, 17 Nov');
      final gpt =
          sub('C', state: SubscriptionState.cancelled, date: day(11, 13));
      expect(stateLabel(gpt, today), 'Active until Fri, 13 Nov');
      expect(stateLabel(gpt, day(11, 20)), 'Ended Fri, 13 Nov');
      expect(stateLabel(sub('S', state: SubscriptionState.inactive), today),
          'Inactive');
      expect(remindLabel(sub('A', remindBefore: 2)), '2 days before');
      expect(remindLabel(sub('A', remindBefore: 7)), '1 week before');
      expect(remindLabel(sub('A')), isNull);
    });
  });

  group('its notifications (09:00)', () {
    final now = DateTime(2026, 10, 19, 10);
    List<(DateTime, String, String)> plan(
      List<Subscription> subs, {
      Preferences preferences = const Preferences(),
      bool hide = false,
    }) =>
        [
          for (final r in planSubscriptionReminders(
            now: now,
            book: SubscriptionBook(subs),
            preferences: preferences,
            days: 14,
            hideNames: hide,
          ))
            (r.at, r.title, r.body),
        ];

    test('on its day, and before it if set', () {
      expect(plan([sub('Claude', date: day(10, 25), remindBefore: 2)]), [
        (DateTime(2026, 10, 23, 9), 'Claude', 'Renews in 2 days · 20€'),
        (DateTime(2026, 10, 25, 9), 'Claude', 'Renews today · 20€'),
      ]);
    });

    test('to cancel; cancelled; none inactive or ended', () {
      expect(
          plan([
            sub('Grok',
                price: 16,
                state: SubscriptionState.toCancel,
                date: day(10, 21),
                remindBefore: 1),
          ]),
          [
            (
              DateTime(2026, 10, 20, 9),
              'Cancel Grok',
              'It renews tomorrow · 16€'
            ),
            (DateTime(2026, 10, 21, 9), 'Cancel Grok', 'It renews today · 16€'),
          ]);
      expect(
          plan([
            sub('ChatGPT',
                state: SubscriptionState.cancelled, date: day(10, 30)),
          ]),
          [(DateTime(2026, 10, 30, 9), 'ChatGPT', 'Ends today')]);
      expect(
          plan([
            sub('Old', state: SubscriptionState.cancelled, date: day(10, 1)),
            sub('Spotify',
                state: SubscriptionState.inactive, date: day(10, 25)),
          ]),
          isEmpty);
    });

    test('past ones and beyond two weeks: none; a renewal gone by: next', () {
      // Today's 09:00 has gone by (it's 10:00).
      expect(plan([sub('A', date: day(10, 19))]), isEmpty);
      expect(plan([sub('A', date: day(11, 10))]), isEmpty);
      expect(plan([sub('A', date: day(9, 25), remindBefore: 1)]), [
        (DateTime(2026, 10, 24, 9), 'A', 'Renews tomorrow · 20€'),
        (DateTime(2026, 10, 25, 9), 'A', 'Renews today · 20€')
      ]);
    });

    test('off, paused, or private', () {
      final s = [sub('Claude', date: day(10, 25))];
      expect(
          plan(s,
              preferences: const Preferences(subscriptionsReminders: false)),
          isEmpty);
      expect(
          plan(s,
              preferences: Preferences(subscriptionsPausedUntil: day(10, 25))),
          isEmpty);
      expect(
          plan(s,
              preferences: Preferences(subscriptionsPausedUntil: day(10, 24))),
          hasLength(1));
      expect(plan(s, hide: true), [
        (
          DateTime(2026, 10, 25, 9),
          'Subscriptions',
          'A subscription renews today'
        ),
      ]);
      expect(
          plan([
            sub('G', state: SubscriptionState.toCancel, date: day(10, 25)),
            sub('C', state: SubscriptionState.cancelled, date: day(10, 26)),
          ], hide: true)
              .map((r) => r.$3),
          [
            'A subscription to cancel renews today',
            'A subscription ends today'
          ]);
      expect(
          planSubscriptionReminders(
            now: now,
            book: SubscriptionBook(s),
            preferences: const Preferences(),
            days: 14,
          ).single.target,
          'subscriptions');
    });

    test('no price: none said', () {
      expect(plan([sub('Free', price: null, date: day(10, 25))]).single.$3,
          'Renews today');
    });
  });

  test('its settings kept', () {
    final p = Preferences(
      subscriptionsReminders: false,
      subscriptionsPausedUntil: day(10, 30),
    );
    final back = Preferences.fromJson(p.toJson());
    expect(back.subscriptionsReminders, isFalse);
    expect(back.subscriptionsPausedUntil, day(10, 30));
    expect(back.subscriptionsPausedOn(day(10, 30)), isTrue);
    expect(back.subscriptionsPausedOn(day(10, 31)), isFalse);
    final plain = Preferences.fromJson(const Preferences().toJson());
    expect(plain.subscriptionsReminders, isTrue);
    expect(plain.subscriptionsPausedUntil, isNull);
    expect(
        p
            .copyWith(subscriptionsPausedUntil: () => null)
            .subscriptionsPausedUntil,
        isNull);
  });
}
