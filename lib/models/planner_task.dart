/// A task in the planner (P2, P7): a block of time on one day, which can be
/// ticked off when done.
class PlannerTask {
  /// Minutes in a day: times run from 0 (00:00) to this (24:00).
  static const dayMinutes = 24 * 60;

  final String id;
  final String title;

  /// The day it's planned for: a local date at midnight (no time of day).
  final DateTime day;

  /// Start and end, in minutes from midnight (end is exclusive, up to
  /// [dayMinutes]). Null for tasks from before the timeline (planner v1),
  /// which had no times.
  final int? start;
  final int? end;

  final bool done;

  /// Its colour (P9): a [BlockColor] name, or null for the default.
  final String? color;

  PlannerTask({
    required this.id,
    required this.title,
    required DateTime day,
    this.start,
    this.end,
    this.done = false,
    this.color,
  }) : day = DateTime(day.year, day.month, day.day) {
    if ((start == null) != (end == null) ||
        (start != null &&
            (start! < 0 || end! > dayMinutes || start! >= end!))) {
      throw ArgumentError('Invalid time: $start–$end');
    }
  }

  /// Whether it has a place on the timeline (tasks from v1 don't).
  bool get hasTime => start != null;

  PlannerTask copyWith({bool? done}) => PlannerTask(
        id: id,
        title: title,
        day: day,
        start: start,
        end: end,
        done: done ?? this.done,
        color: color,
      );

  /// `2026-10-09`: a calendar date, the same in every time zone.
  static String dayToJson(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// A day written by [dayToJson]; throws [FormatException] otherwise.
  static DateTime dayFromJson(Object? json) {
    if (json is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(json)) {
      throw FormatException('Not a day: $json');
    }
    return DateTime.parse(json);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'day': dayToJson(day),
        if (start != null) 'start': start,
        if (end != null) 'end': end,
        'done': done,
        if (color != null) 'color': color,
      };

  factory PlannerTask.fromJson(Map<String, dynamic> json) => PlannerTask(
        id: json['id'] as String,
        title: json['title'] as String,
        day: dayFromJson(json['day']),
        start: json['start'] as int?,
        end: json['end'] as int?,
        done: json['done'] as bool,
        color: json['color'] as String?,
      );
}

/// A free stretch of a day's timeline, in minutes (end exclusive).
typedef FreeSlot = ({int start, int end});

/// A stretch of time in a day, in minutes (end exclusive).
typedef TimeSpan = ({int start, int end});

/// The free stretches of a day with [tasks] (any order; tasks without a
/// time are ignored), from 00:00 to 24:00.
List<FreeSlot> freeSlots(Iterable<PlannerTask> tasks) => freeSlotsAround([
      for (final t in tasks)
        if (t.hasTime) (start: t.start!, end: t.end!),
    ]);

/// The free stretches of a day around [busy] times (any order).
List<FreeSlot> freeSlotsAround(Iterable<TimeSpan> busy) {
  final timed = busy.toList()..sort((a, b) => a.start.compareTo(b.start));
  final slots = <FreeSlot>[];
  var from = 0;
  for (final t in timed) {
    if (t.start > from) slots.add((start: from, end: t.start));
    if (t.end > from) from = t.end;
  }
  if (from < PlannerTask.dayMinutes) {
    slots.add((start: from, end: PlannerTask.dayMinutes));
  }
  return slots;
}
