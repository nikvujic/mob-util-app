import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

/// Everything a section holds, to count or clear it as a whole: the
/// planner's tasks, routines and reminders, Other's counters.
class SectionData {
  final Ref _ref;

  SectionData(this._ref);

  /// How many things [section] holds.
  int count(AppSection section) => switch (section) {
        AppSection.notes => _ref.read(notesProvider).length,
        AppSection.shop => _ref.read(shopProvider).length,
        AppSection.planner => _ref.read(plannerProvider).length +
            _ref.read(routinesProvider).routines.length +
            _ref.read(pinsProvider).length,
        AppSection.other => _ref.read(countersProvider).length,
      };

  /// Empties [section] (saved with the next flush).
  void clear(AppSection section) {
    switch (section) {
      case AppSection.notes:
        _ref.read(notesProvider.notifier).replaceAll(const []);
      case AppSection.shop:
        _ref.read(shopProvider.notifier).replaceAll(const []);
      case AppSection.planner:
        _ref.read(plannerProvider.notifier).replaceAll(const []);
        _ref.read(routinesProvider.notifier).replaceAll(RoutineBook.empty);
        _ref.read(pinsProvider.notifier).replaceAll(const []);
      case AppSection.other:
        _ref.read(countersProvider.notifier).replaceAll(const []);
    }
  }

  /// Empties [sections] and saves (D7). Throws [StorageWriteException] if
  /// that couldn't be saved.
  Future<void> clearAll(Iterable<AppSection> sections) async {
    for (final section in sections) {
      clear(section);
    }
    await _ref.read(appStorageProvider).flush();
  }
}

final sectionDataProvider = Provider<SectionData>(SectionData.new);
