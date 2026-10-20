import 'package:the_app/models/planner_task.dart';

/// How often a subscription renews (Round 79).
enum SubscriptionEvery {
  month('month'),
  year('year');

  const SubscriptionEvery(this.label);

  final String label;

  static SubscriptionEvery fromId(String? id) =>
      values.where((e) => e.name == id).firstOrNull ?? month;
}

/// What's going on with a subscription (Round 79, `docs/SUBSCRIPTIONS_SPEC.md`).
/// Its [Subscription.date] means what goes with it.
enum SubscriptionState {
  /// Running: the date is the next payment.
  active('Active'),

  /// Running and renewing, but to be cancelled before the date (its
  /// renewal).
  toCancel('To cancel'),

  /// Cancelled, still on until the date (its last day).
  cancelled('Cancelled'),

  /// Not running (lapsed, the card ran out, a payment failed): no date.
  inactive('Inactive');

  const SubscriptionState(this.label);

  final String label;

  /// Whether it renews on its date (and its date moves on once gone by).
  bool get renews => this == active || this == toCancel;

  static SubscriptionState fromId(String? id) =>
      values.where((s) => s.name == id).firstOrNull ?? active;
}

/// How a subscription's card stands (Round 84), for its colour.
enum CardExpiry { fine, soon, expired }

/// One subscription (Round 79): a name, what it costs and how often, what
/// state it's in and its date, the card it's paid with, a note, and a
/// reminder some days before its date (besides the one on the day).
class Subscription {
  final String id;
  final String name;

  /// The price ([price] null: none given), its [currency] ("€") and
  /// whether it's [about] that (~).
  final double? price;
  final String currency;
  final bool about;
  final SubscriptionEvery every;
  final SubscriptionState state;

  /// Its day ([state] says what it is); null for an inactive one.
  final DateTime? date;

  /// The card it's paid with; empty: not known.
  final String card;

  /// Round 80 (Nikola): when that card expires (a virtual card runs out);
  /// null: not set.
  final DateTime? cardExpires;
  final String note;

  /// Days before [date] for a second reminder (at 09:00); null: none.
  final int? remindBefore;

  /// The reminders before that can be picked: a day, two, three, a week.
  static const remindChoices = [1, 2, 3, 7];

  /// A to-cancel one's reminder before, unless changed.
  static const toCancelRemind = 2;

  /// The reminders' time of day.
  static const remindHour = 9;

  static const defaultCurrency = '€';

  Subscription({
    required this.id,
    required this.name,
    this.price,
    this.currency = defaultCurrency,
    this.about = false,
    this.every = SubscriptionEvery.month,
    this.state = SubscriptionState.active,
    DateTime? date,
    this.card = '',
    DateTime? cardExpires,
    this.note = '',
    this.remindBefore,
  })  : date = date == null ? null : DateTime(date.year, date.month, date.day),
        cardExpires = cardExpires == null
            ? null
            : DateTime(cardExpires.year, cardExpires.month, cardExpires.day);

  Subscription copyWith({
    String? name,
    double? Function()? price,
    String? currency,
    bool? about,
    SubscriptionEvery? every,
    SubscriptionState? state,
    DateTime? Function()? date,
    String? card,
    DateTime? Function()? cardExpires,
    String? note,
    int? Function()? remindBefore,
  }) =>
      Subscription(
        id: id,
        name: name ?? this.name,
        price: price == null ? this.price : price(),
        currency: currency ?? this.currency,
        about: about ?? this.about,
        every: every ?? this.every,
        state: state ?? this.state,
        date: date == null ? this.date : date(),
        card: card ?? this.card,
        cardExpires: cardExpires == null ? this.cardExpires : cardExpires(),
        note: note ?? this.note,
        remindBefore: remindBefore == null ? this.remindBefore : remindBefore(),
      );

  /// [day] moved on by [times] of its [every].
  DateTime _after(DateTime day, int times) => switch (every) {
        SubscriptionEvery.month => _addMonths(day, times),
        SubscriptionEvery.year => _addMonths(day, 12 * times),
      };

  /// [day] [months] on, the same day of the month (or its last, for the
  /// 31st in a shorter month).
  static DateTime _addMonths(DateTime day, int months) {
    final month = day.month - 1 + months;
    final year = day.year + month ~/ 12;
    final m = month % 12 + 1;
    final last = DateTime(year, m + 1, 0).day;
    return DateTime(year, m, day.day > last ? last : day.day);
  }

  /// Its date as it is on [today]: one that renews has moved on past days
  /// gone by (to today or after); the others as set.
  DateTime? dateOn(DateTime today) {
    final d = date;
    if (d == null || !state.renews) return d;
    final day = DateTime(today.year, today.month, today.day);
    var times = 0;
    var at = d;
    while (at.isBefore(day)) {
      times++;
      at = _after(d, times);
    }
    return at;
  }

  /// Cancelled, and its last day gone by before [today]: ended.
  bool endedOn(DateTime today) {
    final d = date;
    return state == SubscriptionState.cancelled &&
        d != null &&
        d.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// Running on [today]: it costs (active, to cancel), or is still on till
  /// its day (cancelled, not ended).
  bool runningOn(DateTime today) =>
      state.renews || (state == SubscriptionState.cancelled && !endedOn(today));

  /// To cancel, and its day within its reminder before (or today) on
  /// [today]: the Hub's red dot.
  bool cancelDueOn(DateTime today) {
    if (state != SubscriptionState.toCancel) return false;
    final at = dateOn(today);
    if (at == null) return false;
    final day = DateTime(today.year, today.month, today.day);
    final days = DateTime.utc(at.year, at.month, at.day)
        .difference(DateTime.utc(day.year, day.month, day.day))
        .inDays;
    return days <= (remindBefore ?? toCancelRemind);
  }

  /// Its card expires before it next renews, on [today] (a renewing one:
  /// the payment would fail).
  bool cardRunsOutOn(DateTime today) {
    final expires = cardExpires;
    final at = dateOn(today);
    return expires != null &&
        state.renews &&
        at != null &&
        expires.isBefore(at);
  }

  /// Round 84 (Nikola): how its card stands on [today]: expired (gone
  /// by), soon (a week or less away, the day itself included), or fine
  /// (later, or no expiry set).
  CardExpiry cardExpiryOn(DateTime today) {
    final expires = cardExpires;
    if (expires == null) return CardExpiry.fine;
    final day = DateTime(today.year, today.month, today.day);
    if (expires.isBefore(day)) return CardExpiry.expired;
    final days = DateTime.utc(expires.year, expires.month, expires.day)
        .difference(DateTime.utc(day.year, day.month, day.day))
        .inDays;
    return days <= cardSoonDays ? CardExpiry.soon : CardExpiry.fine;
  }

  /// A card expiring within this many days is soon (Round 84).
  static const cardSoonDays = 7;

  /// What it comes to a month (a year's price ÷ 12); null: no price.
  double? get perMonth => switch (price) {
        null => null,
        final p => every == SubscriptionEvery.month ? p : p / 12,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (price != null) 'price': price,
        'currency': currency,
        if (about) 'about': true,
        'every': every.name,
        'state': state.name,
        if (date != null) 'date': PlannerTask.dayToJson(date!),
        if (card.isNotEmpty) 'card': card,
        if (cardExpires != null)
          'cardExpires': PlannerTask.dayToJson(cardExpires!),
        if (note.isNotEmpty) 'note': note,
        if (remindBefore != null) 'remindBefore': remindBefore,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? defaultCurrency,
        about: json['about'] as bool? ?? false,
        every: SubscriptionEvery.fromId(json['every'] as String?),
        state: SubscriptionState.fromId(json['state'] as String?),
        date:
            json['date'] == null ? null : PlannerTask.dayFromJson(json['date']),
        card: json['card'] as String? ?? '',
        cardExpires: json['cardExpires'] == null
            ? null
            : PlannerTask.dayFromJson(json['cardExpires']),
        note: json['note'] as String? ?? '',
        remindBefore: (json['remindBefore'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is Subscription &&
      other.id == id &&
      other.name == name &&
      other.price == price &&
      other.currency == currency &&
      other.about == about &&
      other.every == every &&
      other.state == state &&
      other.date == date &&
      other.card == card &&
      other.cardExpires == cardExpires &&
      other.note == note &&
      other.remindBefore == remindBefore;

  @override
  int get hashCode => Object.hash(id, name, price, currency, about, every,
      state, date, card, cardExpires, note, remindBefore);
}

/// What the running subscriptions come to a month, in one currency.
typedef MonthlyTotal = ({String currency, double amount, bool about});

/// The subscriptions (Round 79), in the order they were added.
class SubscriptionBook {
  final List<Subscription> subscriptions;

  const SubscriptionBook(this.subscriptions);

  static const empty = SubscriptionBook([]);

  bool get isEmpty => subscriptions.isEmpty;

  Subscription? byId(String id) =>
      subscriptions.where((s) => s.id == id).firstOrNull;

  /// The order the page shows them in on [today]: to cancel, active,
  /// cancelled (still on), then inactive and ended; each by the soonest
  /// date, then by name.
  List<Subscription> ordered(DateTime today) {
    int rank(Subscription s) => switch (s.state) {
          SubscriptionState.toCancel => 0,
          SubscriptionState.active => 1,
          SubscriptionState.cancelled => s.endedOn(today) ? 3 : 2,
          SubscriptionState.inactive => 3,
        };
    return [...subscriptions]..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        final da = a.dateOn(today), db = b.dateOn(today);
        if (da != null && db != null && da != db) return da.compareTo(db);
        if ((da == null) != (db == null)) return da == null ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  /// What the ones that cost (active, to cancel) come to a month, by
  /// currency, in the order first met.
  List<MonthlyTotal> monthly() {
    final totals = <String, ({double amount, bool about})>{};
    for (final s in subscriptions) {
      final m = s.perMonth;
      if (!s.state.renews || m == null) continue;
      final was = totals[s.currency];
      totals[s.currency] = (
        amount: (was?.amount ?? 0) + m,
        about: (was?.about ?? false) || s.about,
      );
    }
    return [
      for (final e in totals.entries)
        (currency: e.key, amount: e.value.amount, about: e.value.about),
    ];
  }

  Map<String, dynamic> toJson() => {
        'subscriptions': [for (final s in subscriptions) s.toJson()],
      };

  factory SubscriptionBook.fromJson(Map<String, dynamic> json) =>
      SubscriptionBook([
        for (final s in (json['subscriptions'] as List? ?? const []))
          Subscription.fromJson(s as Map<String, dynamic>),
      ]);
}
