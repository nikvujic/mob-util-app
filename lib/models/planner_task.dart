/// A to-do for one day in the planner (P2).
class PlannerTask {
  final String id;
  final String title;

  /// The day it's planned for: a local date at midnight (no time of day).
  final DateTime day;
  final bool done;

  PlannerTask({
    required this.id,
    required this.title,
    required DateTime day,
    this.done = false,
  }) : day = DateTime(day.year, day.month, day.day);

  PlannerTask copyWith({bool? done}) =>
      PlannerTask(id: id, title: title, day: day, done: done ?? this.done);

  /// `2026-10-09`: a calendar date, the same in every time zone.
  static String dayToJson(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'day': dayToJson(day),
        'done': done,
      };

  factory PlannerTask.fromJson(Map<String, dynamic> json) {
    final day = json['day'] as String;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      throw FormatException('Not a day: $day');
    }
    return PlannerTask(
      id: json['id'] as String,
      title: json['title'] as String,
      day: DateTime.parse(day),
      done: json['done'] as bool,
    );
  }
}
