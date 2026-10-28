import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/placard.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/placard_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/providers/subscriptions_provider.dart';
import 'package:the_app/providers/packing_provider.dart';
import 'package:the_app/providers/people_provider.dart';
import 'package:the_app/providers/todo_provider.dart';

/// Everything a section holds, to count or clear it as a whole: the
/// planner's tasks, routines and reminders, the Hub's counters.
class SectionData {
  final Ref _ref;

  SectionData(this._ref);

  /// How many things [section] holds.
  int count(AppSection section) => switch (section) {
        // With the to-do note's list (Round 28).
        AppSection.notes =>
          _ref.read(notesProvider).length + _ref.read(todoProvider).length,
        AppSection.shop => _ref.read(shopProvider).length,
        AppSection.planner => _ref.read(plannerProvider).length +
            _ref.read(routinesProvider).routines.length +
            _ref.read(pinsProvider).length,
        AppSection.hub => [
            for (final tool in HubTool.values) countOf(tool),
          ].fold(0, (a, b) => a + b),
      };

  /// How many things one of the Hub's pages holds (O9). Exhaustive: a new
  /// page doesn't compile until it's here.
  int countOf(HubTool tool) => switch (tool) {
        HubTool.counters => _ref.read(countersProvider).length,
        // Its text and count, once set.
        HubTool.placard => _ref.read(placardProvider).isSet ? 1 : 0,
        HubTool.medicine => _ref.read(medicineProvider).size,
        // With the ingredients list.
        HubTool.recipes => _ref.read(recipesProvider).length +
            _ref.read(ingredientsProvider).size,
        // Its foods and meals.
        HubTool.food => _ref.read(foodProvider).size,
        HubTool.dates => _ref.read(datesProvider).dates.length,
        HubTool.subscriptions =>
          _ref.read(subscriptionsProvider).subscriptions.length,
        // His life isn't cleared with the Hub's pages; Spotify's morning
        // is a setting (Round 93).
        HubTool.pip || HubTool.spotify || HubTool.converter => 0,
        // Its lists (Round 94).
        HubTool.packing => _ref.read(packingProvider).lists.length,
        // Round 108: everyone on the board.
        HubTool.people => _ref.read(peopleProvider).people.length,
      };

  /// Empties one of the Hub's pages (saved with the next flush).
  void clearOf(HubTool tool) {
    switch (tool) {
      case HubTool.counters:
        _ref.read(countersProvider.notifier).replaceAll(const []);
      case HubTool.placard:
        _ref.read(placardProvider.notifier).replace(Placard.initial);
      case HubTool.medicine:
        _ref.read(medicineProvider.notifier).replaceAll(MedicineBook.empty);
      case HubTool.recipes:
        _ref.read(recipesProvider.notifier).replaceAll(const []);
        _ref
            .read(ingredientsProvider.notifier)
            .replaceAll(IngredientBook.empty);
      case HubTool.food:
        _ref.read(foodProvider.notifier).replaceAll(FoodBook.empty);
      case HubTool.dates:
        _ref.read(datesProvider.notifier).replaceAll(DateBook.empty);
      case HubTool.subscriptions:
        _ref
            .read(subscriptionsProvider.notifier)
            .replaceAll(SubscriptionBook.empty);
      case HubTool.packing:
        // Its sections back to the usual ones too.
        _ref.read(packingProvider.notifier).replaceAll(PackingBook.initial);
      case HubTool.people:
        // Their birthdays on the Dates page go too (they're People's).
        final dates = _ref.read(datesProvider.notifier);
        for (final d in _ref.read(datesProvider).dates) {
          if (d.personId != null) dates.delete(d.id);
        }
        _ref.read(peopleProvider.notifier).replaceAll(PeopleBook.empty);
      case HubTool.pip:
      case HubTool.spotify:
      case HubTool.converter:
    }
  }

  /// Empties [section] (saved with the next flush).
  void clear(AppSection section) {
    switch (section) {
      case AppSection.notes:
        _ref.read(notesProvider.notifier).replaceAll(const []);
        _ref.read(todoProvider.notifier).replaceAll(const []);
      case AppSection.shop:
        _ref.read(shopProvider.notifier).replaceAll(const []);
      case AppSection.planner:
        _ref.read(plannerProvider.notifier).replaceAll(const []);
        _ref.read(routinesProvider.notifier).replaceAll(RoutineBook.empty);
        _ref.read(pinsProvider.notifier).replaceAll(const []);
      case AppSection.hub:
        HubTool.values.forEach(clearOf);
    }
  }

  /// Empties [sections] and [tools] (the Hub's pages) and saves (D7).
  /// Throws [StorageWriteException] if that couldn't be saved.
  Future<void> clearAll(
    Iterable<AppSection> sections, {
    Iterable<HubTool> tools = const [],
  }) async {
    for (final section in sections) {
      clear(section);
    }
    tools.forEach(clearOf);
    await _ref.read(appStorageProvider).flush();
  }
}

final sectionDataProvider = Provider<SectionData>(SectionData.new);
