import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';

/// Thrown when a section lock is turned off while the app is locked.
class AppLockedException implements Exception {
  const AppLockedException();
}

/// Sections locked behind the master password (L5). State: the locked
/// sections. Saved in `settings.json`.
///
/// A section lock hides the section until the app is unlocked (L4); it
/// doesn't encrypt the section's data (locked notes do that for notes).
/// Locks need a master password: removing it clears them.
class SectionLocksNotifier extends StateNotifier<Set<AppSection>> {
  final Ref _ref;

  SectionLocksNotifier(this._ref, AppStorage storage)
      : super(storage.initialSectionLocks) {
    addListener(storage.saveSectionLocks, fireImmediately: false);
    _ref.listen(securityProvider, (_, verifier) {
      if (verifier == null) state = const {};
    });
  }

  /// Locks [section]. Needs a master password.
  void lock(AppSection section) {
    if (_ref.read(securityProvider) == null) {
      throw StateError('Section locks need a master password');
    }
    state = {...state, section};
  }

  /// Removes the lock of [section]. Throws [AppLockedException] while the
  /// app is locked, so a lock can't be turned off without the password.
  void unlock(AppSection section) {
    if (_ref.read(sessionProvider) == null) {
      throw const AppLockedException();
    }
    state = {...state}..remove(section);
  }
}

final sectionLocksProvider =
    StateNotifierProvider<SectionLocksNotifier, Set<AppSection>>(
  (ref) => SectionLocksNotifier(ref, ref.watch(appStorageProvider)),
);

/// Whether [section] is closed right now: locked, with the app locked.
final sectionClosedProvider = Provider.family<bool, AppSection>((ref, section) {
  return ref.watch(sectionLocksProvider).contains(section) &&
      ref.watch(securityProvider) != null &&
      ref.watch(sessionProvider) == null;
});

/// Whether any section is closed right now (e.g. backups need unlocking).
final anySectionClosedProvider = Provider<bool>((ref) {
  return AppSection.values.any((s) => ref.watch(sectionClosedProvider(s)));
});
