import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/subscription.dart';

/// Subscriptions (Round 79), saved to `subscriptions.json`. One is saved
/// as it's edited (upserted).
class SubscriptionsNotifier extends StateNotifier<SubscriptionBook> {
  SubscriptionsNotifier(AppStorage storage)
      : super(storage.initialSubscriptions) {
    addListener(storage.saveSubscriptions, fireImmediately: false);
  }

  /// [subscription] as it is now: added if new, else replaced.
  void save(Subscription subscription) {
    final known = state.byId(subscription.id) != null;
    state = SubscriptionBook([
      for (final s in state.subscriptions)
        if (s.id == subscription.id) subscription else s,
      if (!known) subscription,
    ]);
  }

  /// Deletes [id]; returns the book before, for Undo.
  SubscriptionBook delete(String id) {
    final before = state;
    state = SubscriptionBook([
      for (final s in state.subscriptions)
        if (s.id != id) s,
    ]);
    return before;
  }

  void replaceAll(SubscriptionBook book) => state = book;
}

final subscriptionsProvider =
    StateNotifierProvider<SubscriptionsNotifier, SubscriptionBook>(
  (ref) => SubscriptionsNotifier(ref.watch(appStorageProvider)),
);

/// The red dot on Subscriptions' tile (Round 79): one to cancel whose day
/// is within its reminder before.
final subscriptionsDotProvider = Provider<bool>((ref) {
  final now = ref.watch(clockProvider)();
  return ref
      .watch(subscriptionsProvider)
      .subscriptions
      .any((s) => s.cancelDueOn(now));
});
