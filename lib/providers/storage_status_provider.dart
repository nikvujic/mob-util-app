import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';

/// The data files that couldn't be read at startup and were set aside, so
/// the app started without them (e.g. `notes.json`); empty normally.
final unreadableFilesProvider = Provider<List<String>>(
  (ref) => ref.watch(appStorageProvider).unreadable,
);

/// Whether saving fails right now (D6, Round 23), e.g. the phone's storage
/// is full: the home screen says so, and when it's saved again.
class SaveFailingNotifier extends StateNotifier<bool> {
  SaveFailingNotifier(AppStorage storage) : super(storage.saveFailing.value) {
    void update() => state = storage.saveFailing.value;
    storage.saveFailing.addListener(update);
    _stop = () => storage.saveFailing.removeListener(update);
  }

  late final void Function() _stop;

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

final saveFailingProvider = StateNotifierProvider<SaveFailingNotifier, bool>(
  (ref) => SaveFailingNotifier(ref.watch(appStorageProvider)),
);

/// Tries the failed saves again (when the app comes back).
final retrySavesProvider = Provider<Future<void> Function()>(
  (ref) => ref.watch(appStorageProvider).retryFailed,
);
