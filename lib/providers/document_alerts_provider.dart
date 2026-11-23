import 'package:the_app/core/format.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/dates_alerts_provider.dart';

/// The hour a document's reminders come.
const documentRemindHour = 9;

/// The documents' reminders due after [now] for the next [days] days, at
/// 09:00: before a document expires or a receipt's warranty ends, as each
/// is set to remind; a ticket on its day. None while off or paused. With
/// [hideNames] (set private, or the page locked), no names: "A warranty
/// ends in 7 days".
List<Reminder> planDocumentReminders({
  required DateTime now,
  required DocumentBook book,
  required Preferences preferences,
  required int days,
  bool hideNames = false,
}) {
  if (!preferences.documentsReminders) return const [];
  final end = addDays(dayOf(now), days + 1);
  final reminders = <Reminder>[];
  for (final d in book.items) {
    final due = d.dueDate;
    if (due == null || d.remind == DocRemind.none) continue;
    final before = d.kind == DocKind.ticket ? 0 : d.remind.days;
    final at =
        DateTime(due.year, due.month, due.day - before, documentRemindHour);
    if (!at.isAfter(now) || !at.isBefore(end)) continue;
    if (preferences.documentsPausedOn(at)) continue;
    final soon = howSoon(due, dayOf(at));
    final name = d.name.trim().isEmpty ? d.kind.label : d.name.trim();
    final (title, body) = switch (d.kind) {
      DocKind.ticket => hideNames
          ? ('Documents', 'A ticket $soon')
          : (name, 'Your ticket is for $soon'),
      DocKind.receipt => hideNames
          ? ('Documents', 'A warranty ends $soon')
          : (name, 'Its warranty ends $soon · ${formatShortDate(due)}'),
      _ => hideNames
          ? ('Documents', 'A document expires $soon')
          : (name, 'Expires $soon · ${formatShortDate(due)}'),
    };
    reminders.add(Reminder(
      at: at,
      kind: ReminderKind.documents,
      target: const DocumentsTarget().payload,
      title: title,
      body: body,
    ));
  }
  return reminders..sort((a, b) => a.at.compareTo(b.at));
}
