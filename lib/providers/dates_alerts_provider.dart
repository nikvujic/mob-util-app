import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// How far off [on] is from [today]: "today", "tomorrow", "in 9 days".
String howSoon(DateTime on, DateTime today) => switch (daysBetween(today, on)) {
      0 => 'today',
      1 => 'tomorrow',
      final n => 'in $n days',
    };

/// When [date] is, starting [on] (Round 59): its day, or its days
/// ("Sat, 24 Oct – Mon, 26 Oct") if it lasts; how soon ("in 9 days"), or
/// "on now" / "last day today" while it's on, or how long ago ("2 days
/// ago", a day picked in the past); "turns 31" / "10 years".
String whenLabel(DateEntry date, DateTime on, DateTime today) {
  final end = date.endFrom(on);
  final years = yearsLabel(date, on);
  final ago = daysBetween(end, today);
  return [
    date.span > 1
        ? '${formatDay(on, today: today)} – ${formatDay(end, today: today)}'
        : formatDay(on, today: today),
    if (ago > 0)
      ago == 1 ? 'yesterday' : '$ago days ago'
    else if (on.isBefore(today))
      ago == 0 ? 'last day today' : 'on now'
    else
      howSoon(on, today),
    if (years != null) years,
  ].join('  ·  ');
}

/// What a date is on [on]: "turns 31" (a birthday), "10 years" (an
/// anniversary), or nothing.
String? yearsLabel(DateEntry date, DateTime on) {
  final years = date.yearsOn(on);
  if (years == null) return null;
  return switch (date.type) {
    DateType.birthday => 'turns $years',
    DateType.anniversary => countOf(years, 'year', 'years'),
    _ => null,
  };
}

/// The dates' reminders (Round 57) due after [now] for the next [days]
/// days: each of a date's reminders, its days before the date, at its
/// time. A reminder up to 30 days before a date is planned once its time
/// comes into those days, like the others. None while off or paused.
/// With [hideNames] (the Hub or the Dates page is locked, or set
/// private), no titles. Those due at the same moment come as one.
List<Reminder> planDateReminders({
  required DateTime now,
  required DateBook book,
  required Preferences preferences,
  required int days,
  bool hideNames = false,
}) {
  if (!preferences.datesReminders) return const [];
  final today = dayOf(now);
  final end = addDays(today, days + 1);
  final due = <DateTime, List<({DateEntry date, DateTime on})>>{};
  for (final date in book.dates) {
    // Its next time: with reminders at most 30 days before and two weeks
    // planned, a time after that is never due yet.
    final on = date.nextFrom(today);
    if (on == null) continue;
    for (final r in date.reminders) {
      final at =
          DateTime(on.year, on.month, on.day - r.daysBefore, 0, r.minutes);
      if (!at.isAfter(now) || !at.isBefore(end)) continue;
      if (preferences.datesPausedOn(at)) continue;
      (due[at] ??= []).add((date: date, on: on));
    }
  }
  String part(({DateEntry date, DateTime on}) d, DateTime at) {
    final years = yearsLabel(d.date, d.on);
    return [
      '${d.date.type.label} ${howSoon(d.on, dayOf(at))}',
      if (years != null) years,
    ].join(' · ');
  }

  return [
    for (final MapEntry(key: at, value: dates) in due.entries)
      Reminder(
        at: at,
        kind: ReminderKind.dates,
        target: const DatesTarget().payload,
        title: hideNames ? 'Dates' : dates.map((d) => d.date.title).join(', '),
        body: hideNames
            ? dates.length == 1
                ? 'A ${dates.single.date.type.label.toLowerCase()} '
                    '${howSoon(dates.single.on, dayOf(at))}'
                : '${dates.length} dates'
            : dates.map((d) => part(d, at)).join(', '),
      ),
  ]..sort((a, b) => a.at.compareTo(b.at));
}

/// The green dot on the Dates tile (Round 57): someone's birthday today,
/// and the page not opened yet today. Looked at again with the red dots.
final datesDotProvider = Provider<bool>((ref) {
  final today = dayOf(ref.watch(clockProvider)());
  final seen = ref.watch(preferencesProvider.select((p) => p.datesSeenOn));
  return seen != today && ref.watch(datesProvider).birthdayOn(today);
});
