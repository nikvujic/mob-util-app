import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/section_data_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';

/// What a reset of a forgotten master password deletes (L7).
class PasswordResetPlan {
  /// Locked notes outside a locked Notes section.
  final int lockedNotes;

  /// Each locked section, with how many things in it will be deleted.
  final Map<AppSection, int> sections;

  const PasswordResetPlan({required this.lockedNotes, required this.sections});

  bool get deletesAnything =>
      lockedNotes > 0 || sections.values.any((count) => count > 0);
}

/// Resets a forgotten master password (L7): deletes everything it
/// protects — locked notes and the content of locked sections, so a section
/// lock can't be bypassed this way — then removes the password. Everything
/// else stays.
class PasswordReset {
  final Ref _ref;

  PasswordReset(this._ref);

  PasswordResetPlan plan() {
    final locks = _ref.read(sectionLocksProvider);
    final notes = _ref.read(notesProvider);
    return PasswordResetPlan(
      lockedNotes: locks.contains(AppSection.notes)
          ? 0
          : notes.where((n) => n.isLocked).length,
      sections: {
        for (final section in AppSection.values)
          if (locks.contains(section))
            section: _ref.read(sectionDataProvider).count(section),
      },
    );
  }

  /// Deletes, saves, and only then removes the password: a crash in
  /// between leaves the password set, never protected data without it.
  Future<void> run() async {
    final locks = _ref.read(sectionLocksProvider);
    final data = _ref.read(sectionDataProvider);
    for (final section in locks) {
      data.clear(section);
    }
    if (!locks.contains(AppSection.notes)) {
      _ref.read(notesProvider.notifier).removeNotes({
        for (final note in _ref.read(notesProvider))
          if (note.isLocked) note.id,
      });
    }
    await _ref.read(appStorageProvider).flush();
    // Section locks and the open session go with the password.
    _ref.read(securityProvider.notifier).forgetPassword();
  }
}

final passwordResetProvider = Provider<PasswordReset>(PasswordReset.new);
