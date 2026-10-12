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
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/placard.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/models/shop_item.dart';

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
///     <app documents>/data/counters.json {"version": 3, "counters": [...]}
///     <app documents>/data/preferences.json
///         {"version": 2, "theme": "green", "counterFeedback": true}
///     <app documents>/data/settings.json
///         {"version": 2, "sectionLocks": ["shop", ...]}
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
  /// (O13).
  static const medicineFormatVersion = 2;

  /// Version of `shop.json`, which moves on its own from here. History:
  /// 1–2 = as [formatVersion]; 3 = items may have a quantity (S7).
  static const shopFormatVersion = 3;

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

  /// The master password's verifier, or null if none is set.
  final PasswordVerifier? initialMasterPassword;

  /// Sections locked behind the master password (L5).
  final Set<AppSection> initialSectionLocks;

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
    this._medicineStore, {
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
    required this.initialMasterPassword,
    required this.initialSectionLocks,
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
    this.initialMasterPassword,
    this.initialSectionLocks = const {},
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

    return AppStorage._(
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
      initialSectionLocks: await _load(settingsStore, const {}, (json) {
        final ids = json['sectionLocks'] as List<dynamic>? ?? const [];
        // Unknown sections (from a newer app) are skipped, not fatal.
        return {
          for (final id in ids) AppSection.fromId(id as String),
        }.whereType<AppSection>().toSet();
      }),
    );
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

  Future<void> saveSectionLocks(Set<AppSection> sections) async {
    await _settingsStore?.write({
      'version': formatVersion,
      'sectionLocks': [
        for (final s in AppSection.values)
          if (sections.contains(s)) s.name,
      ],
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
        ])
          if (store != null && store.unreadable)
            store.file.uri.pathSegments.last,
      ];

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
  }
}

/// Provided in `main()` once storage has been opened.
final appStorageProvider = Provider<AppStorage>((ref) {
  throw UnimplementedError('appStorageProvider must be overridden');
});
