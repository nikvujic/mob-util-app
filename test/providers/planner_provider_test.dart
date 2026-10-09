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

  setUp(() => planner = PlannerNotifier(AppStorage.inMemory()));

  List<String> titlesOn(DateTime day) => planner.state
      .where((t) => isSameDay(t.day, day))
      .map((t) => t.title)
      .toList();
  String idOf(String title) =>
      planner.state.firstWhere((t) => t.title == title).id;

  test('adds trimmed tasks at the end of their day; ignores blanks', () {
    planner
      ..addTask(monday, 'Gym')
      ..addTask(tuesday, 'Dentist')
      ..addTask(monday, '  Groceries ')
      ..addTask(monday, '   ');

    expect(titlesOn(monday), ['Gym', 'Groceries']);
    expect(titlesOn(tuesday), ['Dentist']);
  });

  test('a task keeps only the date of its day', () {
    planner.addTask(DateTime(2026, 10, 12, 23, 59), 'Late');
    expect(planner.state.single.day, monday);
  });

  test('toggleDone marks a task done and back', () {
    planner.addTask(monday, 'Gym');
    planner.toggleDone(idOf('Gym'));
    expect(planner.state.single.done, isTrue);
    planner.toggleDone(idOf('Gym'));
    expect(planner.state.single.done, isFalse);
  });

  test('reorder moves tasks within one day only', () {
    planner
      ..addTask(monday, 'A')
      ..addTask(tuesday, 'X')
      ..addTask(monday, 'B')
      ..addTask(monday, 'C');

    planner.reorder(monday, 0, 3); // A to the end of Monday
    expect(titlesOn(monday), ['B', 'C', 'A']);
    expect(titlesOn(tuesday), ['X']);
  });

  test('removeTasks deletes only the given tasks', () {
    planner
      ..addTask(monday, 'A')
      ..addTask(tuesday, 'B');
    planner.removeTasks({idOf('A')});
    expect(planner.state.map((t) => t.title), ['B']);
  });

  test('tasks are saved and survive a restart', () async {
    final dir = Directory.systemTemp.createTempSync('planner');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    planner = PlannerNotifier(storage)
      ..addTask(monday, 'Gym')
      ..addTask(tuesday, 'Dentist');
    planner.toggleDone(idOf('Gym'));
    await storage.flush();

    final file = File('${dir.path}/planner.json').readAsStringSync();
    expect(file, contains('"day":"2026-10-12"'), reason: 'a plain date');

    final reopened =
        (await AppStorage.open(directory: dir)).initialPlannerTasks;
    expect(
        reopened.map((t) => t.toJson()), planner.state.map((t) => t.toJson()));
    expect(reopened.first.day, monday);
  });

  test('a damaged day makes the file unreadable, so it is set aside', () async {
    final dir = Directory.systemTemp.createTempSync('planner');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/planner.json').writeAsStringSync(
      jsonEncode({
        'version': 2,
        'tasks': [
          {'id': '1', 'title': 'x', 'day': 'Monday', 'done': false},
        ],
      }),
    );

    final storage = await AppStorage.open(directory: dir);
    expect(storage.initialPlannerTasks, isEmpty);
    expect(
      dir.listSync().map((f) => f.uri.pathSegments.last),
      contains(startsWith('planner.json.corrupt-')),
    );
  });

  test('day JSON is a calendar date', () {
    expect(PlannerTask.dayToJson(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
