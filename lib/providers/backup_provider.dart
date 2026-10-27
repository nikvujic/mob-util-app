import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/backup.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/counter.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/placard.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/placard_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/providers/subscriptions_provider.dart';
import 'package:the_app/providers/packing_provider.dart';
import 'package:the_app/providers/people_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/providers/todo_provider.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/models/pip_life.dart';

/// Outcome of an export, for the UI to report.
enum ExportResult { saved, cancelled }

/// Creates backups of all app data.
class BackupExporter {
  final Ref _ref;

  /// Injectable clock, so tests get stable timestamps.
  final DateTime Function() _now;

  BackupExporter(this._ref, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// A snapshot of everything the app holds right now. Includes the master
  /// password record if some notes are locked: it holds their key.
  Backup snapshot() {
    final notes = _ref.read(notesProvider);
    return Backup(
      createdAt: _now(),
      appVersion: _ref.read(appVersionProvider),
      notes: notes,
      shopItems: _ref.read(shopProvider),
      plannerTasks: _ref.read(plannerProvider),
      routines: _ref.read(routinesProvider),
      plannerPins: _ref.read(pinsProvider),
      counters: _ref.read(countersProvider),
      placard: _ref.read(placardProvider),
      medicine: _ref.read(medicineProvider),
      todo: _ref.read(todoProvider),
      pip: _ref.read(pipLifeProvider),
      recipes: _ref.read(recipesProvider),
      ingredients: _ref.read(ingredientsProvider),
      food: _ref.read(foodProvider),
      dates: _ref.read(datesProvider),
      subscriptions: _ref.read(subscriptionsProvider),
      packing: _ref.read(packingProvider),
      people: _ref.read(peopleProvider),
      masterPassword:
          notes.any((n) => n.isLocked) ? _ref.read(securityProvider) : null,
    );
  }

  /// Writes a plain (readable) snapshot to a file the user picks. Errors
  /// (e.g. storage full) are passed on to the caller.
  Future<ExportResult> export() async {
    final backup = snapshot();
    return _save(backup.fileName(), backup.encode());
  }

  /// Like [export], but the file is encrypted with [key] (from the master
  /// password) and can only be restored with that password.
  Future<ExportResult> exportEncrypted(PasswordKey key) async {
    final backup = snapshot();
    return _save(
      backup.fileName(encrypted: true),
      await backup.encodeEncrypted(key),
    );
  }

  Future<ExportResult> _save(String fileName, String contents) async {
    final saved = await _ref.read(backupFilesProvider).save(
          fileName: fileName,
          bytes: utf8.encode(contents),
        );
    return saved ? ExportResult.saved : ExportResult.cancelled;
  }
}

final backupExporterProvider = Provider<BackupExporter>(BackupExporter.new);

/// A user-facing reason why a file can't be imported.
class ImportException implements Exception {
  final String message;

  const ImportException(this.message);

  @override
  String toString() => 'ImportException: $message';
}

/// A backup that can be restored, with what to show before restoring.
class RestorableBackup {
  final Backup _backup;

  /// For an encrypted backup: the key from its password, which usually
  /// also opens its master password record.
  final PasswordKey? _fileKey;

  RestorableBackup._(this._backup, [this._fileKey]);

  DateTime get createdAt => _backup.createdAt;
  int get noteCount => _backup.notes.length;
  int get lockedNoteCount => _backup.notes.where((n) => n.isLocked).length;
  int get shopItemCount => _backup.shopItems.length;
  int get plannerTaskCount => _backup.plannerTasks.length;
  int get routineCount => _backup.routines.routines.length;
  int get pinCount => _backup.plannerPins.length;
  int get counterCount => _backup.counters.length;
  int get todoCount => _backup.todo.length;
  int get recipeCount => _backup.recipes.length;

  // What's in it, to pick from (restoring part of it, Round 28).
  List<Note> get notes => _backup.notes;
  List<TodoItem> get todo => _backup.todo;
  List<ShopItem> get shopItems => _backup.shopItems;
  List<PlannerTask> get plannerTasks => _backup.plannerTasks;
  List<Routine> get routines => _backup.routines.routines;
  List<PlannerPin> get plannerPins => _backup.plannerPins;
  List<Counter> get counters => _backup.counters;
  List<Medicine> get medicines => _backup.medicine.medicines;
  List<Recipe> get recipes => _backup.recipes;
  List<DateEntry> get dates => _backup.dates.dates;
  List<Subscription> get subscriptions => _backup.subscriptions.subscriptions;
  List<PackingList> get packingLists => _backup.packing.lists;
  List<Person> get people => _backup.people?.people ?? const [];
}

/// The kinds of things in a backup, to restore some of them (Round 28).
enum BackupPart {
  notes,
  todo,
  shop,
  tasks,
  routines,
  reminders,
  counters,
  medicines,
  recipes,

  /// Birthdays & dates (Round 57).
  dates,

  /// Subscriptions (Round 79).
  subscriptions,

  /// Packing lists (Round 94).
  packing,

  /// People (Round 108).
  people
}

/// [book] with the ingredients [ids] from [from] it doesn't have yet,
/// each into the section of the same id there (or its name), made at the
/// end if missing (Round 42: restoring part of a backup).
IngredientBook withIngredients(
  IngredientBook book,
  IngredientBook from,
  Set<String> ids,
) {
  final sections = [...book.sections];
  for (final section in from.sections) {
    final missing = [
      for (final i in section.items)
        if (ids.contains(i.id) && book.byId(i.id) == null) i,
    ];
    if (missing.isEmpty) continue;
    var at = sections.indexWhere((s) => s.id == section.id);
    if (at == -1) at = sections.indexWhere((s) => s.name == section.name);
    if (at == -1) {
      sections.add(IngredientSection(id: section.id, name: section.name));
      at = sections.length - 1;
    }
    sections[at] =
        sections[at].copyWith(items: [...sections[at].items, ...missing]);
  }
  return IngredientBook(sections);
}

/// A copy's title (Round 30): "Bank" → "Bank (Copy)".
String copyTitle(String title) => '$title (Copy)';

/// What [BackupImporter.restorePart] did.
class PartRestore {
  /// Puts things back as they were, like a full restore's.
  final RestoreUndo undo;

  /// How many things were added; of them, how many as copies (one with
  /// the same id was still in the app, so both are kept).
  final int added;
  final int copies;

  /// Planner tasks and routines left out: their time is taken, or they
  /// are still in the app.
  final int skipped;

  const PartRestore._(
    this.undo, {
    required this.added,
    required this.copies,
    required this.skipped,
  });
}

/// A picked backup file: plain (ready) or encrypted (needs its password).
sealed class PickedBackup {}

class PlainPick extends PickedBackup {
  final RestorableBackup backup;

  PlainPick._(this.backup);
}

class EncryptedPick extends PickedBackup {
  final EncryptedBackupFile _file;

  EncryptedPick._(this._file);

  /// The backup, or null if [password] is wrong. Throws [ImportException]
  /// if the right password reveals damaged contents.
  Future<RestorableBackup?> unlock(String password) async {
    try {
      final opened = await _file.openWithKey(password);
      return opened == null
          ? null
          : RestorableBackup._(opened.backup, opened.key);
    } on BackupFormatException catch (e) {
      throw ImportException(e.message);
    }
  }
}

/// What [BackupImporter.restore] replaced, to undo it.
class RestoreUndo {
  final Backup _previous;
  final PasswordVerifier? _previousMasterPassword;

  /// Whether the restore took over the backup's master password (this app
  /// had none), so its locked notes open with that password.
  final bool adoptedMasterPassword;

  RestoreUndo._(
    this._previous,
    this._previousMasterPassword, {
    required this.adoptedMasterPassword,
  });
}

/// Asks the user for this app's master password (unlocking it) and returns
/// the key of locked notes; null if they cancel.
typedef AskThisAppKey = Future<DataKey?> Function();

/// Asks the user for the master password the backup was made with, checked
/// against [record], and returns the key it protects; null if they cancel.
typedef AskBackupKey = Future<DataKey?> Function(PasswordVerifier record);

/// Reads backup files and restores them (D2, D2a).
class BackupImporter {
  /// Larger files can't be backups of this app; refuse before decoding.
  static const maxFileBytes = 20 * 1024 * 1024;

  final Ref _ref;

  BackupImporter(this._ref);

  /// Lets the user pick a file. Null if they cancelled. Throws
  /// [ImportException] if it isn't a backup this app can read.
  Future<PickedBackup?> pick() async {
    final bytes = await _ref.read(backupFilesProvider).pick();
    return bytes == null ? null : read(bytes);
  }

  /// Parses file contents. Throws [ImportException] if they aren't a
  /// backup this app can read.
  PickedBackup read(Uint8List bytes) {
    const notABackup = ImportException('This file is not a backup.');
    if (bytes.length > maxFileBytes) throw notABackup;
    final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException {
      throw notABackup;
    }
    try {
      return switch (BackupFile.parse(source)) {
        PlainBackupFile(:final backup) =>
          PlainPick._(RestorableBackup._(backup)),
        final EncryptedBackupFile file => EncryptedPick._(file),
      };
    } on BackupFormatException catch (e) {
      throw ImportException(e.message);
    }
  }

  /// Replaces all notes and shop items with [backup]'s, and waits until
  /// they're saved. Returns what it replaced, for [undo]; null if the user
  /// cancelled a password prompt (nothing changed then).
  ///
  /// Locked notes (D3) stay locked:
  /// - If this app has no master password, it takes over the backup's, so
  ///   they open with the password they were locked with.
  /// - Otherwise they must open with this app's key ([thisAppKey]; e.g. a
  ///   backup from this phone), or else with the backup's ([backupKey], or
  ///   the encrypted file's password if it fits); then they are re-locked
  ///   under this app's key.
  ///
  /// Throws [ImportException] if locked notes can't be restored.
  Future<RestoreUndo?> restore(
    RestorableBackup backup, {
    AskThisAppKey thisAppKey = _cancelled,
    AskBackupKey backupKey = _cancelledFor,
  }) async {
    final security = _ref.read(securityProvider.notifier);
    final previousMasterPassword = _ref.read(securityProvider);
    final previous = _ref.read(backupExporterProvider).snapshot();
    final source = backup._backup;
    var notes = source.notes;
    var adopt = false;

    if (notes.any((n) => n.isLocked)) {
      final record = source.masterPassword;
      if (previousMasterPassword == null) {
        if (record == null) throw _missingKey;
        adopt = true;
      } else {
        final relocked = await _relock(
          notes,
          record,
          fileKey: backup._fileKey,
          thisAppKey: thisAppKey,
          backupKey: backupKey,
        );
        if (relocked == null) return null;
        notes = relocked;
      }
    }

    if (adopt) {
      // The password first: locked notes must never be saved without it.
      security.restore(source.masterPassword);
      await _ref.read(appStorageProvider).flush();
    }
    await _apply(
      notes,
      source.shopItems,
      source.plannerTasks,
      source.routines,
      source.plannerPins,
      source.counters,
      source.placard,
      source.medicine,
      source.todo,
      source.pip,
      source.recipes,
      source.ingredients,
      source.food,
      source.dates,
      source.subscriptions,
      source.packing,
      source.people,
    );
    return RestoreUndo._(
      previous,
      previousMasterPassword,
      adoptedMasterPassword: adopt,
    );
  }

  /// Adds the things [picked] (ids, by kind) from [backup] to what's in
  /// the app, leaving the rest as it is (Round 28: e.g. one note back).
  /// Something still in the app (the same id) comes back as a copy
  /// beside it; planner tasks and routines whose time is taken (or that
  /// are still there) are left out. A medicine comes with its history.
  /// Locked notes are handled as in [restore]. Null if the user
  /// cancelled a password prompt (nothing changed then).
  Future<PartRestore?> restorePart(
    RestorableBackup backup,
    Map<BackupPart, Set<String>> picked, {
    AskThisAppKey thisAppKey = _cancelled,
    AskBackupKey backupKey = _cancelledFor,
  }) async {
    final source = backup._backup;
    bool chosen(BackupPart part, String id) =>
        picked[part]?.contains(id) ?? false;
    final previousMasterPassword = _ref.read(securityProvider);
    final previous = _ref.read(backupExporterProvider).snapshot();
    var added = 0, copies = 0, skipped = 0;

    // Notes, locked ones under this app's key (or the backup's, adopted).
    var notes = [
      for (final n in source.notes)
        if (chosen(BackupPart.notes, n.id)) n,
    ];
    var adopt = false;
    DataKey? lockKey;
    if (notes.any((n) => n.isLocked)) {
      final record = source.masterPassword;
      if (previousMasterPassword == null) {
        if (record == null) throw _missingKey;
        adopt = true;
      } else {
        final ours = _ref.read(sessionProvider)?.dataKey ?? await thisAppKey();
        if (ours == null) return null;
        final relocked = await _relock(
          notes,
          record,
          fileKey: backup._fileKey,
          thisAppKey: () async => ours,
          backupKey: backupKey,
        );
        if (relocked == null) return null;
        notes = relocked;
        lockKey = ours;
      }
    }
    final noteIds = {for (final n in _ref.read(notesProvider)) n.id};
    final restoredNotes = <Note>[];
    for (final note in notes) {
      added++;
      if (!noteIds.contains(note.id)) {
        restoredNotes.add(note);
        continue;
      }
      copies++;
      final copy = Note.fromJson({
        ...note.toJson(),
        'id': generateId(),
        'title': copyTitle(note.title),
      });
      if (!note.isLocked) {
        restoredNotes.add(copy);
        continue;
      }
      // Sealed for its id: sealed again for the copy's.
      if (lockKey == null) {
        final record = source.masterPassword!;
        final fileKey = backup._fileKey;
        lockKey = fileKey == null ? null : await record.unwrapDataKey(fileKey);
        lockKey ??= await backupKey(record);
        if (lockKey == null) return null;
      }
      final content = await NotesNotifier.openContent(note, lockKey);
      restoredNotes.add(await NotesNotifier.lockedCopy(copy, content, lockKey));
    }

    /// [current] with the [part] picked from [from] after it; one with an
    /// id already there gets a new one.
    List<T> merged<T>(
      List<T> current,
      List<T> from,
      BackupPart part,
      String Function(T) idOf,
      Map<String, dynamic> Function(T) toJson,
      T Function(Map<String, dynamic>) fromJson, {
      required String name,
    }) {
      final ids = {for (final item in current) idOf(item)};
      final result = [...current];
      for (final item in from) {
        if (!chosen(part, idOf(item))) continue;
        added++;
        if (ids.contains(idOf(item))) {
          copies++;
          final json = toJson(item);
          result.add(fromJson({
            ...json,
            'id': generateId(),
            name: copyTitle(json[name] as String),
          }));
        } else {
          result.add(item);
        }
      }
      return result;
    }

    if (adopt) {
      // The password first: locked notes must never be saved without it.
      _ref.read(securityProvider.notifier).restore(source.masterPassword);
      await _ref.read(appStorageProvider).flush();
    }
    if (restoredNotes.isNotEmpty) {
      _ref
          .read(notesProvider.notifier)
          .replaceAll([...restoredNotes, ..._ref.read(notesProvider)]);
    }
    _ref.read(todoProvider.notifier).replaceAll(merged(
          _ref.read(todoProvider),
          source.todo,
          BackupPart.todo,
          (i) => i.id,
          (i) => i.toJson(),
          TodoItem.fromJson,
          name: 'text',
        ));
    _ref.read(shopProvider.notifier).replaceAll(merged(
          _ref.read(shopProvider),
          source.shopItems,
          BackupPart.shop,
          (i) => i.id,
          (i) => i.toJson(),
          ShopItem.fromJson,
          name: 'name',
        ));
    _ref.read(pinsProvider.notifier).replaceAll(merged(
          _ref.read(pinsProvider),
          source.plannerPins,
          BackupPart.reminders,
          (p) => p.id,
          (p) => p.toJson(),
          PlannerPin.fromJson,
          name: 'title',
        ));
    _ref.read(countersProvider.notifier).replaceAll(merged(
          _ref.read(countersProvider),
          source.counters,
          BackupPart.counters,
          (c) => c.id,
          (c) => c.toJson(),
          Counter.fromJson,
          name: 'name',
        ));

    // Tasks and routines still there, or whose time is taken: left out.
    final planner = _ref.read(plannerProvider.notifier);
    for (final task in source.plannerTasks) {
      if (!chosen(BackupPart.tasks, task.id)) continue;
      if (_ref.read(plannerProvider).any((t) => t.id == task.id)) {
        skipped++;
        continue;
      }
      try {
        planner.restoreTask(task);
        added++;
      } on TaskOverlapException {
        skipped++;
      }
    }
    final routines = _ref.read(routinesProvider.notifier);
    for (final routine in source.routines.routines) {
      if (!chosen(BackupPart.routines, routine.id)) continue;
      if (_ref.read(routinesProvider).routines.any((r) => r.id == routine.id)) {
        skipped++;
        continue;
      }
      try {
        routines.restore(routine, [
          for (final d in source.routines.days.values)
            if (d.routineId == routine.id) d,
        ]);
        added++;
      } on TaskOverlapException {
        skipped++;
      }
    }

    // Medicines, each with its history.
    final book = _ref.read(medicineProvider);
    final medicineIds = {for (final m in book.medicines) m.id};
    final medicines = [...book.medicines];
    final marks = [...book.taken];
    for (final medicine in source.medicine.medicines) {
      if (!chosen(BackupPart.medicines, medicine.id)) continue;
      added++;
      var id = medicine.id;
      var name = medicine.name;
      if (medicineIds.contains(id)) {
        copies++;
        id = generateId();
        name = copyTitle(name);
      }
      medicines.add(
        Medicine.fromJson({...medicine.toJson(), 'id': id, 'name': name}),
      );
      for (final mark in source.medicine.taken) {
        if (mark.medicine == medicine.id) {
          marks.add(DoseTaken.fromJson({...mark.toJson(), 'medicine': id}));
        }
      }
    }
    _ref
        .read(medicineProvider.notifier)
        .replaceAll(MedicineBook(medicines: medicines, taken: marks));

    // Recipes (Round 42), each bringing its ingredients the list doesn't
    // have yet (by id), into a section of the backup's name.
    final pickedRecipes = [
      for (final r in source.recipes)
        if (chosen(BackupPart.recipes, r.id)) r,
    ];
    if (pickedRecipes.isNotEmpty) {
      _ref.read(recipesProvider.notifier).replaceAll(merged(
            _ref.read(recipesProvider),
            pickedRecipes,
            BackupPart.recipes,
            (r) => r.id,
            (r) => r.toJson(),
            Recipe.fromJson,
            name: 'name',
          ));
      final wanted = {
        for (final r in pickedRecipes)
          for (final i in r.ingredients)
            if (i.ingredientId != null) i.ingredientId!,
      };
      _ref.read(ingredientsProvider.notifier).replaceAll(withIngredients(
          _ref.read(ingredientsProvider), source.ingredients, wanted));
    }

    // Dates (Round 57).
    final pickedDates = [
      for (final d in source.dates.dates)
        if (chosen(BackupPart.dates, d.id)) d,
    ];
    if (pickedDates.isNotEmpty) {
      _ref.read(datesProvider.notifier).replaceAll(DateBook(merged(
            _ref.read(datesProvider).dates,
            pickedDates,
            BackupPart.dates,
            (d) => d.id,
            (d) => d.toJson(),
            DateEntry.fromJson,
            name: 'title',
          )));
    }

    // Subscriptions (Round 79).
    final pickedSubscriptions = [
      for (final s in source.subscriptions.subscriptions)
        if (chosen(BackupPart.subscriptions, s.id)) s,
    ];
    if (pickedSubscriptions.isNotEmpty) {
      _ref.read(subscriptionsProvider.notifier).replaceAll(
            SubscriptionBook(merged(
              _ref.read(subscriptionsProvider).subscriptions,
              pickedSubscriptions,
              BackupPart.subscriptions,
              (s) => s.id,
              (s) => s.toJson(),
              Subscription.fromJson,
              name: 'name',
            )),
          );
    }

    // Packing lists (Round 94), each with its own sections (Round 95).
    final pickedLists = [
      for (final l in source.packing.lists)
        if (chosen(BackupPart.packing, l.id)) l,
    ];
    if (pickedLists.isNotEmpty) {
      final now = _ref.read(packingProvider);
      final all = merged(
        now.lists,
        pickedLists,
        BackupPart.packing,
        (l) => l.id,
        (l) => l.toJson(),
        PackingList.fromJson,
        name: 'name',
      );
      _ref.read(packingProvider.notifier).replaceAll(now.copyWith(lists: all));
    }

    // People (Round 108): one still here is left as is; the relations
    // between the people there now come too, and each one's birthday is
    // put back on the Dates page.
    final fromPeople = source.people;
    if (fromPeople != null) {
      final people = _ref.read(peopleProvider.notifier);
      final here = {for (final p in _ref.read(peopleProvider).people) p.id};
      final back = <Person>[];
      for (final p in fromPeople.people) {
        if (!chosen(BackupPart.people, p.id)) continue;
        if (here.contains(p.id)) {
          skipped++;
          continue;
        }
        added++;
        back.add(p);
      }
      if (back.isNotEmpty) {
        final now = _ref.read(peopleProvider);
        final ids = {...here, for (final p in back) p.id};
        final known = {for (final r in now.relations) r.id};
        people.replaceAll(now.copyWith(
          people: [
            ...now.people,
            for (final p in back) p.copyWith(dateId: () => null)
          ],
          relations: [
            ...now.relations,
            for (final r in fromPeople.relations)
              if (ids.contains(r.from) &&
                  ids.contains(r.to) &&
                  !known.contains(r.id) &&
                  !now.relations
                      .any((o) => o.involves(r.from) && o.involves(r.to)))
                r,
          ],
        ));
        // Their birthdays: a date that's theirs already is kept, else made.
        final dates = _ref.read(datesProvider);
        for (final p in back) {
          final own = dates.dates.where((d) => d.personId == p.id).firstOrNull;
          people.save(people.byId(p.id)!.copyWith(dateId: () => own?.id));
        }
      }
    }

    await _ref.read(appStorageProvider).flush();
    return PartRestore._(
      RestoreUndo._(
        previous,
        previousMasterPassword,
        adoptedMasterPassword: adopt,
      ),
      added: added,
      copies: copies,
      skipped: skipped,
    );
  }

  /// Puts back the data (and master password) a [restore] replaced.
  Future<void> undo(RestoreUndo undo) async {
    await _apply(
      undo._previous.notes,
      undo._previous.shopItems,
      undo._previous.plannerTasks,
      undo._previous.routines,
      undo._previous.plannerPins,
      undo._previous.counters,
      undo._previous.placard,
      undo._previous.medicine,
      undo._previous.todo,
      undo._previous.pip,
      undo._previous.recipes,
      undo._previous.ingredients,
      undo._previous.food,
      undo._previous.dates,
      undo._previous.subscriptions,
      undo._previous.packing,
      undo._previous.people,
    );
    if (undo.adoptedMasterPassword) {
      _ref.read(securityProvider.notifier).restore(
            undo._previousMasterPassword,
          );
      await _ref.read(appStorageProvider).flush();
    }
  }

  static Future<DataKey?> _cancelled() async => null;
  static Future<DataKey?> _cancelledFor(PasswordVerifier _) async => null;

  static const _missingKey = ImportException(
    "This backup's locked notes can't be restored: the backup doesn't "
    'include their key.',
  );

  /// [notes] with every locked one under this app's key; null if the user
  /// cancelled a prompt.
  Future<List<Note>?> _relock(
    List<Note> notes,
    PasswordVerifier? record, {
    required PasswordKey? fileKey,
    required AskThisAppKey thisAppKey,
    required AskBackupKey backupKey,
  }) async {
    final ours = _ref.read(sessionProvider)?.dataKey ?? await thisAppKey();
    if (ours == null) return null;

    final locked = notes.where((n) => n.isLocked).toList();
    if (await _allOpen(locked, ours)) return notes; // already ours

    if (record == null) throw _missingKey;
    var theirs = fileKey == null ? null : await record.unwrapDataKey(fileKey);
    theirs ??= await backupKey(record);
    if (theirs == null) return null;

    final relocked = <String, Note>{};
    for (final note in locked) {
      final String content;
      try {
        content = await NotesNotifier.openContent(note, theirs);
      } on DecryptionException {
        throw const ImportException(
          "Some locked notes in this backup can't be opened with its "
          'master password.',
        );
      }
      relocked[note.id] = await NotesNotifier.lockedCopy(note, content, ours);
    }
    return [for (final n in notes) relocked[n.id] ?? n];
  }

  static Future<bool> _allOpen(List<Note> notes, DataKey key) async {
    try {
      for (final note in notes) {
        await NotesNotifier.openContent(note, key);
      }
      return true;
    } on DecryptionException {
      return false;
    }
  }

  Future<void> _apply(
    List<Note> notes,
    List<ShopItem> shopItems,
    List<PlannerTask> plannerTasks,
    RoutineBook routines,
    List<PlannerPin> plannerPins,
    List<Counter> counters,
    Placard placard,
    MedicineBook medicine,
    List<TodoItem> todo,
    PipLife? pip,
    List<Recipe> recipes,
    IngredientBook ingredients,
    FoodBook food,
    DateBook dates,
    SubscriptionBook subscriptions,
    PackingBook packing,
    PeopleBook? people,
  ) async {
    _ref.read(notesProvider.notifier).replaceAll(notes);
    _ref.read(shopProvider.notifier).replaceAll(shopItems);
    _ref.read(plannerProvider.notifier).replaceAll(plannerTasks);
    _ref.read(routinesProvider.notifier).replaceAll(routines);
    _ref.read(pinsProvider.notifier).replaceAll(plannerPins);
    _ref.read(countersProvider.notifier).replaceAll(counters);
    _ref.read(placardProvider.notifier).replace(placard);
    _ref.read(medicineProvider.notifier).replaceAll(medicine);
    _ref.read(todoProvider.notifier).replaceAll(todo);
    // From before him: he stays as he is.
    if (pip != null) _ref.read(pipLifeProvider.notifier).replace(pip);
    _ref.read(recipesProvider.notifier).replaceAll(recipes);
    _ref.read(ingredientsProvider.notifier).replaceAll(ingredients);
    _ref.read(foodProvider.notifier).replaceAll(food);
    _ref.read(datesProvider.notifier).replaceAll(dates);
    _ref.read(subscriptionsProvider.notifier).replaceAll(subscriptions);
    _ref.read(packingProvider.notifier).replaceAll(packing);
    // From before them: People stay as they are.
    if (people != null) _ref.read(peopleProvider.notifier).replaceAll(people);
    await _ref.read(appStorageProvider).flush();
  }
}

final backupImporterProvider = Provider<BackupImporter>(BackupImporter.new);
