/// What kind of date a date is (Round 57): a fixed list, each shown with
/// its icon and colour. The [name] is stored, so a type is never renamed
/// here, only its [label].
enum DateType {
  birthday('Birthday', yearly: true),
  anniversary('Anniversary', yearly: true),
  holiday('Holiday', yearly: true, lasts: true),
  event('Event', lasts: true),
  other('Other');

  const DateType(this.label, {this.yearly = false, this.lasts = false});

  final String label;

  /// Whether a new date of this type is every year.
  final bool yearly;

  /// Whether it can last several days (Round 59: a holiday, an event).
  final bool lasts;

  /// Whether its form offers *Every year* and *Year known* (Round 61:
  /// only Other; a birthday or anniversary is every year, a holiday or an
  /// event is once, on a date with its year).
  bool get choosesYearly => this == other;

  /// Its kinds (Round 61), besides the plain one.
  List<DateKind> get kinds => [
        for (final k in DateKind.values)
          if (k.type == this) k
      ];

  /// The type stored as [id]; unknown (e.g. from a newer app): other.
  static DateType fromId(String? id) =>
      values.where((t) => t.name == id).firstOrNull ?? other;
}

/// A kind of holiday or event (Round 61): a holiday can be a ski trip
/// (Pip goes skiing then, later), a beach or a trip; an event a wedding
/// (its own reminders). None: just a holiday or an event. The [name] is
/// stored.
enum DateKind {
  skiing('Skiing', DateType.holiday),
  beach('Beach', DateType.holiday),
  trip('Trip', DateType.holiday),
  wedding('Wedding', DateType.event);

  const DateKind(this.label, this.type);

  final String label;

  /// The type it's a kind of.
  final DateType type;

  /// The kind stored as [id], or none (also for one from a newer app).
  static DateKind? fromId(String? id) =>
      values.where((k) => k.name == id).firstOrNull;

  /// Its own reminders for a new date of its kind (Round 61: a wedding,
  /// a week and a month before), or null: the usual.
  List<DateReminder>? get reminders => switch (this) {
        wedding => DateReminder.weddingDefaults,
        _ => null,
      };
}

/// A date's reminder (Round 57): [daysBefore] it (0: on the day), at
/// [minutes] into that day.
class DateReminder {
  final int daysBefore;
  final int minutes;

  const DateReminder({required this.daysBefore, required this.minutes});

  /// A new date's (Round 57, Nikola): the day before, at 09:00.
  static const standard = DateReminder(daysBefore: 1, minutes: 9 * 60);

  /// A new date's reminders (Round 61, Nikola): the day before and a
  /// week before, at 09:00.
  static const defaults = [
    standard,
    DateReminder(daysBefore: 7, minutes: 9 * 60),
  ];

  /// A wedding's (Round 61, Nikola): a week and a month before.
  static const weddingDefaults = [
    DateReminder(daysBefore: 7, minutes: 9 * 60),
    DateReminder(daysBefore: 30, minutes: 9 * 60),
  ];

  /// The choices for [daysBefore].
  static const daysChoices = [0, 1, 2, 3, 5, 7, 14, 30];

  /// At most this many a date.
  static const most = 3;

  DateReminder copyWith({int? daysBefore, int? minutes}) => DateReminder(
        daysBefore: daysBefore ?? this.daysBefore,
        minutes: minutes ?? this.minutes,
      );

  @override
  bool operator ==(Object other) =>
      other is DateReminder &&
      other.daysBefore == daysBefore &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(daysBefore, minutes);

  Map<String, dynamic> toJson() => {
        'daysBefore': daysBefore,
        'minutes': minutes,
      };

  factory DateReminder.fromJson(Map<String, dynamic> json) => DateReminder(
        daysBefore: (json['daysBefore'] as num?)?.toInt() ?? 0,
        minutes: (json['minutes'] as num?)?.toInt() ?? 9 * 60,
      );
}

/// An important date (Round 57): a birthday, an anniversary, a holiday,
/// an event. Its [day] and [month], and its [year] if known (needed for
/// a one-off: [yearly] off). A birthday on 29 February comes on 28
/// February in a year without it.
class DateEntry {
  final String id;
  final String title;
  final DateType type;
  final int day;
  final int month;
  final int? year;
  final bool yearly;
  final String note;
  final List<DateReminder> reminders;

  /// How many days it lasts (Round 59), from its day on; only a type that
  /// [DateType.lasts] (else it's kept, unused, for if the type comes
  /// back). See [span].
  final int days;

  /// The longest it can last.
  static const mostDays = 31;

  /// Its kind (Round 61), if one of its type's; see [kindNow].
  final DateKind? kind;

  /// Its kind as its type has it: none if the kind is another type's
  /// (kept, unused, for if the type comes back).
  DateKind? get kindNow => kind?.type == type ? kind : null;

  /// A ski trip's travel (Round 67): hours each way (0: none), when the
  /// bus leaves on the first day ([leaveAt]) and on the day after the
  /// last ([backAt]), as minutes into the day. Only for a Skiing holiday
  /// ([hasTravel]); kept otherwise, unused.
  final int travelHours;
  final int leaveAt;
  final int backAt;

  static const mostTravelHours = 24;
  static const leaveDefault = 6 * 60;
  static const backDefault = 11 * 60;

  /// A Skiing holiday with travel set.
  bool get hasTravel => kindNow == DateKind.skiing && travelHours > 0;

  /// The bus trips for the holiday starting on [start]: there (leaving
  /// on its first day) and back (leaving the day after its last); null
  /// without travel.
  ({DateTime there, DateTime back, Duration length})? tripsFrom(
      DateTime start) {
    if (!hasTravel) return null;
    final end = endFrom(start);
    return (
      there: DateTime(start.year, start.month, start.day, 0, leaveAt),
      back: DateTime(end.year, end.month, end.day + 1, 0, backAt),
      length: Duration(hours: travelHours),
    );
  }

  const DateEntry({
    required this.id,
    required this.title,
    required this.type,
    required this.day,
    required this.month,
    this.year,
    this.yearly = true,
    this.note = '',
    this.reminders = const [DateReminder.standard],
    this.days = 1,
    this.kind,
    this.travelHours = 0,
    this.leaveAt = leaveDefault,
    this.backAt = backDefault,
  });

  /// How many days it lasts, as its type has it: 1 unless it [DateType.lasts].
  int get span => type.lasts ? days : 1;

  /// Its last day, for one starting on [start].
  DateTime endFrom(DateTime start) =>
      DateTime(start.year, start.month, start.day + span - 1);

  DateEntry copyWith({
    String? title,
    DateType? type,
    int? day,
    int? month,
    int? Function()? year,
    bool? yearly,
    String? note,
    List<DateReminder>? reminders,
    int? days,
    DateKind? Function()? kind,
    int? travelHours,
    int? leaveAt,
    int? backAt,
  }) =>
      DateEntry(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        day: day ?? this.day,
        month: month ?? this.month,
        year: year == null ? this.year : year(),
        yearly: yearly ?? this.yearly,
        note: note ?? this.note,
        reminders: reminders ?? this.reminders,
        days: (days ?? this.days).clamp(1, mostDays),
        kind: kind == null ? this.kind : kind(),
        travelHours:
            (travelHours ?? this.travelHours).clamp(0, mostTravelHours),
        leaveAt: leaveAt ?? this.leaveAt,
        backAt: backAt ?? this.backAt,
      );

  /// When it falls in [inYear] (29 February on the 28th in a year without
  /// it); null for a one-off in another year.
  DateTime? inYear(int inYear) {
    if (!yearly && year != inYear) return null;
    final last = DateTime(inYear, month + 1, 0).day;
    return DateTime(inYear, month, day > last ? last : day);
  }

  /// When the time it covers [date] began (its first day), or null if
  /// it doesn't fall on [date] (a day, local). Round 59: lasting several
  /// days, every one of them (also into the new year).
  DateTime? startCovering(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    for (final y in [date.year, date.year - 1]) {
      final at = inYear(y);
      if (at != null && !at.isAfter(day) && !endFrom(at).isBefore(day)) {
        return at;
      }
    }
    return null;
  }

  /// Whether it falls on [date] (a day, local).
  bool on(DateTime date) => startCovering(date) != null;

  /// The next time it falls, on [from] or after (a day): its first day,
  /// which is before [from] while it's on (Round 59); null if never again
  /// (a one-off gone by).
  DateTime? nextFrom(DateTime from) {
    final start = DateTime(from.year, from.month, from.day);
    for (final y in [from.year - 1, from.year, from.year + 1]) {
      final at = inYear(y);
      if (at != null && !endFrom(at).isBefore(start)) return at;
    }
    return null;
  }

  /// How many years it is on [date], with a year known and only after
  /// it ("turns 31", "10 years"); null otherwise.
  int? yearsOn(DateTime date) {
    final from = year;
    if (from == null || date.year <= from) return null;
    return date.year - from;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'day': day,
        'month': month,
        if (year != null) 'year': year,
        'yearly': yearly,
        'note': note,
        'reminders': [for (final r in reminders) r.toJson()],
        if (days != 1) 'days': days,
        if (kind != null) 'kind': kind!.name,
        if (travelHours > 0)
          'travel': {'hours': travelHours, 'leave': leaveAt, 'back': backAt},
      };

  factory DateEntry.fromJson(Map<String, dynamic> json) {
    final travel = json['travel'] as Map<String, dynamic>?;
    int minutes(Object? m, int fallback) =>
        ((m as num?)?.toInt() ?? fallback).clamp(0, 24 * 60 - 1);
    return DateEntry(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      type: DateType.fromId(json['type'] as String?),
      day: (json['day'] as num).toInt(),
      month: (json['month'] as num).toInt(),
      year: (json['year'] as num?)?.toInt(),
      yearly: json['yearly'] as bool? ?? true,
      note: json['note'] as String? ?? '',
      reminders: [
        for (final r in (json['reminders'] as List? ?? const []))
          DateReminder.fromJson(r as Map<String, dynamic>),
      ],
      days: ((json['days'] as num?)?.toInt() ?? 1).clamp(1, mostDays),
      kind: DateKind.fromId(json['kind'] as String?),
      travelHours:
          ((travel?['hours'] as num?)?.toInt() ?? 0).clamp(0, mostTravelHours),
      leaveAt: minutes(travel?['leave'], leaveDefault),
      backAt: minutes(travel?['back'], backDefault),
    );
  }
}

/// A date on the day it next falls (for the upcoming list).
typedef DateOn = ({DateEntry date, DateTime on});

/// The dates (Round 57), in the order they were added.
class DateBook {
  final List<DateEntry> dates;

  const DateBook(this.dates);

  static const empty = DateBook([]);

  DateEntry? byId(String id) => dates.where((d) => d.id == id).firstOrNull;

  /// The dates falling on [day].
  List<DateEntry> on(DateTime day) => [
        for (final d in dates)
          if (d.on(day)) d,
      ];

  /// What's coming from [today] for [days] days, soonest first (the same
  /// day by title).
  List<DateOn> upcoming(DateTime today, {int days = 366}) {
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(start.year, start.month, start.day + days);
    final found = <DateOn>[
      for (final d in dates)
        if (d.nextFrom(start) case final at? when at.isBefore(end))
          (date: d, on: at),
    ]..sort((a, b) {
        final byDay = a.on.compareTo(b.on);
        return byDay != 0
            ? byDay
            : a.date.title.toLowerCase().compareTo(b.date.title.toLowerCase());
      });
    return found;
  }

  /// The dates on [today] (Round 72: the Today section), each from its
  /// first day (one lasting several may have begun before), by title.
  List<DateOn> today(DateTime today) => [
        for (final d in dates)
          if (d.startCovering(today) case final at?) (date: d, on: at),
      ]..sort((a, b) =>
          a.date.title.toLowerCase().compareTo(b.date.title.toLowerCase()));

  /// One-off dates gone by (Round 72: the Past section, kept so they
  /// aren't lost), the latest first.
  List<DateOn> past(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return [
      for (final d in dates)
        if (!d.yearly && d.nextFrom(day) == null)
          if (d.year case final year?)
            if (d.inYear(year) case final at?) (date: d, on: at),
    ]..sort((a, b) => b.on.compareTo(a.on));
  }

  /// Whether someone has a birthday on [day] (Pip's party hat, the
  /// green dot).
  bool birthdayOn(DateTime day) =>
      dates.any((d) => d.type == DateType.birthday && d.on(day));

  Map<String, dynamic> toJson() => {
        'dates': [for (final d in dates) d.toJson()],
      };

  factory DateBook.fromJson(Map<String, dynamic> json) => DateBook([
        for (final d in (json['dates'] as List? ?? const []))
          DateEntry.fromJson(d as Map<String, dynamic>),
      ]);
}
