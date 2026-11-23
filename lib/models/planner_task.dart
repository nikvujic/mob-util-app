/// A task in the planner (P2, P7): a block of time on one day, which can be
/// ticked off when done.
class PlannerTask {
  /// Minutes in a day: times run from 0 (00:00) to this (24:00).
  static const dayMinutes = 24 * 60;

  /// The shortest a new block (task or routine) can be (at the
  /// largest zoom, 5 minutes is one touch target high).
  static const minMinutes = 5;

  /// Throws [ArgumentError] if [start]–[end] is shorter than [minMinutes]
  /// (new or changed times; older, shorter blocks stay as they were).
  static void checkLength(int start, int end) {
    if (end - start < minMinutes) {
      throw ArgumentError('Shorter than $minMinutes minutes: $start–$end');
    }
  }

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

  /// Its reminders (P10): each so many minutes before its start (0: at
  /// the start), soonest-before first; none, no reminder.
  final List<int> reminds;

  /// The reminder nearest its start, or null for none.
  int? get remind => reminds.isEmpty ? null : reminds.first;

  /// [minutes] as kept: each once, the nearest the start first.
  static List<int> sortedReminds(Iterable<int> minutes) =>
      List.unmodifiable({...minutes}.toList()..sort());

  /// A reminder list as stored: `reminds` (since several), else the one
  /// `remind` before them.
  static List<int> remindsFromJson(Map<String, dynamic> json) {
    final list = json['reminds'];
    if (list is List) return sortedReminds([for (final m in list) m as int]);
    final one = json['remind'] as int?;
    return one == null ? const [] : [one];
  }

  /// [reminds] as stored: the list, and the nearest one alone (as older
  /// versions read it).
  static Map<String, dynamic> remindsToJson(List<int> reminds) => {
        if (reminds.isNotEmpty) 'remind': reminds.first,
        if (reminds.length > 1) 'reminds': reminds,
      };

  /// More about it (P20), or null.
  final String? description;

  PlannerTask({
    required this.id,
    required this.title,
    required DateTime day,
    this.start,
    this.end,
    this.done = false,
    this.color,
    List<int> reminds = const [],
    this.description,
  })  : day = DateTime(day.year, day.month, day.day),
        reminds = sortedReminds(reminds) {
    if (this.reminds.any((m) => m < 0)) {
      throw ArgumentError('Invalid reminder: $reminds');
    }
    if ((start == null) != (end == null) ||
        (start != null &&
            (start! < 0 || end! > dayMinutes || start! >= end!))) {
      throw ArgumentError('Invalid time: $start–$end');
    }
  }

  /// Whether it has a place on the timeline (tasks from v1 don't).
  bool get hasTime => start != null;

  PlannerTask copyWith({bool? done, DateTime? day, int? start, int? end}) =>
      PlannerTask(
        id: id,
        title: title,
        day: day ?? this.day,
        start: start ?? this.start,
        end: end ?? this.end,
        done: done ?? this.done,
        color: color,
        reminds: reminds,
        description: description,
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
        ...remindsToJson(reminds),
        if (description != null) 'description': description,
      };

  factory PlannerTask.fromJson(Map<String, dynamic> json) => PlannerTask(
        id: json['id'] as String,
        title: json['title'] as String,
        day: dayFromJson(json['day']),
        start: json['start'] as int?,
        end: json['end'] as int?,
        done: json['done'] as bool,
        color: json['color'] as String?,
        reminds: remindsFromJson(json),
        description: json['description'] as String?,
      );
}

/// A free stretch of a day's timeline, in minutes (end exclusive).
typedef FreeSlot = ({int start, int end});

/// A stretch of time in a day, in minutes (end exclusive).
typedef TimeSpan = ({int start, int end});

/// Where [span] fits in [free] (a block moved to another day):
/// itself if it's free there, else the nearest time of its length (the
/// earlier of two as near); null if no free stretch is that long.
TimeSpan? fitTime(List<FreeSlot> free, TimeSpan span) {
  final length = span.end - span.start;
  TimeSpan? best;
  for (final slot in free) {
    if (slot.end - slot.start < length) continue;
    final start = span.start.clamp(slot.start, slot.end - length);
    if (best == null ||
        (start - span.start).abs() < (best.start - span.start).abs()) {
      best = (start: start, end: start + length);
    }
  }
  return best;
}

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
