import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:the_app/core/crypto.dart' hide open;
import 'package:the_app/core/crypto.dart' as crypto show open;
import 'package:the_app/data/document_files.dart';
import 'package:the_app/models/counter.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/models/placard.dart';
import 'package:the_app/models/planner_pin.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/models/todo_item.dart';

/// Thrown when a backup file can't be read. [message] is shown to the user.
class BackupFormatException implements Exception {
  final String message;

  const BackupFormatException(this.message);

  @override
  String toString() => 'BackupFormatException: $message';
}

/// A snapshot of all app data, as written to (and read from) a backup file:
///
///     {
///       "format": "the-app-backup",
///       "version": 2,
///       "createdAt": "2026-10-08T07:30:00.000Z",
///       "appVersion": "0.7.0 (8)",
///       "data": { "notes": [...], "shopItems": [...],
///                 "plannerTasks": [...], "routines": {...},
///                 "plannerPins": [...],
///                 "counters": [...],
///                 "masterPassword": {...} }
///     }
///
/// `masterPassword` (since version 2) is only there if some notes (or,
/// since 34, the Documents page: `documentsSealed`) are locked: it's the master password record (as in `security.json`), which
/// holds the key of the locked notes, itself encrypted with the password.
/// Locked notes stay encrypted in every backup, plain or not.
///
/// An encrypted backup keeps the same header but replaces `data` with the
/// whole plain document, sealed with a key from the master password:
///
///     {
///       "format": "the-app-backup", "version": 2, "encrypted": true,
///       "createdAt": "…", "appVersion": "…",
///       "kdf": {Argon2id parameters}, "sealed": {AES-256-GCM box}
///     }
///
/// Since version 34 the file is a zip ([zip]): that document as
/// `backup.json`, and the Documents page's pictures as `pictures/<id>`
/// (stored, not compressed: they're JPEGs). In an encrypted backup each
/// picture is sealed with the same key as the document. Older backups are
/// the document alone, and still read ([BackupFile.read] tells them apart
/// by their first bytes).
///
/// [version] goes up whenever the layout changes; [BackupFile.parse] must
/// keep reading every older version.
class Backup {
  /// Authenticated with the encrypted data, so nothing else sealed with the
  /// same key can be passed off as a backup.
  static const sealContext = 'the-app/backup';

  static const format = 'the-app-backup';

  /// History: 1 = first format; 2 = notes may be locked
  /// (`lockedContent`); 3 = planner tasks and counters (`plannerTasks`,
  /// `counters`; older backups have none); 4 = planner tasks have start
  /// and end times, and a count from a since-removed page (`dzoniCount`,
  /// now ignored); 5 = planner
  /// routines (`routines`, as in `routines.json`) and block colours;
  /// 6 = planner reminders (`plannerPins`, P14); 7 = tasks and routines
  /// may have a description (P20); 8 = shop items may have a quantity
  /// (S7); 9 = Placard's text and count (`placard`, O4); 10 = counters
  /// may have a step, colour and limits (O5); 11 = the medicine tracker
  /// (`medicine`, as in `medicine.json`, O6); 12 = doses missed or not
  /// sure, taken ones maybe without a time (O13); 13 = a medicine may
  /// remind again after its doses; 14 = a medicine may be
  /// important; 15 = the to-do note's list (`todo`);
  /// 16 = to-do things may be done; 17 = Pip, the pet (`pip`);
  /// 18 = his energy and batteries; 19 = a medicine
  /// may be taken on some weekdays only; 20 = recipes and the
  /// ingredients list (`recipes`, `ingredients`, as in their files);
  /// 21 = to-do things may be waiting; 22 = the
  /// food tracker (`food`, as in `food.json`); 23 = birthdays &
  /// dates (`dates`, as in `dates.json`); 24 = a holiday or an
  /// event may last several days (`days`); 25 = and be of a
  /// kind (`kind`); 26 = Pip's adventures (in `pip`); 27 = a ski trip's travel (in `dates`); 28 = a shop
  /// item's typed amount (in `shopItems`); 29 = subscriptions
  /// (`subscriptions`, as in `subscriptions.json`); 30 =
  /// packing lists (`packing`, as in `packing.json`); 31 = a
  /// packing list's own sections (in `packing`); 32 = people
  /// (`people`, as in `people.json`), and a date's person (in
  /// `dates`); 33 = Pip's quests (in `pip`). The
  /// food tracker's gone: `food` isn't written, and is ignored in older
  /// backups (the format's otherwise the same, so still 33);
  /// 34 = a zip, with the Documents page (`documents`, as in
  /// `documents.json`, and its pictures beside the document).
  static const version = 34;

  /// The document's name in the zip.
  static const documentEntry = 'backup.json';

  /// The pictures' folder in the zip.
  static const picturesFolder = 'pictures/';

  final DateTime createdAt;
  final String appVersion;
  final List<Note> notes;
  final List<ShopItem> shopItems;
  final List<PlannerTask> plannerTasks;

  /// Planner routines (P8); none in backups from before them.
  final RoutineBook routines;

  /// Planner reminders (P14); none in backups from before them.
  final List<PlannerPin> plannerPins;
  final List<Counter> counters;

  /// Placard's text and count (O4); a fresh one in backups from before.
  final Placard placard;

  /// The medicine tracker (O6); empty in backups from before it.
  final MedicineBook medicine;

  /// The to-do note's list; empty in backups from before it.
  final List<TodoItem> todo;

  /// Pip; null in backups from before him: restoring one of
  /// those leaves him as he is.
  final PipLife? pip;

  /// Recipes and the ingredients list; none in backups from
  /// before them.
  final List<Recipe> recipes;
  final IngredientBook ingredients;

  /// Birthdays & dates; empty in backups from before them.
  final DateBook dates;

  /// Subscriptions; empty in backups from before them.
  final SubscriptionBook subscriptions;

  /// Packing lists and the default sections; the usual
  /// sections and no lists in backups from before them.
  PackingBook get packing => _packing ?? PackingBook.initial;
  final PackingBook? _packing;

  /// People; null in backups from before them (restoring one
  /// leaves the People page as it is).
  final PeopleBook? people;

  /// The Documents page; null in backups from before it (restoring one
  /// leaves the page as it is).
  final DocumentBook? documents;

  /// The Documents page while locked: the list sealed with the master
  /// password's data key (the record in [masterPassword]); its pictures
  /// are sealed too. Null when not locked ([documents] then).
  final SealedBox? documentsSealed;

  /// The Documents page's pictures, by id, as stored. Not in the JSON
  /// document: beside it in the zip.
  final Map<String, Uint8List> pictures;

  /// The master password record the locked notes need, if any are locked.
  final PasswordVerifier? masterPassword;

  const Backup({
    required this.createdAt,
    required this.appVersion,
    required this.notes,
    required this.shopItems,
    this.plannerTasks = const [],
    this.routines = RoutineBook.empty,
    this.plannerPins = const [],
    this.counters = const [],
    this.placard = Placard.initial,
    this.medicine = MedicineBook.empty,
    this.todo = const [],
    this.pip,
    this.recipes = const [],
    this.ingredients = IngredientBook.empty,
    this.dates = DateBook.empty,
    this.subscriptions = SubscriptionBook.empty,
    PackingBook? packing,
    this.people,
    this.documents,
    this.documentsSealed,
    this.pictures = const {},
    this.masterPassword,
  }) : _packing = packing;

  /// [backup] with the Documents page sealed ([documentsSealed]) instead
  /// of open.
  factory Backup.fromParts(Backup backup,
          {required SealedBox documentsSealed}) =>
      Backup(
        createdAt: backup.createdAt,
        appVersion: backup.appVersion,
        notes: backup.notes,
        shopItems: backup.shopItems,
        plannerTasks: backup.plannerTasks,
        routines: backup.routines,
        plannerPins: backup.plannerPins,
        counters: backup.counters,
        placard: backup.placard,
        medicine: backup.medicine,
        todo: backup.todo,
        pip: backup.pip,
        recipes: backup.recipes,
        ingredients: backup.ingredients,
        dates: backup.dates,
        subscriptions: backup.subscriptions,
        packing: backup._packing,
        people: backup.people,
        documentsSealed: documentsSealed,
        pictures: backup.pictures,
        masterPassword: backup.masterPassword,
      );

  /// This backup with [pictures] beside it.
  Backup withPictures(Map<String, Uint8List> pictures) => Backup(
        createdAt: createdAt,
        appVersion: appVersion,
        notes: notes,
        shopItems: shopItems,
        plannerTasks: plannerTasks,
        routines: routines,
        plannerPins: plannerPins,
        counters: counters,
        placard: placard,
        medicine: medicine,
        todo: todo,
        pip: pip,
        recipes: recipes,
        ingredients: ingredients,
        dates: dates,
        subscriptions: subscriptions,
        packing: _packing,
        people: people,
        documents: documents,
        documentsSealed: documentsSealed,
        pictures: pictures,
        masterPassword: masterPassword,
      );

  /// Suggested file name, e.g. `the-app-backup-2026-10-08-0930.zip` or
  /// `…-0930-encrypted.zip` (local time, so it matches what the user sees).
  String fileName({bool encrypted = false}) {
    final t = createdAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'the-app-backup-${t.year}-${two(t.month)}-${two(t.day)}'
        '-${two(t.hour)}${two(t.minute)}${encrypted ? '-encrypted' : ''}.zip';
  }

  Map<String, dynamic> _header() => {
        'format': format,
        'version': version,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'appVersion': appVersion,
      };

  Map<String, dynamic> toJson() => {
        ..._header(),
        'data': {
          'notes': [for (final n in notes) n.toJson()],
          'shopItems': [for (final i in shopItems) i.toJson()],
          'plannerTasks': [for (final t in plannerTasks) t.toJson()],
          'routines': routines.toJson(),
          'plannerPins': [for (final p in plannerPins) p.toJson()],
          'counters': [for (final c in counters) c.toJson()],
          'placard': placard.toJson(),
          'medicine': medicine.toJson(),
          'todo': [for (final t in todo) t.toJson()],
          if (pip != null) 'pip': pip!.toJson(),
          'recipes': [for (final r in recipes) r.toJson()],
          'ingredients': ingredients.toJson(),
          'dates': [for (final d in dates.dates) d.toJson()],
          'subscriptions': [
            for (final s in subscriptions.subscriptions) s.toJson()
          ],
          'packing': packing.toJson(),
          if (people != null) 'people': people!.toJson(),
          if (documents != null) 'documents': documents!.toJson()['documents'],
          if (documentsSealed != null)
            'documentsSealed': documentsSealed!.toJson(),
          if (masterPassword != null)
            'masterPassword': masterPassword!.toJson(),
        },
      };

  static const _indented = JsonEncoder.withIndent('  ');

  /// The file contents: indented JSON, readable in any text editor.
  String encode() => _indented.convert(toJson());

  /// The file contents of an encrypted backup, sealed with [key] (derived
  /// from the master password). Only the header stays readable.
  Future<String> encodeEncrypted(PasswordKey key) async {
    final sealed = await seal(
      utf8.encode(jsonEncode(toJson())),
      key,
      context: sealContext,
    );
    return _indented.convert({
      ..._header(),
      'encrypted': true,
      'kdf': key.params.toJson(),
      'sealed': sealed.toJson(),
    });
  }

  /// The backup file: a zip of the document ([encode], or
  /// [encodeEncrypted] with [key]) and the pictures (sealed with [key] if
  /// given).
  Future<Uint8List> zip({PasswordKey? key}) async {
    final archive = Archive()
      ..add(ArchiveFile.string(
        documentEntry,
        key == null ? encode() : await encodeEncrypted(key),
      ));
    for (final MapEntry(key: id, value: bytes) in pictures.entries) {
      final stored =
          key == null ? bytes : await DocumentFiles.sealBytes(bytes, key);
      archive.add(ArchiveFile.bytes('$picturesFolder$id', stored)
        ..compression = CompressionType.none);
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Reads a plain backup. Throws [BackupFormatException] if [source] is not
  /// a plain backup this app can read.
  static Backup decode(String source) {
    final json = _parseHeader(source);
    if (json['encrypted'] == true) {
      throw const BackupFormatException('This backup is encrypted.');
    }
    return _fromJson(json);
  }

  /// Parses [source] as JSON and checks the header (format and version).
  static Map<String, dynamic> _parseHeader(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const BackupFormatException('This file is not a backup.');
    }
    if (json is! Map<String, dynamic> || json['format'] != format) {
      throw const BackupFormatException('This file is not a backup.');
    }
    final fileVersion = json['version'];
    if (fileVersion is! int || fileVersion < 1) {
      throw const BackupFormatException('This backup is damaged.');
    }
    if (fileVersion > version) {
      throw const BackupFormatException(
        'This backup was made by a newer version of the app. '
        'Update the app to restore it.',
      );
    }
    return json;
  }

  static Backup _fromJson(Map<String, dynamic> json) {
    final Backup backup;
    try {
      final data = json['data'] as Map<String, dynamic>;
      backup = Backup(
        createdAt: DateTime.parse(json['createdAt'] as String),
        appVersion: json['appVersion'] as String,
        notes: [
          for (final n in data['notes'] as List<dynamic>)
            Note.fromJson(n as Map<String, dynamic>),
        ],
        shopItems: [
          for (final i in data['shopItems'] as List<dynamic>)
            ShopItem.fromJson(i as Map<String, dynamic>),
        ],
        plannerTasks: [
          for (final t in data['plannerTasks'] as List<dynamic>? ?? const [])
            PlannerTask.fromJson(t as Map<String, dynamic>),
        ],
        routines: data['routines'] == null
            ? RoutineBook.empty
            : RoutineBook.fromJson(data['routines'] as Map<String, dynamic>),
        plannerPins: [
          for (final p in data['plannerPins'] as List<dynamic>? ?? const [])
            PlannerPin.fromJson(p as Map<String, dynamic>),
        ],
        counters: [
          for (final c in data['counters'] as List<dynamic>? ?? const [])
            Counter.fromJson(c as Map<String, dynamic>),
        ],
        placard: data['placard'] == null
            ? Placard.initial
            : Placard.fromJson(data['placard'] as Map<String, dynamic>),
        medicine: data['medicine'] == null
            ? MedicineBook.empty
            : MedicineBook.fromJson(data['medicine'] as Map<String, dynamic>),
        todo: [
          for (final t in data['todo'] as List<dynamic>? ?? const [])
            TodoItem.fromJson(t as Map<String, dynamic>),
        ],
        pip: data['pip'] == null
            ? null
            : PipLife.fromJson(data['pip'] as Map<String, dynamic>),
        recipes: [
          for (final r in data['recipes'] as List<dynamic>? ?? const [])
            Recipe.fromJson(r as Map<String, dynamic>),
        ],
        ingredients: data['ingredients'] == null
            ? IngredientBook.empty
            : IngredientBook.fromJson(
                data['ingredients'] as Map<String, dynamic>),
        dates: DateBook.fromJson({'dates': data['dates'] ?? const []}),
        subscriptions: SubscriptionBook.fromJson(
            {'subscriptions': data['subscriptions'] ?? const []}),
        packing: data['packing'] == null
            ? null
            : PackingBook.fromJson(data['packing'] as Map<String, dynamic>),
        people: data['people'] == null
            ? null
            : PeopleBook.fromJson(data['people'] as Map<String, dynamic>),
        documents: data['documents'] == null
            ? null
            : DocumentBook.fromJson({'documents': data['documents']}),
        documentsSealed: data['documentsSealed'] == null
            ? null
            : SealedBox.fromJson(
                data['documentsSealed'] as Map<String, dynamic>),
        masterPassword: data['masterPassword'] == null
            ? null
            : PasswordVerifier.fromJson(
                data['masterPassword'] as Map<String, dynamic>,
              ),
      );
    } on Object {
      // Wrong types, missing fields, bad dates: all mean a damaged file.
      throw const BackupFormatException('This backup is damaged.');
    }
    // Ids must be unique: lists use them as keys, and duplicates would make
    // the app misbehave after restoring.
    bool unique(Iterable<String> ids) => ids.toSet().length == ids.length;
    if (!unique(backup.notes.map((n) => n.id)) ||
        !unique(backup.shopItems.map((i) => i.id)) ||
        !unique(backup.plannerTasks.map((t) => t.id)) ||
        !unique(backup.plannerPins.map((p) => p.id)) ||
        !unique(backup.counters.map((c) => c.id)) ||
        !unique(backup.todo.map((t) => t.id)) ||
        !unique(backup.recipes.map((r) => r.id)) ||
        !unique(backup.ingredients.all.map((i) => i.id)) ||
        !unique(backup.ingredients.sections.map((s) => s.id)) ||
        !unique(backup.dates.dates.map((d) => d.id)) ||
        !unique(backup.subscriptions.subscriptions.map((s) => s.id)) ||
        !unique(backup.packing.lists.map((l) => l.id)) ||
        !unique(backup.packing.sections.map((s) => s.id)) ||
        !unique((backup.people?.people ?? const []).map((p) => p.id)) ||
        !unique((backup.documents?.items ?? const []).map((d) => d.id))) {
      throw const BackupFormatException('This backup is damaged.');
    }
    return backup;
  }
}

/// A backup file as read from disk: either plain (ready to use) or encrypted
/// (needs the master password it was made with).
sealed class BackupFile {
  /// When the backup was made (readable even if encrypted).
  DateTime get createdAt;

  /// Larger documents can't be backups of this app; refused unread.
  static const maxDocumentBytes = 20 * 1024 * 1024;

  /// Whether [bytes] start as a zip does.
  static bool isZip(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  /// Reads a backup file's [bytes]: a zip (version 34 on) or the JSON
  /// document alone (older ones). Throws [BackupFormatException] if it
  /// isn't a backup this app can read.
  static BackupFile read(List<int> bytes) {
    const notABackup = BackupFormatException('This file is not a backup.');
    if (!isZip(bytes)) {
      if (bytes.length > maxDocumentBytes) throw notABackup;
      final String source;
      try {
        source = utf8.decode(bytes);
      } on FormatException {
        throw notABackup;
      }
      return parse(source);
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw notABackup;
    }
    final document = archive.findFile(Backup.documentEntry);
    if (document == null || document.size > maxDocumentBytes) {
      throw notABackup;
    }
    final pictures = <String, Uint8List>{};
    final String source;
    try {
      source = utf8.decode(document.content);
      for (final file in archive.files) {
        if (!file.isFile || !file.name.startsWith(Backup.picturesFolder)) {
          continue;
        }
        final id = file.name.substring(Backup.picturesFolder.length);
        if (!_safeId(id)) continue;
        pictures[id] = file.content;
      }
    } on Object {
      throw notABackup;
    }
    return parse(source, pictures: pictures);
  }

  /// A picture's id as a file name: no folders, nothing hidden.
  static bool _safeId(String id) =>
      id.isNotEmpty && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);

  /// Reads the JSON document [source], with the [pictures] beside it
  /// (sealed with the backup's key if it's encrypted). Throws
  /// [BackupFormatException] if it isn't a backup this app can read.
  static BackupFile parse(
    String source, {
    Map<String, Uint8List> pictures = const {},
  }) {
    final json = Backup._parseHeader(source);
    if (json['encrypted'] != true) {
      return PlainBackupFile(Backup._fromJson(json).withPictures(pictures));
    }
    try {
      return EncryptedBackupFile._(
        createdAt: DateTime.parse(json['createdAt'] as String),
        kdf: KdfParams.fromJson(json['kdf'] as Map<String, dynamic>),
        sealed: SealedBox.fromJson(json['sealed'] as Map<String, dynamic>),
        pictures: pictures,
      );
    } on Object {
      throw const BackupFormatException('This backup is damaged.');
    }
  }
}

class PlainBackupFile extends BackupFile {
  final Backup backup;

  PlainBackupFile(this.backup);

  @override
  DateTime get createdAt => backup.createdAt;
}

class EncryptedBackupFile extends BackupFile {
  @override
  final DateTime createdAt;
  final KdfParams _kdf;
  final SealedBox _sealed;

  /// The pictures, each sealed with the backup's key.
  final Map<String, Uint8List> _pictures;

  EncryptedBackupFile._({
    required this.createdAt,
    required KdfParams kdf,
    required SealedBox sealed,
    required Map<String, Uint8List> pictures,
  })  : _kdf = kdf,
        _sealed = sealed,
        _pictures = pictures;

  /// The backup inside, or null if [password] is wrong. Throws
  /// [BackupFormatException] if the decrypted contents are damaged.
  Future<Backup?> open(String password) async =>
      (await openWithKey(password))?.backup;

  /// Like [open], but also returns the key derived from [password]: it
  /// usually also opens the backup's [Backup.masterPassword] record, as the
  /// backup was encrypted with that password's key.
  Future<({Backup backup, PasswordKey key})?> openWithKey(
    String password,
  ) async {
    final key = await PasswordKey.derive(password, _kdf);
    final List<int> plain;
    try {
      plain = await crypto.open(_sealed, key, context: Backup.sealContext);
    } on DecryptionException {
      return null;
    }
    final backup = Backup.decode(utf8.decode(plain, allowMalformed: true));
    final pictures = <String, Uint8List>{};
    try {
      for (final MapEntry(key: id, value: sealed) in _pictures.entries) {
        pictures[id] = await DocumentFiles.openBytes(sealed, key);
      }
    } on DecryptionException {
      throw const BackupFormatException('This backup is damaged.');
    }
    return (backup: backup.withPictures(pictures), key: key);
  }
}
