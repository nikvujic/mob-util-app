import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/data/reminder_scheduler.dart';
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
    List<int> reminds = const [],
    bool done = false,
  }) =>
      PlannerTask(
        id: title,
        title: title,
        day: day ?? today,
        start: at(from),
        end: at(to ?? from + 1),
        reminds: reminds,
        done: done,
      );

  test('tasks with a reminder, before their start, if still ahead', () {
    final reminders = planReminders(
      now: now,
      tasks: [
        task('Dentist', from: 15, reminds: [10]),
        task('Lunch', from: 13, reminds: [0]),
        task('No reminder', from: 16),
        task('Done', from: 17, reminds: [5], done: true),
        task('Too late', from: 12.25, reminds: [30]), // was due at 11:45
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
          reminds: [60],
        ),
      ],
      routines: RoutineBook.empty,
    );
    expect(reminders.single.at, DateTime(2026, 10, 8, 23, 15));
    expect(reminders.single.body, 'In 1 h · 00:15–01:15');
  });

  test(
      'routines remind on each of their days for two weeks, '
      'not when skipped', () {
    final gym = Routine(
      id: 'gym',
      title: 'Gym',
      start: at(18),
      end: at(19),
      weekdays: {DateTime.monday, DateTime.thursday},
      from: DateTime(2026, 10, 1),
      reminds: [15],
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
      // An old tick (routines aren't ticked off now) is no
      // reason to stay quiet.
      DateTime(2026, 10, 15, 17, 45),
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
      reminds: [0],
    );
    final reminders = planReminders(
      now: now,
      tasks: [
        task('Call mum', from: 18, to: 20, reminds: [10])
      ],
      routines: RoutineBook(routines: [gym]),
    );
    expect([for (final r in reminders) r.title], ['Call mum', 'Gym']);
  });

  test('with the Planner locked, titles are left out', () {
    final reminders = planReminders(
      now: now,
      tasks: [
        task('Therapy', from: 15, reminds: [10])
      ],
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
            reminds: [0],
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

  test(
      'several reminders for one block, up to two days before; one due '
      'in the days planned even for a block past them', () {
    final reminders = planReminders(
      now: now,
      tasks: [
        task('Trip',
            from: 10, day: addDays(today, 3), reminds: [0, 60, 1440, 2880]),
        // Past the 14 days planned; its 2-day reminder falls inside them.
        task('Far', from: 10, day: addDays(today, 15), reminds: [2880, 1440]),
      ],
      routines: RoutineBook.empty,
    );
    String when(Reminder r) =>
        '${daysBetween(today, DateTime(r.at.year, r.at.month, r.at.day))}d '
        '${r.at.hour}:${r.at.minute.toString().padLeft(2, '0')} '
        '${r.title} ${r.body.split(' · ').first}';
    expect([
      for (final r in reminders) when(r)
    ], [
      '1d 10:00 Trip In 2 days',
      '2d 10:00 Trip Tomorrow',
      '3d 9:00 Trip In 1 h',
      '3d 10:00 Trip Now',
      '13d 10:00 Far In 2 days',
      '14d 10:00 Far Tomorrow',
    ]);
  });

  test('a routine with several reminders reminds of each', () {
    final yoga = Routine(
      id: 'y',
      title: 'Yoga',
      start: 18 * 60,
      end: 19 * 60,
      weekdays: {for (var d = 1; d <= 7; d++) d},
      from: today,
      until: today,
      reminds: [0, 30],
    );
    final reminders = planReminders(
      now: now,
      tasks: const [],
      routines: RoutineBook(routines: [yoga]),
    );
    expect([for (final r in reminders) '${r.at.hour}:${r.at.minute}'],
        ['17:30', '18:0']);
  });

  test("older files' single reminder reads as one; several written both ways",
      () {
    final old = PlannerTask.fromJson({
      'id': 'a',
      'title': 'A',
      'day': '2026-10-09',
      'start': 600,
      'end': 660,
      'done': false,
      'remind': 15,
    });
    expect(old.reminds, [15]);
    final several = task('B', from: 10, reminds: [60, 0, 60, 1440]);
    expect(several.reminds, [0, 60, 1440], reason: 'each once, nearest first');
    final json = several.toJson();
    expect(json['remind'], 0, reason: 'what older versions read');
    expect(json['reminds'], [0, 60, 1440]);
    expect(PlannerTask.fromJson(json).reminds, [0, 60, 1440]);
    expect(task('C', from: 10).toJson().containsKey('remind'), isFalse);
  });
}
