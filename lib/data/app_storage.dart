import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:the_app/data/json_file_store.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/shop_item.dart';

/// Loads and saves all app data. Each feature has its own JSON file:
///
///     <app documents>/data/notes.json  {"version": 1, "notes": [...]}
///     <app documents>/data/shop.json   {"version": 1, "items": [...]}
///
/// Data is loaded once at startup ([open]) and then saved after every change
/// by the providers.
class AppStorage {
  static const formatVersion = 1;

  final JsonFileStore? _notesStore;
  final JsonFileStore? _shopStore;

  /// Data as loaded at startup.
  final List<Note> initialNotes;
  final List<ShopItem> initialShopItems;

  AppStorage._(
    this._notesStore,
    this._shopStore, {
    required this.initialNotes,
    required this.initialShopItems,
  });

  /// Storage that keeps nothing (for tests and previews).
  AppStorage.inMemory({
    this.initialNotes = const [],
    this.initialShopItems = const [],
  })  : _notesStore = null,
        _shopStore = null;

  /// Opens storage in [directory], or in the app's documents folder.
  static Future<AppStorage> open({Directory? directory}) async {
    final dir = directory ??
        Directory('${(await getApplicationDocumentsDirectory()).path}/data');
    final notesStore = JsonFileStore(File('${dir.path}/notes.json'));
    final shopStore = JsonFileStore(File('${dir.path}/shop.json'));

    return AppStorage._(
      notesStore,
      shopStore,
      initialNotes: await _load(notesStore, 'notes', Note.fromJson),
      initialShopItems: await _load(shopStore, 'items', ShopItem.fromJson),
    );
  }

  static Future<List<T>> _load<T>(
    JsonFileStore store,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final json = await store.read();
      if (json == null) return [];
      final list = (json as Map<String, dynamic>)[key] as List<dynamic>;
      return [for (final e in list) fromJson(e as Map<String, dynamic>)];
    } catch (e) {
      // Never overwrite data we could not read: move it aside and start
      // empty, so it can still be recovered by hand.
      final moved = await store.quarantine();
      debugPrint('Could not read ${store.file.path} ($e); moved to $moved');
      return [];
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

  /// Completes when every pending save is on disk.
  Future<void> flush() async {
    await _notesStore?.flush();
    await _shopStore?.flush();
  }
}

/// Provided in `main()` once storage has been opened.
final appStorageProvider = Provider<AppStorage>((ref) {
  throw UnimplementedError('appStorageProvider must be overridden');
});
