import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/providers/planner_provider.dart';

void main() {
  late PlannerNotifier planner;

  final monday = DateTime(2026, 10, 12);
  final tuesday = DateTime(2026, 10, 13);

  /// [hours] like 8.5 → minutes from midnight.
  int at(num hours) => (hours * 60).round();

  setUp(() => planner = PlannerNotifier(AppStorage.inMemory()));

  List<String> titlesOn(DateTime day) => planner.state
      .where((t) => isSameDay(t.day, day))
      .map((t) => t.title)
      .toList();
  String idOf(String title) =>
      planner.state.firstWhere((t) => t.title == title).id;

  test('adds trimmed tasks with their times; ignores blank titles', () {
    planner
      ..addTask(monday, 'Gym', start: at(8), end: at(9))
      ..addTask(tuesday, 'Dentist', start: at(8), end: at(9))
      ..addTask(monday, '  Groceries ', start: at(18), end: at(18.5))
      ..addTask(monday, '   ', start: at(20), end: at(21));

    expect(titlesOn(monday), ['Gym', 'Groceries']);
    expect(titlesOn(tuesday), ['Dentist'], reason: 'other days are separate');
    final groceries = planner.state.firstWhere((t) => t.title == 'Groceries');
    expect((groceries.start, groceries.end), (18 * 60, 18 * 60 + 30));
  });

  test('tasks never overlap', () {
    planner.addTask(monday, 'Gym', start: at(8), end: at(9));

    for (final (start, end) in [(7.5, 8.5), (8.5, 9.5), (8, 9), (7, 10)]) {
      expect(
        () => planner.addTask(monday, 'X', start: at(start), end: at(end)),
        throwsA(isA<TaskOverlapException>()),
        reason: '$start–$end',
      );
    }
    // Touching is fine.
    planner
      ..addTask(monday, 'Before', start: at(7), end: at(8))
      ..addTask(monday, 'After', start: at(9), end: at(10));
    expect(titlesOn(monday), ['Gym', 'Before', 'After']);
  });

  test('times must make sense', () {
    expect(
      () => planner.addTask(monday, 'X', start: at(9), end: at(9)),
      throwsArgumentError,
    );
    expect(
      () => planner.addTask(monday, 'X', start: at(23), end: at(25)),
      throwsArgumentError,
    );
  });

  test('free slots are the gaps of the day, 00:00–24:00', () {
    expect(freeSlots(const []), [(start: 0, end: 1440)]);

    planner
      ..addTask(monday, 'Gym', start: at(8), end: at(9))
      ..addTask(monday, 'Work', start: at(9), end: at(17))
      ..addTask(monday, 'Late', start: at(23), end: at(24));
    expect(freeSlots(planner.state), [
      (start: 0, end: at(8)),
      (start: at(17), end: at(23)),
    ]);
  });

  test('a task keeps only the date of its day', () {
    planner.addTask(DateTime(2026, 10, 12, 23, 59), 'Late', start: 0, end: 60);
    expect(planner.state.single.day, monday);
  });

  test('toggleDone marks a task done and back', () {
    planner.addTask(monday, 'Gym', start: at(8), end: at(9));
    planner.toggleDone(idOf('Gym'));
    expect(planner.state.single.done, isTrue);
    planner.toggleDone(idOf('Gym'));
    expect(planner.state.single.done, isFalse);
  });

  test('removeTasks deletes only the given tasks', () {
    planner
      ..addTask(monday, 'A', start: at(8), end: at(9))
      ..addTask(tuesday, 'B', start: at(8), end: at(9));
    planner.removeTasks({idOf('A')});
    expect(planner.state.map((t) => t.title), ['B']);
  });

  test('tasks are saved (planner.json version 4) and survive a restart',
      () async {
    final dir = Directory.systemTemp.createTempSync('planner');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    planner = PlannerNotifier(storage)
      ..addTask(monday, 'Gym', start: at(8), end: at(9))
      ..addTask(tuesday, 'Dentist', start: at(14), end: at(14.5));
    planner.toggleDone(idOf('Gym'));
    await storage.flush();

    final file = jsonDecode(File('${dir.path}/planner.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(file['version'], 4);
    expect(jsonEncode(file), contains('"day":"2026-10-12","start":480'));

    final reopened =
        (await AppStorage.open(directory: dir)).initialPlannerTasks;
    expect(
      reopened.map((t) => t.toJson()),
      planner.state.map((t) => t.toJson()),
    );
  });

  test('tasks from the first planner (no times) are still read', () async {
    final dir = Directory.systemTemp.createTempSync('planner');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/planner.json').writeAsStringSync(
      jsonEncode({
        'version': 2,
        'tasks': [
          {'id': '1', 'title': 'Old', 'day': '2026-10-12', 'done': false},
        ],
      }),
    );

    final task =
        (await AppStorage.open(directory: dir)).initialPlannerTasks.single;
    expect(task.title, 'Old');
    expect(task.hasTime, isFalse);
  });

  test('a damaged task makes the file unreadable, so it is set aside',
      () async {
    for (final damaged in [
      {'id': '1', 'title': 'x', 'day': 'Monday', 'done': false},
      {
        'id': '1',
        'title': 'x',
        'day': '2026-10-12',
        'start': 600,
        'end': 500,
        'done': false
      },
    ]) {
      final dir = Directory.systemTemp.createTempSync('planner');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/planner.json').writeAsStringSync(
        jsonEncode({
          'version': 3,
          'tasks': [damaged]
        }),
      );

      final storage = await AppStorage.open(directory: dir);
      expect(storage.initialPlannerTasks, isEmpty);
      expect(
        dir.listSync().map((f) => f.uri.pathSegments.last),
        contains(startsWith('planner.json.corrupt-')),
      );
    }
  });

  test('day JSON is a calendar date', () {
    expect(PlannerTask.dayToJson(DateTime(2026, 1, 5)), '2026-01-05');
  });

  group('editing', () {
    test('changes title and times; blank title keeps the old one', () {
      planner.addTask(monday, 'Gym', start: at(8), end: at(9));
      planner.toggleDone(idOf('Gym'));

      planner.updateTask(idOf('Gym'), title: 'Run', start: at(7), end: at(8));
      var task = planner.state.single;
      expect((task.title, task.start, task.end), ('Run', at(7), at(8)));
      expect(task.done, isTrue, reason: 'stays ticked off');
      expect(task.day, monday);

      planner.updateTask(idOf('Run'), title: '  ', start: at(7), end: at(9));
      task = planner.state.single;
      expect((task.title, task.end), ('Run', at(9)));
    });

    test('can overlap its own old time, never another task', () {
      planner
        ..addTask(monday, 'Gym', start: at(8), end: at(9))
        ..addTask(monday, 'Work', start: at(10), end: at(17));

      planner.updateTask(idOf('Gym'),
          title: 'Gym', start: at(8.5), end: at(10));
      expect(
        () => planner.updateTask(
          idOf('Gym'),
          title: 'Gym',
          start: at(9),
          end: at(10.5),
        ),
        throwsA(isA<TaskOverlapException>()),
      );
      expect(planner.state.firstWhere((t) => t.title == 'Gym').end, at(10));
    });

    test('room: the free time around a task, up to its neighbours', () {
      planner
        ..addTask(monday, 'Gym', start: at(8), end: at(9))
        ..addTask(monday, 'Lunch', start: at(12), end: at(13))
        ..addTask(monday, 'Work', start: at(14), end: at(17))
        ..addTask(tuesday, 'Other day', start: at(10), end: at(11));

      final lunch = planner.state.firstWhere((t) => t.title == 'Lunch');
      expect(planner.roomFor(lunch), (start: at(9), end: at(14)));
    });
  });
}
