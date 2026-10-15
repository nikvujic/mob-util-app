import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/date_entry.dart';

/// Birthdays & dates (Round 57), saved to `dates.json`. A date is saved
/// as it's edited (upserted); one left without a title is dropped by its
/// page.
class DatesNotifier extends StateNotifier<DateBook> {
  DatesNotifier(AppStorage storage) : super(storage.initialDates) {
    addListener(storage.saveDates, fireImmediately: false);
  }

  /// [date] as it is now: added if new, else replaced.
  void save(DateEntry date) {
    final known = state.byId(date.id) != null;
    state = DateBook([
      for (final d in state.dates)
        if (d.id == date.id) date else d,
      if (!known) date,
    ]);
  }

  /// Deletes [id]; returns the book before, for Undo.
  DateBook delete(String id) {
    final before = state;
    state = DateBook([
      for (final d in state.dates)
        if (d.id != id) d,
    ]);
    return before;
  }

  void replaceAll(DateBook book) => state = book;
}

final datesProvider = StateNotifierProvider<DatesNotifier, DateBook>(
  (ref) => DatesNotifier(ref.watch(appStorageProvider)),
);
