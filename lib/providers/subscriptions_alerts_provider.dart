import 'package:the_app/core/format.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/providers/dates_alerts_provider.dart';

/// An amount as shown: whole without decimals ("20"), else two ("4.99").
String amountLabel(double amount) => amount == amount.roundToDouble()
    ? amount.round().toString()
    : amount.toStringAsFixed(2);

/// [s]'s price as shown: "~16€", or null for none.
String? priceLabel(Subscription s) => switch (s.price) {
      null => null,
      final p => '${s.about ? '~' : ''}${amountLabel(p)}${s.currency}',
    };

/// [s]'s state and date on [today], for its card: "Renews 3 Nov",
/// "Cancel by 17 Nov", "Active until 13 Nov", "Ended 13 Nov", "Inactive".
String stateLabel(Subscription s, DateTime today) {
  final at = s.dateOn(today);
  if (s.state == SubscriptionState.inactive || at == null) {
    return s.state.label;
  }
  final day = formatDay(at, today: today);
  return switch (s.state) {
    SubscriptionState.active => 'Renews $day',
    SubscriptionState.toCancel => 'Cancel by $day',
    SubscriptionState.cancelled =>
      s.endedOn(today) ? 'Ended $day' : 'Active until $day',
    SubscriptionState.inactive => s.state.label,
  };
}

/// [s]'s card on [today], for its card: its name (or "Card"), and when
/// it expires ("expires 30 Nov"; "expired …" once it has); "Card
/// unknown" for neither.
String cardLabel(Subscription s, DateTime today) {
  final expires = s.cardExpires;
  if (s.card.isEmpty && expires == null) return 'Card unknown';
  final name = s.card.isEmpty ? 'Card' : s.card;
  if (expires == null) return name;
  final gone = expires.isBefore(today);
  // Shortly, without the weekday ("10 Nov", "31 Mar 2027").
  final day = formatDay(expires, today: today).split(', ').last;
  return '$name · ${gone ? 'expired' : 'expires'} $day';
}

/// [s]'s reminder before, shortly: "2 days before"; null for none.
String? remindLabel(Subscription s) => switch (s.remindBefore) {
      null => null,
      final days => '${beforeLabel(days)} before',
    };

/// The subscriptions' reminders (Round 79) due after [now] for the next
/// [days] days: on each one's day at 09:00, and its reminder before (if
/// set) at 09:00: renewing (active), to cancel, ending (cancelled). None
/// for an inactive or ended one, nor while off or paused. With
/// [hideNames] (the Hub or the page is locked, or set private), no names
/// or prices.
List<Reminder> planSubscriptionReminders({
  required DateTime now,
  required SubscriptionBook book,
  required Preferences preferences,
  required int days,
  bool hideNames = false,
}) {
  if (!preferences.subscriptionsReminders) return const [];
  final today = dayOf(now);
  final end = addDays(today, days + 1);
  final reminders = <Reminder>[];
  for (final s in book.subscriptions) {
    if (s.state == SubscriptionState.inactive) continue;
    // An ended one's day has gone by: nothing comes.
    final on = s.dateOn(today);
    if (on == null) continue;
    for (final before in {0, if (s.remindBefore case final b?) b}) {
      final at =
          DateTime(on.year, on.month, on.day - before, Subscription.remindHour);
      if (!at.isAfter(now) || !at.isBefore(end)) continue;
      if (preferences.subscriptionsPausedOn(at)) continue;
      final soon = howSoon(on, dayOf(at));
      final price = priceLabel(s);
      final (title, body) = switch (s.state) {
        SubscriptionState.toCancel => hideNames
            ? ('Subscriptions', 'A subscription to cancel renews $soon')
            : (
                'Cancel ${s.name}',
                'It renews $soon${price == null ? '' : ' · $price'}'
              ),
        SubscriptionState.cancelled => hideNames
            ? ('Subscriptions', 'A subscription ends $soon')
            : (s.name, 'Ends $soon'),
        _ => hideNames
            ? ('Subscriptions', 'A subscription renews $soon')
            : (s.name, 'Renews $soon${price == null ? '' : ' · $price'}'),
      };
      reminders.add(Reminder(
        at: at,
        kind: ReminderKind.subscriptions,
        target: const SubscriptionsTarget().payload,
        title: title,
        body: body,
      ));
    }
  }
  return reminders..sort((a, b) => a.at.compareTo(b.at));
}
