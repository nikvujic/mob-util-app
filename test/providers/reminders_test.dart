import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/providers/reminders_provider.dart';

/// Planning planner reminders (P10).
void main() {
  /// Thursday 8 October 2026, 12:00.
  final now = DateTime(2026, 10, 8, 12);
  final today = DateTime(2026, 10, 8);
  int at(num hours) => (hours * 60).round();

  PlannerTask task(
    String title, {
    DateTime? day,
    required num from,
    num? to,
    int? remind,
    bool done = false,
  }) =>
      PlannerTask(
        id: title,
        title: title,
        day: day ?? today,
        start: at(from),
        end: at(to ?? from + 1),
        remind: remind,
        done: done,
      );

  test('tasks with a reminder, before their start, if still ahead', () {
    final reminders = planReminders(
      now: now,
      tasks: [
        task('Dentist', from: 15, remind: 10),
        task('Lunch', from: 13, remind: 0),
        task('No reminder', from: 16),
        task('Done', from: 17, remind: 5, done: true),
        task('Too late', from: 12.25, remind: 30), // was due at 11:45
      ],
      routines: RoutineBook.empty,
    );
    expect(
      reminders.map((r) => '${r.at.hour}:${r.at.minute} ${r.title}'),
      ['13:0 Lunch', '14:50 Dentist'],
    );
    expect(reminders.first.body, 'Now · 13:00–14:00');
    expect(reminders.last.body, 'In 10 min · 15:00–16:00');
  });

  test('the planner\'s reminders (P14) notify at their time', () {
    PlannerPin pin(String title, DateTime day, num hours) =>
        PlannerPin(id: title, title: title, day: day, time: at(hours));
    final reminders = planReminders(
      now: now,
      tasks: const [],
      routines: RoutineBook.empty,
      pins: [
        pin('Call mum', today, 12.5),
        pin('Past', today, 11.5),
        pin('Bins', DateTime(2026, 10, 9), 20),
        pin('Too far ahead', addDays(today, reminderDays + 1), 9),
      ],
    );
    expect(
      reminders
          .map((r) => '${r.at.day} ${r.at.hour}:${r.at.minute} ${r.title}'),
      ['8 12:30 Call mum', '9 20:0 Bins'],
    );
    expect(reminders.first.body, 'Reminder · 12:30');

    final hidden = planReminders(
      now: now,
      tasks: const [],
      routines: RoutineBook.empty,
      pins: [pin('Call mum', today, 12.5)],
      hideTitles: true,
    );
    expect((hidden.single.title, hidden.single.body),
        ('Planner', 'A reminder at 12:30'));
  });

  test('a reminder can fall on the day before', () {
    final reminders = planReminders(
      now: now,
      tasks: [
        task(
          'Early',
          day: DateTime(2026, 10, 9),
          from: 0.25,
          remind: 60,
        ),
      ],
      routines: RoutineBook.empty,
    );
    expect(reminders.single.at, DateTime(2026, 10, 8, 23, 15));
    expect(reminders.single.body, 'In 1 h · 00:15–01:15');
  });

  test(
      'routines remind on each of their days for two weeks, '
      'not when ticked off or skipped', () {
    final gym = Routine(
      id: 'gym',
      title: 'Gym',
      start: at(18),
      end: at(19),
      weekdays: {DateTime.monday, DateTime.thursday},
      from: DateTime(2026, 10, 1),
      remind: 15,
    );
    final skipped = RoutineDay(
      routineId: 'gym',
      day: DateTime(2026, 10, 12),
      skipped: true,
    );
    final ticked = RoutineDay(
      routineId: 'gym',
      day: DateTime(2026, 10, 15),
      done: true,
    );
    final reminders = planReminders(
      now: now,
      tasks: const [],
      routines: RoutineBook(
        routines: [gym],
        days: {skipped.key: skipped, ticked.key: ticked},
      ),
    );
    expect(reminders.map((r) => r.at), [
      DateTime(2026, 10, 8, 17, 45), // today
      DateTime(2026, 10, 19, 17, 45),
      DateTime(2026, 10, 22, 17, 45), // the 14th day ahead
    ]);
  });

  test('a task and a routine at the same time both remind', () {
    final gym = Routine(
      id: 'gym',
      title: 'Gym',
      start: at(18),
      end: at(19),
      weekdays: {DateTime.thursday},
      from: today,
      until: today,
      remind: 0,
    );
    final reminders = planReminders(
      now: now,
      tasks: [task('Call mum', from: 18, to: 20, remind: 10)],
      routines: RoutineBook(routines: [gym]),
    );
    expect([for (final r in reminders) r.title], ['Call mum', 'Gym']);
  });

  test('with the Planner locked, titles are left out', () {
    final reminders = planReminders(
      now: now,
      tasks: [task('Therapy', from: 15, remind: 10)],
      routines: RoutineBook.empty,
      hideTitles: true,
    );
    expect(reminders.single.title, 'Planner');
    expect(reminders.single.body, 'A block starts at 15:00');
    expect('${reminders.single}', isNot(contains('Therapy')));
  });

  test('at most $maxReminders are planned, the soonest', () {
    // 40 reminders a day for 14 days: 560.
    final tasks = [
      for (var d = 1; d <= 14; d++)
        for (var i = 0; i < 40; i++)
          PlannerTask(
            id: '$d-$i',
            title: '$d-$i',
            day: DateTime(2026, 10, 8 + d),
            start: i * 30,
            end: i * 30 + 30,
            remind: 0,
          ),
    ];
    final reminders =
        planReminders(now: now, tasks: tasks, routines: RoutineBook.empty);
    expect(reminders, hasLength(maxReminders));
    expect(reminders.first.title, '1-0');
    final latest = reminders.last.at;
    final dropped = tasks.length - maxReminders;
    expect(dropped, 160);
    expect(latest.isBefore(DateTime(2026, 10, 19)), isTrue,
        reason: 'the latest ones are dropped');
  });
}
