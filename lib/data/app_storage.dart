import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/json_file_store.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/counter.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/models/shop_item.dart';

/// Loads and saves all app data. Each feature has its own JSON file:
///
///     <app documents>/data/notes.json  {"version": 2, "notes": [...]}
///     <app documents>/data/shop.json   {"version": 2, "items": [...]}
///     <app documents>/data/security.json
///         {"version": 2, "masterPassword": {verifier} or null}
///     <app documents>/data/planner.json {"version": 4, "tasks": [...]}
///     <app documents>/data/routines.json
///         {"version": 1, "routines": [...], "days": [...]}
///     <app documents>/data/counters.json {"version": 2, "counters": [...]}
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
  /// none and are still read); 4 = tasks may have a colour (P9).
  static const plannerFormatVersion = 4;

  /// Version of `routines.json` (P8). History: 1 = first format.
  static const routinesFormatVersion = 1;

  final JsonFileStore? _notesStore;
  final JsonFileStore? _shopStore;
  final JsonFileStore? _securityStore;
  final JsonFileStore? _settingsStore;
  final JsonFileStore? _plannerStore;
  final JsonFileStore? _countersStore;
  final JsonFileStore? _preferencesStore;
  final JsonFileStore? _routinesStore;

  /// Data as loaded at startup.
  final List<Note> initialNotes;
  final List<ShopItem> initialShopItems;
  final List<PlannerTask> initialPlannerTasks;
  final RoutineBook initialRoutines;
  final List<Counter> initialCounters;
  final Preferences initialPreferences;

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
    this._routinesStore, {
    required this.initialNotes,
    required this.initialShopItems,
    required this.initialPlannerTasks,
    required this.initialRoutines,
    required this.initialCounters,
    required this.initialPreferences,
    required this.initialMasterPassword,
    required this.initialSectionLocks,
  });

  /// Storage that keeps nothing (for tests and previews).
  AppStorage.inMemory({
    this.initialNotes = const [],
    this.initialShopItems = const [],
    this.initialPlannerTasks = const [],
    this.initialRoutines = RoutineBook.empty,
    this.initialCounters = const [],
    this.initialPreferences = const Preferences(),
    this.initialMasterPassword,
    this.initialSectionLocks = const {},
  })  : _notesStore = null,
        _shopStore = null,
        _securityStore = null,
        _settingsStore = null,
        _plannerStore = null,
        _countersStore = null,
        _preferencesStore = null,
        _routinesStore = null;

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

    return AppStorage._(
      notesStore,
      shopStore,
      securityStore,
      settingsStore,
      plannerStore,
      countersStore,
      preferencesStore,
      routinesStore,
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
      initialCounters: await _load(
        countersStore,
        [],
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
      'version': formatVersion,
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

  Future<void> saveCounters(List<Counter> counters) async {
    await _countersStore?.write({
      'version': formatVersion,
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

  /// Completes when every pending save is on disk.
  Future<void> flush() async {
    await _notesStore?.flush();
    await _shopStore?.flush();
    await _securityStore?.flush();
    await _settingsStore?.flush();
    await _plannerStore?.flush();
    await _countersStore?.flush();
    await _preferencesStore?.flush();
    await _routinesStore?.flush();
  }
}

/// Provided in `main()` once storage has been opened.
final appStorageProvider = Provider<AppStorage>((ref) {
  throw UnimplementedError('appStorageProvider must be overridden');
});
