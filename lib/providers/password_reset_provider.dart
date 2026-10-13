import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/hub_tool.dart';
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

  /// Each locked Hub page outside a locked Hub (O7), with how many things
  /// in it will be deleted.
  final Map<HubTool, int> pages;

  const PasswordResetPlan({
    required this.lockedNotes,
    required this.sections,
    this.pages = const {},
  });

  bool get deletesAnything =>
      lockedNotes > 0 ||
      sections.values.any((count) => count > 0) ||
      pages.values.any((count) => count > 0);
}

/// Resets a forgotten master password (L7): deletes everything it
/// protects — locked notes and the content of locked sections and Hub
/// pages, so a lock can't be bypassed this way — then removes the password. Everything
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
      pages: {
        if (!locks.contains(AppSection.hub))
          for (final page in _ref.read(pageLocksProvider))
            page: _ref.read(sectionDataProvider).countOf(page),
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
    _ref.read(pageLocksProvider).forEach(data.clearOf);
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
