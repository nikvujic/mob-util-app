import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/models/notification_target.dart';

/// A notification tapped (Round 19), waiting for its page to show it: the
/// home screen goes to its section, and the page takes it once it's in
/// view and not locked. Locked, it waits for the next visit after
/// unlocking.
final pendingTargetProvider = StateProvider<NotificationTarget?>((ref) => null);

/// Hears taps on notifications, and the one that started the app; kept
/// running by the home screen.
final notificationOpenerProvider = Provider<void>((ref) {
  final scheduler = ref.watch(reminderSchedulerProvider);
  void take(String? payload) {
    final target = NotificationTarget.parse(payload);
    if (target is PlannerNowTarget) {
      // Round 72: Done on a block that's on ticks it; either way, to it.
      if (target.done) tickNow(ref, target);
      ref.read(pendingTargetProvider.notifier).state = target.at;
      return;
    }
    if (target != null) ref.read(pendingTargetProvider.notifier).state = target;
  }

  final taps = scheduler.opened.listen(take);
  ref.onDispose(taps.cancel);
  scheduler.takeLaunch().then(take);
});

/// Ticks off the block [target] is about (Round 72: its notification's
/// Done), unless it already is (or is gone). Round 78: a routine isn't
/// ticked off (an old notification's Done just opens the planner).
void tickNow(Ref ref, PlannerNowTarget target) {
  if (target.routine) return;
  final task =
      ref.read(plannerProvider).where((t) => t.id == target.id).firstOrNull;
  if (task != null && !task.done) {
    ref.read(plannerProvider.notifier).toggleDone(target.id);
  }
}
