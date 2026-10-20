import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/json_file_store.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/counter.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/models/notification_log.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/placard.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/models/todo_item.dart';

/// Loads and saves all app data. Each feature has its own JSON file:
///
///     <app documents>/data/notes.json  {"version": 2, "notes": [...]}
///     <app documents>/data/shop.json   {"version": 3, "items": [...]}
///     <app documents>/data/security.json
///         {"version": 2, "masterPassword": {verifier} or null}
///     <app documents>/data/planner.json {"version": 5, "tasks": [...]}
///     <app documents>/data/routines.json
///         {"version": 2, "routines": [...], "days": [...]}
///     <app documents>/data/pins.json {"version": 1, "pins": [...]}
///     <app documents>/data/layout.json {"version": 2, "hub": [ids]}
///     <app documents>/data/placard.json {"version": 1, "text": …, "count": …}
///     <app documents>/data/medicine.json
///         {"version": 2, "medicines": [...], "taken": [...]}
///     <app documents>/data/todo.json {"version": 3, "items": [...]}
///     <app documents>/data/pip.json
///         {"version": 2, "born": …, "name": …, "energy": …, ...}
///     <app documents>/data/recipes.json {"version": 1, "recipes": [...]}
///     <app documents>/data/ingredients.json
///         {"version": 1, "sections": [...]}
///     <app documents>/data/food.json
///         {"version": 1, "foods": [...], "meals": [...]}
///     <app documents>/data/dates.json {"version": 3, "dates": [...]}
///     <app documents>/data/subscriptions.json
///         {"version": 1, "subscriptions": [...]}
///     <app documents>/data/packing.json
///         {"version": 1, "sections": [...], "lists": [...]}
///     <app documents>/data/notifications.json
///         {"version": 1, "scheduled": [...], "clearedAt": …}
///     <app documents>/data/counters.json {"version": 3, "counters": [...]}
///     <app documents>/data/preferences.json
///         {"version": 2, "theme": "green", "counterFeedback": true}
///     <app documents>/data/settings.json
///         {"version": 2, "sectionLocks": ["shop", ...],
///          "pageLocks": ["medicine", ...], "todoLocked": true}
///
/// Data is loaded once at startup ([open]) and then saved after every change
/// by the providers.
class AppStorage {
  /// Version of the files written. History: 1 = first format; 2 = notes
  /// may be locked (`lockedContent`) and the master password record may
  /// hold a wrapped data key. Every older version must stay readable.
  static const formatVersion = 2;

  /// Version of `planner.json`, which moves on its own. History: 2 = tasks
  /// per day; 3 = tasks have start and end times (P7; version 2 tasks have
  /// none and are still read); 4 = tasks may have a colour (P9); 5 = and
  /// a description (P20).
  static const plannerFormatVersion = 5;

  /// Version of `routines.json` (P8). History: 1 = first format; 2 =
  /// routines may have a description (P20).
  static const routinesFormatVersion = 2;

  /// Version of `pins.json` (P14). History: 1 = first format.
  static const pinsFormatVersion = 1;

  /// Version of `layout.json` (O9): where the pages go. History: 1 =
  /// first format (the Hub's order, under `other`); 2 = under `hub` (O11).
  static const layoutFormatVersion = 2;

  /// Version of `placard.json` (O4). History: 1 = first format.
  static const placardFormatVersion = 1;

  /// Version of `counters.json`, on its own from here. History: 1–2 = as
  /// [formatVersion]; 3 = counters may have a step, colour and limits (O5).
  static const countersFormatVersion = 3;

  /// Version of `medicine.json` (O6). History: 1 = first format; 2 =
  /// doses can be missed or not sure, and taken ones may have no time
  /// (O13); 3 = a medicine may remind again after its doses (`followUp`,
  /// Round 16); 4 = a medicine may be important (`important`, Round 24);
  /// 5 = a medicine may be taken on some weekdays only (`weekdays`, Round
  /// 40).
  static const medicineFormatVersion = 5;

  /// Version of `shop.json`, which moves on its own from here. History:
  /// 1–2 = as [formatVersion]; 3 = items may have a quantity (S7); 4 =
  /// or a typed one (`text`, Round 70).
  static const shopFormatVersion = 4;

  /// Version of `todo.json` (Round 28). History: 1 = first format; 2 =
  /// things may be done (`done`, Round 30); 3 = or waiting (`waiting`,
  /// Round 45).
  static const todoFormatVersion = 3;

  /// Version of `notifications.json` (Round 31): what was scheduled, for
  /// the history. This phone only, not in backups. History: 1 = first
  /// format.
  static const notificationsFormatVersion = 1;

  /// Version of `pip.json` (Round 34): Pip, the pet. History: 1 = first
  /// format; 2 = his energy, batteries and what was shown (Round 37);
  /// 3 = his adventures (`adventure`, Round 63). Round 77 added an
  /// optional `wokenAt` within 3 (without it he simply wasn't woken).
  static const pipFormatVersion = 3;

  /// Version of `recipes.json` (Round 42). History: 1 = first format.
  static const recipesFormatVersion = 1;

  /// Version of `ingredients.json` (Round 42), the list recipes pick
  /// from. History: 1 = first format.
  static const ingredientsFormatVersion = 1;

  /// Version of `food.json` (Round 46), the food tracker. History: 1 =
  /// first format.
  static const foodFormatVersion = 1;

  /// Version of `dates.json` (Round 57), birthdays & dates. History: 1 =
  /// first format; 2 = a holiday or an event may last several days
  /// (`days`, Round 59); 3 = a holiday or an event may be of a kind
  /// (`kind`: skiing, beach, trip, wedding; Round 61); 4 = a ski trip's
  /// travel (`travel`: hours, leave, back; Round 67).
  static const datesFormatVersion = 4;

  /// Version of `subscriptions.json` (Round 79). History: 1 = first
  /// format.
  static const subscriptionsFormatVersion = 1;

  /// Version of `packing.json` (Round 94). History: 1 = first format.
  static const packingFormatVersion = 1;

  final JsonFileStore? _notesStore;
  final JsonFileStore? _shopStore;
  final JsonFileStore? _securityStore;
  final JsonFileStore? _settingsStore;
  final JsonFileStore? _plannerStore;
  final JsonFileStore? _countersStore;
  final JsonFileStore? _preferencesStore;
  final JsonFileStore? _routinesStore;
  final JsonFileStore? _pinsStore;
  final JsonFileStore? _layoutStore;
  final JsonFileStore? _placardStore;
  final JsonFileStore? _medicineStore;
  final JsonFileStore? _todoStore;
  final JsonFileStore? _notificationsStore;
  final JsonFileStore? _pipStore;
  final JsonFileStore? _recipesStore;
  final JsonFileStore? _ingredientsStore;
  final JsonFileStore? _foodStore;
  final JsonFileStore? _datesStore;
  final JsonFileStore? _subscriptionsStore;
  final JsonFileStore? _packingStore;

  /// Data as loaded at startup.
  final List<Note> initialNotes;
  final List<ShopItem> initialShopItems;
  final List<PlannerTask> initialPlannerTasks;
  final RoutineBook initialRoutines;
  final List<PlannerPin> initialPins;
  final List<Counter> initialCounters;
  final Preferences initialPreferences;
  final PageLayout initialLayout;
  final Placard initialPlacard;
  final MedicineBook initialMedicine;
  final List<TodoItem> initialTodo;
  final NotificationLog initialNotificationLog;
  final PipLife initialPip;
  final List<Recipe> initialRecipes;
  final IngredientBook initialIngredients;
  final FoodBook initialFood;
  final DateBook initialDates;
  final SubscriptionBook initialSubscriptions;
  final PackingBook initialPacking;

  /// The master password's verifier, or null if none is set.
  final PasswordVerifier? initialMasterPassword;

  /// Sections locked behind the master password (L5).
  final Set<AppSection> initialSectionLocks;

  /// The Hub's pages locked behind the master password (O7).
  final Set<HubTool> initialPageLocks;

  /// The to-do note locked behind the master password (Round 45).
  final bool initialTodoLocked;

  /// The locks last saved: settings.json holds every kind.
  late Set<AppSection> _sectionLocks = initialSectionLocks;
  late Set<HubTool> _pageLocks = initialPageLocks;
  late bool _todoLocked = initialTodoLocked;

  AppStorage._(
    this._notesStore,
    this._shopStore,
    this._securityStore,
    this._settingsStore,
    this._plannerStore,
    this._countersStore,
    this._preferencesStore,
    this._routinesStore,
    this._pinsStore,
    this._layoutStore,
    this._placardStore,
    this._medicineStore,
    this._todoStore,
    this._notificationsStore,
    this._pipStore,
    this._recipesStore,
    this._ingredientsStore,
    this._foodStore,
    this._datesStore,
    this._subscriptionsStore,
    this._packingStore, {
    required this.initialNotes,
    required this.initialShopItems,
    required this.initialPlannerTasks,
    required this.initialRoutines,
    required this.initialPins,
    required this.initialCounters,
    required this.initialPreferences,
    required this.initialLayout,
    required this.initialPlacard,
    required this.initialMedicine,
    required this.initialTodo,
    required this.initialNotificationLog,
    required this.initialPip,
    required this.initialRecipes,
    required this.initialIngredients,
    required this.initialFood,
    required this.initialDates,
    required this.initialSubscriptions,
    required this.initialPacking,
    required this.initialMasterPassword,
    required this.initialSectionLocks,
    required this.initialPageLocks,
    required this.initialTodoLocked,
  });

  /// Storage that keeps nothing (for tests and previews).
  AppStorage.inMemory({
    this.initialNotes = const [],
    this.initialShopItems = const [],
    this.initialPlannerTasks = const [],
    this.initialRoutines = RoutineBook.empty,
    this.initialPins = const [],
    this.initialCounters = const [],
    this.initialPreferences = const Preferences(),
    PageLayout? initialLayout,
    this.initialPlacard = Placard.initial,
    this.initialMedicine = MedicineBook.empty,
    this.initialTodo = const [],
    NotificationLog? initialNotificationLog,
    this.initialPip = PipLife.egg,
    this.initialRecipes = const [],
    this.initialIngredients = IngredientBook.empty,
    this.initialFood = FoodBook.empty,
    this.initialDates = DateBook.empty,
    this.initialSubscriptions = SubscriptionBook.empty,
    PackingBook? initialPacking,
    this.initialMasterPassword,
    this.initialSectionLocks = const {},
    this.initialPageLocks = const {},
    this.initialTodoLocked = false,
  })  : _notesStore = null,
        _shopStore = null,
        _securityStore = null,
        _settingsStore = null,
        _plannerStore = null,
        _countersStore = null,
        _preferencesStore = null,
        _routinesStore = null,
        _pinsStore = null,
        _layoutStore = null,
        _placardStore = null,
        _medicineStore = null,
        _todoStore = null,
        _notificationsStore = null,
        _pipStore = null,
        _recipesStore = null,
        _ingredientsStore = null,
        _foodStore = null,
        _datesStore = null,
        _subscriptionsStore = null,
        _packingStore = null,
        initialPacking = initialPacking ?? PackingBook.initial,
        initialNotificationLog =
            initialNotificationLog ?? NotificationLog.empty,
        initialLayout = initialLayout ?? PageLayout.initial;

  /// Opens storage in [directory], or in the app's documents folder.
  static Future<AppStorage> open({Directory? directory}) async {
    final dir = directory ??
        Directory('${(await getApplicationDocumentsDirectory()).path}/data');
    final notesStore = JsonFileStore(File('${dir.path}/notes.json'));
    final shopStore = JsonFileStore(File('${dir.path}/shop.json'));
    final securityStore = JsonFileStore(File('${dir.path}/security.json'));
    final settingsStore = JsonFileStore(File('${dir.path}/settings.json'));
    final plannerStore = JsonFileStore(File('${dir.path}/planner.json'));
    final countersStore = JsonFileStore(File('${dir.path}/counters.json'));
    final preferencesStore =
        JsonFileStore(File('${dir.path}/preferences.json'));
    final routinesStore = JsonFileStore(File('${dir.path}/routines.json'));
    final pinsStore = JsonFileStore(File('${dir.path}/pins.json'));
    final layoutStore = JsonFileStore(File('${dir.path}/layout.json'));
    final placardStore = JsonFileStore(File('${dir.path}/placard.json'));
    final medicineStore = JsonFileStore(File('${dir.path}/medicine.json'));
    final todoStore = JsonFileStore(File('${dir.path}/todo.json'));
    final notificationsStore =
        JsonFileStore(File('${dir.path}/notifications.json'));
    final pipStore = JsonFileStore(File('${dir.path}/pip.json'));
    final recipesStore = JsonFileStore(File('${dir.path}/recipes.json'));
    final ingredientsStore =
        JsonFileStore(File('${dir.path}/ingredients.json'));
    final foodStore = JsonFileStore(File('${dir.path}/food.json'));
    final datesStore = JsonFileStore(File('${dir.path}/dates.json'));
    final subscriptionsStore =
        JsonFileStore(File('${dir.path}/subscriptions.json'));
    final packingStore = JsonFileStore(File('${dir.path}/packing.json'));
    // Unknown sections and pages (from a newer app) are skipped, not fatal.
    final locks = await _load(
        settingsStore, (<AppSection>{}, <HubTool>{}, false), (json) {
      List<dynamic> ids(String key) => json[key] as List<dynamic>? ?? const [];
      return (
        {
          for (final id in ids('sectionLocks')) AppSection.fromId(id as String),
        }.whereType<AppSection>().toSet(),
        {
          for (final id in ids('pageLocks')) HubTool.fromId(id as String),
        }.whereType<HubTool>().toSet(),
        json['todoLocked'] as bool? ?? false,
      );
    });

    final storage = AppStorage._(
      notesStore,
      shopStore,
      securityStore,
      settingsStore,
      plannerStore,
      countersStore,
      preferencesStore,
      routinesStore,
      pinsStore,
      layoutStore,
      placardStore,
      medicineStore,
      todoStore,
      notificationsStore,
      pipStore,
      recipesStore,
      ingredientsStore,
      foodStore,
      datesStore,
      subscriptionsStore,
      packingStore,
      initialNotes: await _load(
        notesStore,
        [],
        (json) => [
          for (final e in json['notes'] as List<dynamic>)
            Note.fromJson(e as Map<String, dynamic>),
        ],
      ),
      initialShopItems: await _load(
        shopStore,
        [],
        maxVersion: shopFormatVersion,
        (json) => [
          for (final e in json['items'] as List<dynamic>)
            ShopItem.fromJson(e as Map<String, dynamic>),
        ],
      ),
      initialMasterPassword: await _load(securityStore, null, (json) {
        final verifier = json['masterPassword'];
        return verifier == null
            ? null
            : PasswordVerifier.fromJson(verifier as Map<String, dynamic>);
      }),
      initialPlannerTasks: await _load(
        plannerStore,
        [],
        maxVersion: plannerFormatVersion,
        (json) => [
          for (final e in json['tasks'] as List<dynamic>)
            PlannerTask.fromJson(e as Map<String, dynamic>),
        ],
      ),
      initialRoutines: await _load(
        routinesStore,
        RoutineBook.empty,
        maxVersion: routinesFormatVersion,
        RoutineBook.fromJson,
      ),
      initialPins: await _load(
        pinsStore,
        [],
        maxVersion: pinsFormatVersion,
        (json) => [
          for (final e in json['pins'] as List<dynamic>)
            PlannerPin.fromJson(e as Map<String, dynamic>),
        ],
      ),
      initialCounters: await _load(
        countersStore,
        [],
        maxVersion: countersFormatVersion,
        (json) => [
          for (final e in json['counters'] as List<dynamic>)
            Counter.fromJson(e as Map<String, dynamic>),
        ],
      ),
      initialPreferences: await _load(
        preferencesStore,
        const Preferences(),
        Preferences.fromJson,
      ),
      initialLayout: await _load(
        layoutStore,
        PageLayout.initial,
        maxVersion: layoutFormatVersion,
        PageLayout.fromJson,
      ),
      initialPlacard: await _load(
        placardStore,
        Placard.initial,
        maxVersion: placardFormatVersion,
        Placard.fromJson,
      ),
      initialMedicine: await _load(
        medicineStore,
        MedicineBook.empty,
        maxVersion: medicineFormatVersion,
        MedicineBook.fromJson,
      ),
      initialTodo: await _load(
        todoStore,
        [],
        maxVersion: todoFormatVersion,
        (json) => [
          for (final e in json['items'] as List<dynamic>)
            TodoItem.fromJson(e as Map<String, dynamic>),
        ],
      ),
      initialNotificationLog: await _load(
        notificationsStore,
        NotificationLog.empty,
        maxVersion: notificationsFormatVersion,
        NotificationLog.fromJson,
      ),
      initialPip: await _load(
        pipStore,
        PipLife.egg,
        maxVersion: pipFormatVersion,
        PipLife.fromJson,
      ),
      initialRecipes: await _load(
        recipesStore,
        [],
        maxVersion: recipesFormatVersion,
        (json) => [
          for (final e in json['recipes'] as List<dynamic>)
            Recipe.fromJson(e as Map<String, dynamic>),
        ],
      ),
      initialIngredients: await _load(
        ingredientsStore,
        IngredientBook.empty,
        maxVersion: ingredientsFormatVersion,
        IngredientBook.fromJson,
      ),
      initialFood: await _load(
        foodStore,
        FoodBook.empty,
        maxVersion: foodFormatVersion,
        FoodBook.fromJson,
      ),
      initialDates: await _load(
        datesStore,
        DateBook.empty,
        maxVersion: datesFormatVersion,
        DateBook.fromJson,
      ),
      initialSubscriptions: await _load(
        subscriptionsStore,
        SubscriptionBook.empty,
        maxVersion: subscriptionsFormatVersion,
        SubscriptionBook.fromJson,
      ),
      initialPacking: await _load(
        packingStore,
        PackingBook.initial,
        maxVersion: packingFormatVersion,
        PackingBook.fromJson,
      ),
      initialSectionLocks: locks.$1,
      initialPageLocks: locks.$2,
      initialTodoLocked: locks.$3,
    );
    storage._watchSaving();
    return storage;
  }

  /// Reads [store] with [parse]; [empty] if the file doesn't exist yet.
  ///
  /// Every format version this app ever wrote must stay readable here
  /// (enforced by test/data/storage_compatibility_test.dart). A file from a
  /// *newer* version — only possible after installing an older app — is not
  /// misread: like any unreadable file it's moved aside, intact.
  static Future<T> _load<T>(
    JsonFileStore store,
    T empty,
    T Function(Map<String, dynamic> json) parse, {
    int maxVersion = formatVersion,
  }) async {
    try {
      final json = await store.read();
      if (json == null) return empty;
      final map = json as Map<String, dynamic>;
      final version = map['version'];
      if (version is! int || version < 1 || version > maxVersion) {
        throw FormatException('Unsupported format version: $version');
      }
      return parse(map);
    } catch (e) {
      // Never overwrite data we could not read: move it aside and start
      // empty, so it can still be recovered by hand.
      final moved = await store.quarantine();
      debugPrint('Could not read ${store.file.path} ($e); moved to $moved');
      return empty;
    }
  }

  Future<void> saveNotes(List<Note> notes) async {
    await _notesStore?.write({
      'version': formatVersion,
      'notes': [for (final n in notes) n.toJson()],
    });
  }

  Future<void> saveShopItems(List<ShopItem> items) async {
    await _shopStore?.write({
      'version': shopFormatVersion,
      'items': [for (final i in items) i.toJson()],
    });
  }

  Future<void> saveMasterPassword(PasswordVerifier? verifier) async {
    await _securityStore?.write({
      'version': formatVersion,
      'masterPassword': verifier?.toJson(),
    });
  }

  Future<void> savePlannerTasks(List<PlannerTask> tasks) async {
    await _plannerStore?.write({
      'version': plannerFormatVersion,
      'tasks': [for (final t in tasks) t.toJson()],
    });
  }

  Future<void> saveRoutines(RoutineBook book) async {
    await _routinesStore?.write({
      'version': routinesFormatVersion,
      ...book.toJson(),
    });
  }

  Future<void> savePins(List<PlannerPin> pins) async {
    await _pinsStore?.write({
      'version': pinsFormatVersion,
      'pins': [for (final p in pins) p.toJson()],
    });
  }

  Future<void> saveLayout(PageLayout layout) async {
    await _layoutStore?.write({
      'version': layoutFormatVersion,
      ...layout.toJson(),
    });
  }

  Future<void> savePlacard(Placard placard) async {
    await _placardStore?.write({
      'version': placardFormatVersion,
      ...placard.toJson(),
    });
  }

  Future<void> saveMedicine(MedicineBook book) async {
    await _medicineStore?.write({
      'version': medicineFormatVersion,
      ...book.toJson(),
    });
  }

  Future<void> saveTodo(List<TodoItem> items) async {
    await _todoStore?.write({
      'version': todoFormatVersion,
      'items': [for (final i in items) i.toJson()],
    });
  }

  Future<void> saveNotificationLog(NotificationLog log) async {
    await _notificationsStore?.write({
      'version': notificationsFormatVersion,
      ...log.toJson(),
    });
  }

  Future<void> savePip(PipLife pip) async {
    await _pipStore?.write({
      'version': pipFormatVersion,
      ...pip.toJson(),
    });
  }

  Future<void> saveRecipes(List<Recipe> recipes) async {
    await _recipesStore?.write({
      'version': recipesFormatVersion,
      'recipes': [for (final r in recipes) r.toJson()],
    });
  }

  Future<void> saveIngredients(IngredientBook book) async {
    await _ingredientsStore?.write({
      'version': ingredientsFormatVersion,
      ...book.toJson(),
    });
  }

  Future<void> saveFood(FoodBook book) async {
    await _foodStore?.write({
      'version': foodFormatVersion,
      ...book.toJson(),
    });
  }

  Future<void> saveDates(DateBook book) async {
    await _datesStore?.write({
      'version': datesFormatVersion,
      ...book.toJson(),
    });
  }

  Future<void> saveSubscriptions(SubscriptionBook book) async {
    await _subscriptionsStore?.write({
      'version': subscriptionsFormatVersion,
      ...book.toJson(),
    });
  }

  Future<void> savePacking(PackingBook book) async {
    await _packingStore?.write({
      'version': packingFormatVersion,
      ...book.toJson(),
    });
  }

  Future<void> saveCounters(List<Counter> counters) async {
    await _countersStore?.write({
      'version': countersFormatVersion,
      'counters': [for (final c in counters) c.toJson()],
    });
  }

  Future<void> savePreferences(Preferences preferences) async {
    await _preferencesStore?.write({
      'version': formatVersion,
      ...preferences.toJson(),
    });
  }

  Future<void> saveSectionLocks(Set<AppSection> sections) {
    _sectionLocks = sections;
    return _saveLocks();
  }

  Future<void> savePageLocks(Set<HubTool> pages) {
    _pageLocks = pages;
    return _saveLocks();
  }

  Future<void> saveTodoLocked(bool locked) {
    _todoLocked = locked;
    return _saveLocks();
  }

  Future<void> _saveLocks() async {
    await _settingsStore?.write({
      'version': formatVersion,
      'sectionLocks': [
        for (final s in AppSection.values)
          if (_sectionLocks.contains(s)) s.name,
      ],
      'pageLocks': [
        for (final t in HubTool.values)
          if (_pageLocks.contains(t)) t.name,
      ],
      if (_todoLocked) 'todoLocked': true,
    });
  }

  /// The files that couldn't be read at startup and were set aside (the
  /// app started without their data), e.g. `notes.json`.
  List<String> get unreadable => [
        for (final store in [
          _notesStore,
          _shopStore,
          _securityStore,
          _settingsStore,
          _plannerStore,
          _countersStore,
          _preferencesStore,
          _routinesStore,
          _pinsStore,
          _layoutStore,
          _placardStore,
          _medicineStore,
          _todoStore,
          _notificationsStore,
          _pipStore,
          _recipesStore,
          _ingredientsStore,
          _foodStore,
          _datesStore,
          _subscriptionsStore,
          _packingStore,
        ])
          if (store != null && store.unreadable)
            store.file.uri.pathSegments.last,
      ];

  /// Whether saving fails right now for any file (e.g. the phone's
  /// storage is full): the app says so, and says when it's saved again.
  final saveFailing = ValueNotifier<bool>(false);

  List<JsonFileStore> get _stores => [
        for (final store in [
          _notesStore,
          _shopStore,
          _securityStore,
          _settingsStore,
          _plannerStore,
          _countersStore,
          _preferencesStore,
          _routinesStore,
          _pinsStore,
          _layoutStore,
          _placardStore,
          _medicineStore,
          _todoStore,
          _notificationsStore,
          _pipStore,
          _recipesStore,
          _ingredientsStore,
          _foodStore,
          _datesStore,
          _subscriptionsStore,
          _packingStore,
        ])
          if (store != null) store,
      ];

  void _watchSaving() {
    void update() =>
        saveFailing.value = _stores.any((store) => store.failing.value);
    for (final store in _stores) {
      store.failing.addListener(update);
    }
  }

  /// Tries the failed saves again (when the app comes back: space may have
  /// been freed meanwhile).
  Future<void> retryFailed() async {
    for (final store in _stores) {
      await store.retry();
    }
  }

  /// Completes when every pending save is on disk. Throws
  /// [StorageWriteException] if one couldn't be saved.
  Future<void> flush() async {
    await _notesStore?.flush();
    await _shopStore?.flush();
    await _securityStore?.flush();
    await _settingsStore?.flush();
    await _plannerStore?.flush();
    await _countersStore?.flush();
    await _preferencesStore?.flush();
    await _routinesStore?.flush();
    await _pinsStore?.flush();
    await _layoutStore?.flush();
    await _placardStore?.flush();
    await _medicineStore?.flush();
    await _todoStore?.flush();
    await _notificationsStore?.flush();
    await _pipStore?.flush();
    await _recipesStore?.flush();
    await _ingredientsStore?.flush();
    await _foodStore?.flush();
    await _datesStore?.flush();
    await _subscriptionsStore?.flush();
    await _packingStore?.flush();
  }
}

/// Provided in `main()` once storage has been opened.
final appStorageProvider = Provider<AppStorage>((ref) {
  throw UnimplementedError('appStorageProvider must be overridden');
});
