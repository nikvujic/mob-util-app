import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/hub_tool.dart';
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

/// The Hub's pages locked behind the master password (O7, Round 21).
/// State: the locked pages. Saved in `settings.json` with the section
/// locks. Independent of the Hub's own lock: a free Hub can have locked
/// pages, and a locked Hub's pages keep their own switches. Like section
/// locks they hide, not encrypt, and need a master password.
class PageLocksNotifier extends StateNotifier<Set<HubTool>> {
  final Ref _ref;

  PageLocksNotifier(this._ref, AppStorage storage)
      : super(storage.initialPageLocks) {
    addListener(storage.savePageLocks, fireImmediately: false);
    _ref.listen(securityProvider, (_, verifier) {
      if (verifier == null) state = const {};
    });
  }

  /// Locks [page]. Needs a master password.
  void lock(HubTool page) {
    if (_ref.read(securityProvider) == null) {
      throw StateError('Page locks need a master password');
    }
    if (!page.lockable) return;
    state = {...state, page};
  }

  /// Removes the lock of [page]. Throws [AppLockedException] while the app
  /// is locked.
  void unlock(HubTool page) {
    if (_ref.read(sessionProvider) == null) {
      throw const AppLockedException();
    }
    state = {...state}..remove(page);
  }
}

final pageLocksProvider =
    StateNotifierProvider<PageLocksNotifier, Set<HubTool>>(
  (ref) => PageLocksNotifier(ref, ref.watch(appStorageProvider)),
);

/// Whether the Hub's [page] is closed right now: locked, with the app
/// locked.
final pageClosedProvider = Provider.family<bool, HubTool>((ref, page) {
  return ref.watch(pageLocksProvider).contains(page) &&
      ref.watch(securityProvider) != null &&
      ref.watch(sessionProvider) == null;
});

/// Whether [page] is hidden right now, by its own lock or the Hub's.
final pageHiddenProvider = Provider.family<bool, HubTool>((ref, page) {
  return ref.watch(pageClosedProvider(page)) ||
      ref.watch(sectionClosedProvider(AppSection.hub));
});

/// Whether any of the Hub's pages is closed right now (its own lock).
final anyPageClosedProvider = Provider<bool>((ref) {
  return HubTool.values.any((t) => ref.watch(pageClosedProvider(t)));
});

/// Whether any section or Hub page is closed right now (e.g. backups need
/// unlocking).
final anySectionClosedProvider = Provider<bool>((ref) {
  return AppSection.values.any((s) => ref.watch(sectionClosedProvider(s))) ||
      HubTool.values.any((t) => ref.watch(pageClosedProvider(t)));
});
