import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';

/// A scheduler that takes its time, like the real one (each reminder is a
/// call to Android): [release] lets the current [replaceAll] finish.
class _SlowScheduler implements ReminderScheduler {
  final calls = <List<String>>[];
  int running = 0;
  int mostAtOnce = 0;
  Completer<void>? _gate;

  void release() => _gate?.complete();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> areAllowed() async => true;

  @override
  Stream<String> get opened => const Stream.empty();

  @override
  Future<String?> takeLaunch() async => null;

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {
    running++;
    if (running > mostAtOnce) mostAtOnce = running;
    calls.add([for (final r in reminders) r.title]);
    _gate = Completer<void>();
    await _gate!.future;
    running--;
  }
}

void main() {
  test('refreshes run one at a time; the last one has the latest', () async {
    final scheduler = _SlowScheduler();
    final container = ProviderContainer(overrides: [
      appStorageProvider.overrideWithValue(AppStorage.inMemory()),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 8, 9)),
    ]);
    addTearDown(container.dispose);
    final planner = container.read(reminderPlannerProvider);
    await Future<void>.delayed(Duration.zero); // the first plan starts
    expect(scheduler.calls, [<String>[]]);

    // Changes while it's still scheduling.
    container.read(plannerProvider.notifier).addTask(
        DateTime(2026, 10, 8), 'Dentist',
        start: 600, end: 660, remind: 0);
    final again = planner.refresh(); // e.g. the app came back
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.running, 1, reason: 'waits for the one running');

    scheduler.release();
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.calls.last, ['Dentist']);
    scheduler.release();
    await again;

    expect(scheduler.mostAtOnce, 1);
    expect(scheduler.calls, hasLength(2), reason: 'the changes planned once');
  });
}
