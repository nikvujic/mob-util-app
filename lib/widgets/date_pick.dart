import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';

/// Asks for a day, the app's one way (Round 87, Nikola: a calendar opened
/// where an earlier one had been, for something else): it always opens
/// on [today]'s month (or the nearest one allowed, between [first] and
/// [last]), today marked. [value], the day already set, shows picked only
/// when it's in that month. Null if dismissed.
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
  final shown = day.isBefore(first)
      ? dayOf(first)
      : day.isAfter(last)
          ? dayOf(last)
          : day;
  bool fits(DateTime d) =>
      !d.isBefore(dayOf(first)) &&
      !d.isAfter(last) &&
      (selectable?.call(d) ?? true);
  final DateTime? initial = switch (value) {
    final v? when v.year == shown.year && v.month == shown.month && fits(v) =>
      dayOf(v),
    // Today out of reach: open where it can, on that day if it may be
    // picked (the picker needs one to show a month other than today's).
    _ when shown != day && fits(shown) => shown,
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
