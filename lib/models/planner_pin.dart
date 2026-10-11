import 'package:the_app/models/planner_task.dart';

/// A reminder on the planner (P14): a title at a time on one day, with no
/// end. It floats over the timeline without taking up time, notifies at
/// its time, and is deleted once ticked off. ("Pin" in code; "reminder"
/// in the app.)
class PlannerPin {
  final String id;
  final String title;

  /// A local date at midnight.
  final DateTime day;

  /// Minutes from midnight, 0 to 23:59.
  final int time;

  PlannerPin({
    required this.id,
    required this.title,
    required DateTime day,
    required this.time,
  }) : day = DateTime(day.year, day.month, day.day) {
    if (time < 0 || time >= PlannerTask.dayMinutes) {
      throw ArgumentError('Invalid time: $time');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'day': PlannerTask.dayToJson(day),
        'time': time,
      };

  factory PlannerPin.fromJson(Map<String, dynamic> json) => PlannerPin(
        id: json['id'] as String,
        title: json['title'] as String,
        day: PlannerTask.dayFromJson(json['day']),
        time: json['time'] as int,
      );
}
