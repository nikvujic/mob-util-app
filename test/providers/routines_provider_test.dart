import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/planner_task.dart';
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
        for (final o in routinesOn(day, book())) o.routine.title,
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

  group('a task and a routine may share time (P12)', () {
    test('a routine shows where a task already is', () {
      planner().addTask(monday, 'Dentist', start: at(17.5), end: at(18.5));
      gym();
      expect(shownOn(monday), ['Gym']);
    });

    test('a task can go over a routine, but not over another task', () {
      gym();
      planner().addTask(monday, 'Call', start: at(18.5), end: at(20));
      expect(shownOn(monday), ['Gym'], reason: 'side by side');
      expect(
        () => planner().addTask(monday, 'X', start: at(19.5), end: at(21)),
        throwsA(isA<TaskOverlapException>()),
        reason: 'two tasks never share time',
      );
    });

    test('editing a task can move it over a routine', () {
      gym();
      planner().addTask(monday, 'Dentist', start: at(16), end: at(17));
      final id = container.read(plannerProvider).single.id;
      planner().updateTask(id, title: 'Dentist', start: at(17), end: at(19));
      expect(container.read(plannerProvider).single.end, at(19));
    });

    test('a task\'s room reaches past routines, up to the next task', () {
      gym();
      planner()
        ..addTask(monday, 'Lunch', start: at(12), end: at(13))
        ..addTask(monday, 'Film', start: at(20), end: at(22));
      final lunch =
          container.read(plannerProvider).firstWhere((t) => t.title == 'Lunch');
      expect(planner().roomFor(lunch), (start: 0, end: at(20)));
      expect(planner().freeOn(monday), [
        (start: 0, end: at(12)),
        (start: at(13), end: at(20)),
        (start: at(22), end: at(24)),
      ]);
    });

    test('routines still never overlap each other', () {
      planner().addTask(monday, 'Dentist', start: at(17), end: at(19));
      gym();
      expect(
        () => routines().add(
          title: 'Run',
          start: at(18.5),
          end: at(20),
          weekdays: {DateTime.monday},
          from: monday,
        ),
        throwsA(isA<TaskOverlapException>()),
      );
    });
  });

  test('skipping counts for one day only', () {
    final id = gym();
    routines().setSkipped(id, wednesday, skipped: true);
    expect(shownOn(wednesday), isEmpty);
    expect(shownOn(nextMonday), ['Gym']);
    expect(book().dayOf(id, monday), isNull);

    routines().setSkipped(id, wednesday, skipped: false);
    expect(book().days, isEmpty, reason: 'nothing left to keep');
  });

  test('editing changes every day, past too; skips stay', () {
    final id = gym();
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
    expect(shownOn(wednesday), isEmpty);
    expect(shownOn(DateTime(2026, 10, 16)), isEmpty, reason: 'no Fridays');
  });

  test('deleting removes it from every day, with its skips', () {
    final id = gym();
    routines().setSkipped(id, monday, skipped: true);
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

  test('room around times: follows the weekdays and dates asked about', () {
    gym(); // Mon/Wed/Fri 18–19, for good
    routines().add(
      title: 'Later',
      start: at(18),
      end: at(19),
      weekdays: {DateTime.tuesday},
      from: DateTime(2026, 11, 3), // starts in November
    );
    FreeSlot around({required Set<int> on, DateTime? until}) =>
        routines().roomAround(
          weekdays: on,
          from: monday,
          until: until,
          start: at(18.5),
          end: at(19.5),
        );

    expect(around(on: {DateTime.thursday}), (start: 0, end: at(24)));
    // Monday has Gym: the free time with most of 18:30–19:30 is after it.
    expect(around(on: {DateTime.monday}), (start: at(19), end: at(24)));
    // A routine that starts later counts too, unless this one ends first.
    expect(around(on: {DateTime.tuesday}), (start: at(19), end: at(24)));
    expect(
      around(on: {DateTime.tuesday}, until: DateTime(2026, 10, 31)),
      (start: 0, end: at(24)),
    );
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
