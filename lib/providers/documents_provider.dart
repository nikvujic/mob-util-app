import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/document_files.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/session_provider.dart';

/// How far turning the lock on or off has come: pictures done, of all.
typedef SealProgress = ({int done, int all});

/// The Documents page (spec `docs/DOCUMENTS_SPEC.md`), saved to
/// `documents.json`, its pictures in [DocumentFiles]. A document is saved
/// as it's edited (upserted); a new one goes first. Their order is the
/// user's, set by dragging.
///
/// **Locked** (spec: locking and encryption), the page is encrypted with
/// the master password's data key: `documents.json` holds the list sealed
/// (`sealed`) and a small index without names for the reminders and
/// counts (`index`); every picture is sealed. While the app is locked the
/// list isn't open ([isOpen] false, the state empty and never saved).
/// Turning the lock on or off seals or opens everything once
/// ([reconcile]); each file is replaced whole, and a run cut short is
/// finished the next time the key is there (every picture says whether
/// it's sealed, so a mix reads fine meanwhile).
class DocumentsNotifier extends StateNotifier<DocumentBook> {
  final AppStorage _storage;

  /// Authenticated with the sealed list, so nothing else sealed with the
  /// data key passes for it.
  static const sealContext = 'the-app/documents';

  DocumentsNotifier(this._storage) : super(DocumentBook.empty) {
    final json = _storage.initialDocuments;
    if (json?['sealed'] case final Map<String, dynamic> sealed) {
      _encrypted = true;
      _sealed = SealedBox.fromJson(sealed);
      _index = DocumentIndex.fromJson(json?['index']);
    } else if (json != null && json['documents'] != null) {
      _quiet = true;
      state = DocumentBook.fromJson(json);
      _quiet = false;
    }
    addListener(_save, fireImmediately: false);
  }

  /// Encrypted on disk (the list sealed).
  bool get encrypted => _encrypted;
  bool _encrypted = false;

  /// The data key, while the list is open and encrypted.
  DataKey? _key;

  /// The list as last sealed, to open next time.
  SealedBox? _sealed;

  /// The index (no names) while the list isn't open.
  DocumentIndex _index = DocumentIndex.empty;

  /// Whether the documents can be seen and changed now: not encrypted, or
  /// opened with the key.
  bool get isOpen => !_encrypted || _key != null;

  /// The lock on or off, as wanted (the page lock), and the key while
  /// the app is unlocked: [reconcile] follows them.
  bool _wantLocked = false;
  DataKey? _sessionKey;

  /// Told the progress while sealing or opening every picture; null
  /// when done.
  void Function(SealProgress?) onProgress = (_) {};

  Future<void>? _reconciling;
  bool _again = false;

  /// Saves, one after another (sealing takes a moment).
  Future<void> _saving = Future.value();
  bool _quiet = false;

  DocumentFiles get files => _storage.documentFiles;

  /// The list as it is, with the key at this moment (an edit just
  /// before the app locks is sealed with the key it was made under).
  void _save(DocumentBook book) {
    if (_quiet || !isOpen) return;
    final encrypted = _encrypted, key = _key;
    _saving = _saving.then((_) => _write(book, encrypted, key));
  }

  Future<void> _write(DocumentBook book, bool encrypted, DataKey? key) async {
    if (!encrypted) {
      _storage.saveDocuments(book.toJson());
      return;
    }
    if (key == null) return;
    final sealed = await seal(
      utf8.encode(jsonEncode(book.toJson())),
      key,
      context: sealContext,
    );
    _sealed = sealed;
    _storage.saveDocuments({
      'sealed': sealed.toJson(),
      'index': DocumentIndex.of(book).toJson(),
    });
  }

  /// Waits until what's been changed is written (to the store; its file
  /// with the store's next flush).
  Future<void> get saved => _saving;

  /// The documents for reminders: the open list, or (locked) the index's
  /// dates, without names.
  DocumentBook get forReminders => isOpen ? state : _index.book;

  /// How many there are, open or not.
  int get count => isOpen ? state.size : _index.count;

  // ---- Locking (spec: locking and encryption) ----

  /// The page lock wanted on or off; [key] the session's data key (null
  /// while the app is locked). Opens or closes the list, and seals or
  /// opens everything as needed.
  void follow({required bool locked, required DataKey? key}) {
    _wantLocked = locked;
    _sessionKey = key;
    if (key == null) {
      _close();
      return;
    }
    if (_encrypted && _key == null) {
      unawaited(_open(key));
    } else {
      unawaited(reconcile());
    }
  }

  /// The list opened with [key] (asynchronously: it shows once read);
  /// stays sealed if it doesn't open (another password's key).
  Future<void> _open(DataKey key) async {
    await _saving;
    final sealed = _sealed;
    if (sealed == null || _key != null) return;
    final List<int> plain;
    try {
      plain = await open(sealed, key, context: sealContext);
    } on DecryptionException {
      return;
    }
    if (_sessionKey != key || !_encrypted || _key != null) return;
    _key = key;
    _quiet = true;
    state = DocumentBook.fromJson(
        jsonDecode(utf8.decode(plain)) as Map<String, dynamic>);
    _quiet = false;
    await cleanUp();
    await reconcile();
  }

  /// The app locked: the list (and its key) dropped from memory.
  void _close() {
    if (!_encrypted || _key == null) return;
    _index = DocumentIndex.of(state);
    _key = null;
    _quiet = true;
    state = DocumentBook.empty;
    _quiet = false;
  }

  /// Seals (the lock on) or opens (off) the list and every picture, with
  /// the session's key, until everything is as wanted. The list goes
  /// first when locking (its names protected at once), last when
  /// unlocking. Nothing while the app is locked.
  Future<void> reconcile() {
    if (_reconciling != null) {
      _again = true;
      return _reconciling!;
    }
    return _reconciling = () async {
      try {
        do {
          _again = false;
          await _reconcileOnce();
        } while (_again);
      } finally {
        _reconciling = null;
        onProgress(null);
      }
    }();
  }

  Future<void> _reconcileOnce() async {
    final key = _sessionKey;
    if (key == null) return;
    final lock = _wantLocked;
    if (lock && !_encrypted) {
      _encrypted = true;
      _key = key;
      _save(state);
      await _saving;
    }
    if (_encrypted && _key == null) return; // not open (or not ours)
    final ids = await files.ids();
    var done = 0;
    for (final id in ids) {
      if (_sessionKey != key || _wantLocked != lock) {
        _again = true;
        return;
      }
      final bytes = await files.read(id);
      if (bytes != null) {
        final sealed = DocumentFiles.isSealed(bytes);
        if (lock && !sealed) {
          await files.write(id, await DocumentFiles.sealBytes(bytes, key));
        } else if (!lock && sealed) {
          try {
            await files.write(id, await DocumentFiles.openBytes(bytes, key));
          } on DecryptionException {
            // Not this key's: it stays as it is.
          }
        }
      }
      done++;
      if (ids.length > 1) onProgress((done: done, all: ids.length));
    }
    if (!lock && _encrypted) {
      _encrypted = false;
      _key = null;
      _sealed = null;
      _save(state);
      await _saving;
    }
  }

  /// Opens everything with [key] before the master password goes (as
  /// locked notes are). Throws [DecryptionException] if it doesn't open.
  Future<void> openAll(DataKey key) async {
    if (!_encrypted) return;
    await _saving;
    if (_key == null) {
      final sealed = _sealed;
      if (sealed == null) throw const DecryptionException();
      final plain = await open(sealed, key, context: sealContext);
      _quiet = true;
      state = DocumentBook.fromJson(
          jsonDecode(utf8.decode(plain)) as Map<String, dynamic>);
      _quiet = false;
      _key = key;
    }
    _wantLocked = false;
    _sessionKey = key;
    await reconcile();
    if (_reconciling != null) await _reconciling;
  }

  /// The data key the list is open with, if encrypted and open.
  DataKey? get openKey => _key;

  /// The list sealed as it is now, for a backup (null if not encrypted
  /// or not open).
  Future<SealedBox?> sealedForBackup() async {
    final key = _key;
    if (!_encrypted || key == null) return null;
    return seal(utf8.encode(jsonEncode(state.toJson())), key,
        context: sealContext);
  }

  // ---- Editing ----

  /// [item] as it is now: added (first) if new, else replaced.
  void save(DocItem item) {
    final known = state.byId(item.id) != null;
    state = DocumentBook([
      if (!known) item,
      for (final d in state.items)
        if (d.id == item.id) item else d,
    ]);
  }

  /// Deletes [id]; returns the book before, for Undo. Its pictures stay
  /// until [cleanUp] (after Undo has gone).
  DocumentBook delete(String id) {
    final before = state;
    state = DocumentBook([
      for (final d in state.items)
        if (d.id != id) d,
    ]);
    return before;
  }

  /// [id] moved to [to]'s place, the others shifting.
  void moveTo(String id, int to) {
    final list = [...state.items];
    final from = list.indexWhere((d) => d.id == id);
    if (from == -1 || to < 0 || to >= list.length || from == to) return;
    list.insert(to, list.removeAt(from));
    state = DocumentBook(list);
  }

  /// The handle's move, as the list reports it ([newIndex] counted
  /// before the row leaves its place).
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final list = [...state.items];
    list.insert(newIndex, list.removeAt(oldIndex));
    state = DocumentBook(list);
  }

  /// Every document replaced (a restore, Undo). Not while the list isn't
  /// open: it would be lost.
  void replaceAll(DocumentBook book) {
    if (!isOpen) return;
    state = book;
  }

  /// Stores a picture's [bytes] and returns its id.
  Future<String> addPicture(List<int> bytes) async {
    final id = generateId();
    await storePicture(id, bytes);
    return id;
  }

  /// Stores [bytes] as picture [id]: sealed while encrypted.
  Future<void> storePicture(String id, List<int> bytes) async {
    final key = _key;
    await files.write(
      id,
      _encrypted && key != null && !DocumentFiles.isSealed(bytes)
          ? await DocumentFiles.sealBytes(bytes, key)
          : bytes,
    );
  }

  /// A picture's bytes, ready to show; null if it's missing, or sealed
  /// while the list isn't open.
  Future<Uint8List?> readPicture(String id) async {
    final bytes = await files.read(id);
    if (bytes == null || !DocumentFiles.isSealed(bytes)) return bytes;
    final key = _key ?? _sessionKey;
    if (key == null) return null;
    try {
      return await DocumentFiles.openBytes(bytes, key);
    } on DecryptionException {
      return null;
    }
  }

  /// A picture's bytes as stored (sealed while encrypted), for a backup.
  Future<Uint8List?> storedPicture(String id) => files.read(id);

  /// Deletes pictures no document refers to (a document deleted and its
  /// Undo gone, a picture taken out, a crash mid-way). Never while
  /// `documents.json` couldn't be read, nor while the list isn't open:
  /// their pictures are kept for them.
  Future<void> cleanUp() async {
    if (!_storage.documentsReadable || !isOpen) return;
    await files.keepOnly(state.fileIds);
  }

  /// Deletes every document and picture (Clear data, a password reset):
  /// not encrypted, and empty, after.
  Future<void> clearAll() async {
    _encrypted = false;
    _key = null;
    _sealed = null;
    _index = DocumentIndex.empty;
    state = DocumentBook.empty;
    await files.clear();
    // Locked still (Clear data): sealed again, empty.
    if (_wantLocked) await reconcile();
  }
}

/// What a locked `documents.json` keeps readable: how many documents, and
/// each one's date and reminder, without names.
class DocumentIndex {
  final int count;
  final List<DocItem> dates;

  const DocumentIndex(this.count, this.dates);

  static const empty = DocumentIndex(0, []);

  static DocItem _dated(DocKind kind, DateTime due, DocRemind remind) =>
      DocItem(
        id: '',
        kind: kind,
        expires: kind == DocKind.document ? due : null,
        warranty: kind == DocKind.receipt,
        warrantyTo: kind == DocKind.receipt ? due : null,
        date: kind == DocKind.ticket ? due : null,
        remind: remind,
        createdAt: DateTime(2000),
      );

  factory DocumentIndex.of(DocumentBook book) => DocumentIndex(book.size, [
        for (final d in book.items)
          if (d.dueDate case final due?
              when d.remind != DocRemind.none && d.kind != DocKind.barcode)
            _dated(d.kind, due, d.remind),
      ]);

  DocumentBook get book => DocumentBook(dates);

  Map<String, dynamic> toJson() => {
        'count': count,
        'dates': [
          for (final d in dates)
            {
              'kind': d.kind.name,
              'due': PlannerTask.dayToJson(d.dueDate!),
              'remind': d.remind.name,
            },
        ],
      };

  factory DocumentIndex.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return empty;
    final dates = <DocItem>[];
    for (final e in json['dates'] as List<dynamic>? ?? const []) {
      if (e is! Map<String, dynamic> || e['due'] == null) continue;
      dates.add(_dated(
        DocKind.fromId(e['kind'] as String?),
        PlannerTask.dayFromJson(e['due']),
        DocRemind.fromId(e['remind'] as String?),
      ));
    }
    return DocumentIndex(
        (json['count'] as num?)?.toInt() ?? dates.length, dates);
  }
}

/// A picture's bytes, read once while shown; null if it's missing.
final documentPictureProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>(
  (ref, id) => ref.watch(documentsProvider.notifier).readPicture(id),
);

final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, DocumentBook>((ref) {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final notifier = DocumentsNotifier(ref.watch(appStorageProvider))
    // Work still running once the app's state is gone tells no one.
    ..onProgress = (p) {
      if (!disposed) ref.read(documentsProgressProvider.notifier).state = p;
    };
  // The lock and the session: the page sealed or opened to match.
  void follow() => notifier.follow(
        locked: ref.read(pageLocksProvider).contains(HubTool.documents),
        key: ref.read(sessionProvider)?.dataKey,
      );
  ref.listen(pageLocksProvider, (_, __) => follow());
  ref.listen(sessionProvider, (_, __) => follow());
  follow();
  return notifier;
});

/// Progress while the Documents lock seals or opens its pictures.
final documentsProgressProvider = StateProvider<SealProgress?>((ref) => null);
