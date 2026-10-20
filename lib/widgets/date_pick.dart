import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';

/// Asks for a day, the app's one way: it opens on [value], the day
/// already set; with none set (Round 91, Nikola: a new subscription's
/// calendar didn't open on today), on [today] (or the nearest day
/// allowed, between [first] and [last]). Today is marked. Null if
/// dismissed. (Round 87 opened every one on today's month; Nikola: a day
/// set should open where it is.)
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime today,
  required DateTime first,
  required DateTime last,
  DateTime? value,
  String? helpText,
  SelectableDayPredicate? selectable,
}) {
  final day = dayOf(today);
  bool fits(DateTime d) =>
      !d.isBefore(dayOf(first)) &&
      !d.isAfter(last) &&
      (selectable?.call(d) ?? true);
  final nearest = day.isBefore(first)
      ? dayOf(first)
      : day.isAfter(last)
          ? dayOf(last)
          : day;
  final DateTime? initial = switch (value) {
    final v? when fits(dayOf(v)) => dayOf(v),
    _ when fits(nearest) => nearest,
    _ => null,
  };
  return showDatePicker(
    context: context,
    initialDate: initial,
    currentDate: day,
    firstDate: first,
    lastDate: last,
    helpText: helpText,
    selectableDayPredicate: selectable,
  );
}
