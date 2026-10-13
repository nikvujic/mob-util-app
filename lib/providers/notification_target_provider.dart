import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    if (target != null) ref.read(pendingTargetProvider.notifier).state = target;
  }

  final taps = scheduler.opened.listen(take);
  ref.onDispose(taps.cancel);
  scheduler.takeLaunch().then(take);
});
