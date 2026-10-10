import 'package:the_app/models/planner_task.dart';

/// A routine in the planner (P8): a block of time that repeats on chosen
/// weekdays, from a date, until a date or for good. It's one item, not
/// copies on days: each day shows the routines that fall on it.
class Routine {
  final String id;
  final String title;

  /// Start and end, in minutes from midnight, as for [PlannerTask].
  final int start;
  final int end;

  /// The weekdays it's on: [DateTime.monday] (1) to [DateTime.sunday] (7).
  final Set<int> weekdays;

  /// The first day it can be on (a local date at midnight).
  final DateTime from;

  /// The last day it can be on, or null for no end.
  final DateTime? until;

  /// Its colour (P9): a [BlockColor] name, or null for the default.
  final String? color;

  Routine({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required Set<int> weekdays,
    required DateTime from,
    DateTime? until,
    this.color,
  })  : weekdays = Set.unmodifiable(weekdays),
        from = DateTime(from.year, from.month, from.day),
        until = until == null
            ? null
            : DateTime(until.year, until.month, until.day) {
    if (start < 0 || end > PlannerTask.dayMinutes || start >= end) {
      throw ArgumentError('Invalid time: $start–$end');
    }
    if (weekdays.isEmpty || weekdays.any((d) => d < 1 || d > 7)) {
      throw ArgumentError('Invalid weekdays: $weekdays');
    }
    if (this.until != null && this.until!.isBefore(this.from)) {
      throw ArgumentError('Ends before it starts');
    }
  }

  /// Whether it falls on [day].
  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return weekdays.contains(d.weekday) &&
        !d.isBefore(from) &&
        (until == null || !d.isAfter(until!));
  }

  /// Whether it and [other] can fall on the same day.
  bool sharesDaysWith(Routine other) =>
      weekdays.any(other.weekdays.contains) &&
      (until == null || !until!.isBefore(other.from)) &&
      (other.until == null || !other.until!.isBefore(from));

  /// Whether their times of day overlap.
  bool overlapsInTime(Routine other) => start < other.end && other.start < end;

  Routine copyWith({
    String? title,
    int? start,
    int? end,
    Set<int>? weekdays,
    DateTime? from,
    DateTime? Function()? until,
    String? Function()? color,
  }) =>
      Routine(
        id: id,
        title: title ?? this.title,
        start: start ?? this.start,
        end: end ?? this.end,
        weekdays: weekdays ?? this.weekdays,
        from: from ?? this.from,
        until: until == null ? this.until : until(),
        color: color == null ? this.color : color(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start,
        'end': end,
        'weekdays': weekdays.toList()..sort(),
        'from': PlannerTask.dayToJson(from),
        if (until != null) 'until': PlannerTask.dayToJson(until!),
        if (color != null) 'color': color,
      };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
        id: json['id'] as String,
        title: json['title'] as String,
        start: json['start'] as int,
        end: json['end'] as int,
        weekdays: {for (final d in json['weekdays'] as List<dynamic>) d as int},
        from: PlannerTask.dayFromJson(json['from']),
        until: json['until'] == null
            ? null
            : PlannerTask.dayFromJson(json['until']),
        color: json['color'] as String?,
      );
}

/// What happened to a routine on one day: ticked off, or skipped.
class RoutineDay {
  final String routineId;
  final DateTime day;
  final bool done;
  final bool skipped;

  RoutineDay({
    required this.routineId,
    required DateTime day,
    this.done = false,
    this.skipped = false,
  }) : day = DateTime(day.year, day.month, day.day);

  /// Its key in [RoutineBook.days].
  String get key => keyFor(routineId, day);

  static String keyFor(String routineId, DateTime day) =>
      '$routineId/${PlannerTask.dayToJson(day)}';

  /// Whether there's anything to keep (else it's dropped).
  bool get isEmpty => !done && !skipped;

  Map<String, dynamic> toJson() => {
        'routine': routineId,
        'day': PlannerTask.dayToJson(day),
        if (done) 'done': true,
        if (skipped) 'skipped': true,
      };

  factory RoutineDay.fromJson(Map<String, dynamic> json) => RoutineDay(
        routineId: json['routine'] as String,
        day: PlannerTask.dayFromJson(json['day']),
        done: json['done'] as bool? ?? false,
        skipped: json['skipped'] as bool? ?? false,
      );
}

/// All routines, and what happened to them on particular days.
class RoutineBook {
  final List<Routine> routines;

  /// By [RoutineDay.key].
  final Map<String, RoutineDay> days;

  const RoutineBook({this.routines = const [], this.days = const {}});

  static const empty = RoutineBook();

  bool get isEmpty => routines.isEmpty;

  RoutineDay? dayOf(String routineId, DateTime day) =>
      days[RoutineDay.keyFor(routineId, day)];

  Map<String, dynamic> toJson() => {
        'routines': [for (final r in routines) r.toJson()],
        'days': [for (final d in days.values) d.toJson()],
      };

  /// Throws if anything is malformed, or a day belongs to no routine.
  factory RoutineBook.fromJson(Map<String, dynamic> json) {
    final routines = [
      for (final r in json['routines'] as List<dynamic>)
        Routine.fromJson(r as Map<String, dynamic>),
    ];
    final ids = {for (final r in routines) r.id};
    if (ids.length != routines.length) {
      throw const FormatException('Duplicate routine ids');
    }
    final days = <String, RoutineDay>{};
    for (final d in json['days'] as List<dynamic>) {
      final day = RoutineDay.fromJson(d as Map<String, dynamic>);
      if (!ids.contains(day.routineId)) {
        throw FormatException('Day of no routine: ${day.routineId}');
      }
      if (!day.isEmpty) days[day.key] = day;
    }
    return RoutineBook(routines: routines, days: days);
  }
}
