import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';

/// Planner routines (P8).
void main() {
  late ProviderContainer container;

  /// Monday 12 October 2026, and the days after.
  final monday = DateTime(2026, 10, 12);
  final tuesday = DateTime(2026, 10, 13);
  final wednesday = DateTime(2026, 10, 14);
  final nextMonday = DateTime(2026, 10, 19);
  int at(num hours) => (hours * 60).round();

  setUp(() {
    container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(AppStorage.inMemory())],
    );
    addTearDown(container.dispose);
  });

  RoutinesNotifier routines() => container.read(routinesProvider.notifier);
  PlannerNotifier planner() => container.read(plannerProvider.notifier);
  RoutineBook book() => container.read(routinesProvider);

  /// Gym, Mon/Wed/Fri 18–19, from [monday], for good.
  String gym() => routines().add(
        title: 'Gym',
        start: at(18),
        end: at(19),
        weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
        from: monday,
      )!;

  List<String> shownOn(DateTime day) => [
        for (final o in routinesOn(
          day,
          book(),
          container.read(plannerProvider).where((t) => isSameDay(t.day, day)),
        ))
          o.routine.title,
      ];

  test('a routine shows on its weekdays, from its first day, until its last',
      () {
    routines().add(
      title: 'Read',
      start: at(22),
      end: at(23),
      weekdays: {1, 2, 3, 4, 5, 6, 7},
      from: tuesday,
      until: wednesday,
    );
    gym();
    expect(shownOn(monday), ['Gym']);
    expect(shownOn(tuesday), ['Read']);
    expect(shownOn(wednesday), ['Gym', 'Read']);
    expect(shownOn(nextMonday), ['Gym'], reason: 'Read has ended');
    expect(shownOn(DateTime(2026, 10, 5)), isEmpty, reason: 'before it');
  });

  test('routines never overlap on a weekday they share', () {
    gym();
    expect(
      () => routines().add(
        title: 'Run',
        start: at(18.5),
        end: at(19.5),
        weekdays: {DateTime.wednesday},
        from: monday,
      ),
      throwsA(isA<TaskOverlapException>()),
    );
    // Another weekday, or a time next to it, is fine.
    routines()
      ..add(
        title: 'Swim',
        start: at(18),
        end: at(19),
        weekdays: {DateTime.tuesday},
        from: monday,
      )
      ..add(
        title: 'Stretch',
        start: at(19),
        end: at(19.5),
        weekdays: {DateTime.monday},
        from: monday,
      );
    expect(book().routines, hasLength(3));
  });

  test('routines that end before another starts may share its time', () {
    routines().add(
      title: 'Old',
      start: at(18),
      end: at(19),
      weekdays: {DateTime.monday},
      from: DateTime(2026, 9, 1),
      until: DateTime(2026, 10, 1),
    );
    gym();
    expect(book().routines, hasLength(2));
  });

  test('a one-off task already there wins: the routine stays away that day',
      () {
    planner().addTask(monday, 'Dentist', start: at(17.5), end: at(18.5));
    gym();
    expect(shownOn(monday), isEmpty);
    expect(shownOn(wednesday), ['Gym'], reason: 'only that day');
  });

  test('new one-off tasks can\'t go over a routine', () {
    gym();
    expect(
      () => planner().addTask(monday, 'X', start: at(18.5), end: at(20)),
      throwsA(isA<TaskOverlapException>()),
    );
    // Next to it is fine, and so is a day without it.
    planner()
      ..addTask(monday, 'Dinner', start: at(19), end: at(20))
      ..addTask(tuesday, 'X', start: at(18.5), end: at(20));
  });

  test('editing a task that keeps a routine away doesn\'t clash with it', () {
    planner().addTask(monday, 'Dentist', start: at(17.5), end: at(18.5));
    gym();
    final id = container.read(plannerProvider).single.id;
    planner().updateTask(id, title: 'Doctor', start: at(17.5), end: at(18.5));
    expect(container.read(plannerProvider).single.title, 'Doctor');
  });

  test('ticking off and skipping count for one day only', () {
    final id = gym();
    routines().toggleDone(id, monday);
    expect(book().dayOf(id, monday)!.done, isTrue);
    expect(book().dayOf(id, wednesday), isNull);

    routines().setSkipped(id, wednesday, skipped: true);
    expect(shownOn(wednesday), isEmpty);
    expect(shownOn(nextMonday), ['Gym']);

    routines().setSkipped(id, wednesday, skipped: false);
    routines().toggleDone(id, monday);
    expect(book().days, isEmpty, reason: 'nothing left to keep');
  });

  test('editing changes every day, past too; ticks and skips stay', () {
    final id = gym();
    routines().toggleDone(id, monday);
    routines().setSkipped(id, wednesday, skipped: true);

    routines().update(
      id,
      title: 'Gym (long)',
      start: at(17),
      end: at(19),
      weekdays: {DateTime.monday, DateTime.wednesday},
      until: null,
    );
    final routine = book().routines.single;
    expect((routine.title, routine.start), ('Gym (long)', at(17)));
    expect(book().dayOf(id, monday)!.done, isTrue);
    expect(shownOn(wednesday), isEmpty);
    expect(shownOn(DateTime(2026, 10, 16)), isEmpty, reason: 'no Fridays');
  });

  test('deleting removes it from every day, with its ticks', () {
    final id = gym();
    routines().toggleDone(id, monday);
    routines().remove(id);
    expect(book().routines, isEmpty);
    expect(book().days, isEmpty);
    expect(shownOn(monday), isEmpty);
  });

  test('room: the free time around it, on all its weekdays', () {
    gym();
    routines()
      ..add(
        title: 'Dinner',
        start: at(20),
        end: at(21),
        weekdays: {DateTime.wednesday},
        from: monday,
      )
      ..add(
        title: 'Lunch',
        start: at(12),
        end: at(13),
        weekdays: {DateTime.friday},
        from: monday,
      );
    final gymRoutine = book().routines.first;
    expect(routines().roomFor(gymRoutine), (start: at(13), end: at(20)));
  });

  test('a blank title adds nothing', () {
    expect(
      routines().add(
        title: '  ',
        start: 0,
        end: 60,
        weekdays: {1},
        from: monday,
      ),
      isNull,
    );
    expect(book().routines, isEmpty);
  });
}
