import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/other_tool.dart';
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
        AppSection.other => [
            for (final tool in OtherTool.values) countOf(tool),
          ].fold(0, (a, b) => a + b),
      };

  /// How many things one of Other's pages holds (O9). Exhaustive: a new
  /// page doesn't compile until it's here.
  int countOf(OtherTool tool) => switch (tool) {
        OtherTool.counters => _ref.read(countersProvider).length,
      };

  /// Empties one of Other's pages (saved with the next flush).
  void clearOf(OtherTool tool) {
    switch (tool) {
      case OtherTool.counters:
        _ref.read(countersProvider.notifier).replaceAll(const []);
    }
  }

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
        OtherTool.values.forEach(clearOf);
    }
  }

  /// Empties [sections] and [tools] (Other's pages) and saves (D7).
  /// Throws [StorageWriteException] if that couldn't be saved.
  Future<void> clearAll(
    Iterable<AppSection> sections, {
    Iterable<OtherTool> tools = const [],
  }) async {
    for (final section in sections) {
      clear(section);
    }
    tools.forEach(clearOf);
    await _ref.read(appStorageProvider).flush();
  }
}

final sectionDataProvider = Provider<SectionData>(SectionData.new);
