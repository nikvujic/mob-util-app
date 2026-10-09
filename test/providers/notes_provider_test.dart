import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/providers/notes_provider.dart';

void main() {
  late NotesNotifier notifier;

  setUp(() => notifier = NotesNotifier(AppStorage.inMemory()));

  List<String> titles() => notifier.state.map((n) => n.title).toList();

  test('new notes are added to the top', () {
    notifier.addNote(title: 'A');
    notifier.addNote(title: 'B');
    expect(titles(), ['B', 'A']);
  });

  test('reorder follows ReorderableListView index semantics', () {
    notifier
      ..addNote(title: 'C')
      ..addNote(title: 'B')
      ..addNote(title: 'A');

    notifier.reorder(0, 3); // drag A below C
    expect(titles(), ['B', 'C', 'A']);

    notifier.reorder(2, 0); // drag A back to top
    expect(titles(), ['A', 'B', 'C']);
  });

  test('updateNote changes fields and bumps modifiedAt only on change', () {
    final id = notifier.addNote(title: 'A');
    final before = notifier.state.single;

    notifier.updateNote(id, title: 'A', content: '');
    expect(identical(notifier.state.single, before), isTrue);

    notifier.updateNote(id, title: 'Renamed');
    expect(notifier.state.single.title, 'Renamed');
    expect(
      notifier.state.single.modifiedAt.isBefore(before.modifiedAt),
      isFalse,
    );
  });

  test('removeNotes deletes only the given ids', () {
    final a = notifier.addNote(title: 'A');
    notifier.addNote(title: 'B');
    final c = notifier.addNote(title: 'C');

    notifier.removeNotes({a, c});
    expect(titles(), ['B']);
  });

  test('restoreNote puts back an exact earlier version', () {
    final id = notifier.addNote(title: 'A', content: 'original');
    final snapshot = notifier.state.single;

    notifier.updateNote(id, title: 'B', content: 'edited');
    notifier.restoreNote(snapshot);

    expect(identical(notifier.state.single, snapshot), isTrue);
  });

  group('locked notes', () {
    final key = DataKey.fromBytes(List.filled(32, 7));
    final otherKey = DataKey.fromBytes(List.filled(32, 8));

    Future<String> lockedNote({String content = 'secret'}) async {
      final id = notifier.addNote(title: 'Bank', content: content);
      await notifier.lockNote(id, key);
      return id;
    }

    test('locking keeps the title but drops the plain content', () async {
      final id = await lockedNote();
      final before = notifier.state.single;

      final note = notifier.state.single;
      expect(note.isLocked, isTrue);
      expect(note.title, 'Bank');
      expect(note.content, isEmpty);
      expect(note.toJson().toString(), isNot(contains('secret')));
      expect(await notifier.readContent(note, key), 'secret');

      // Locking again changes nothing.
      await notifier.lockNote(id, key);
      expect(identical(notifier.state.single, before), isTrue);
    });

    test('unlocking puts the content back in the clear', () async {
      final id = await lockedNote(content: 'čaj 🥙');
      final modified = notifier.state.single.modifiedAt;

      await notifier.unlockNote(id, key);

      final note = notifier.state.single;
      expect(note.isLocked, isFalse);
      expect(note.content, 'čaj 🥙');
      expect(note.modifiedAt, modified, reason: 'locking is not an edit');
    });

    test('the wrong key opens nothing and changes nothing', () async {
      final id = await lockedNote();
      final before = notifier.state.single;

      await expectLater(
        notifier.readContent(before, otherKey),
        throwsA(isA<DecryptionException>()),
      );
      await expectLater(
        notifier.unlockNote(id, otherKey),
        throwsA(isA<DecryptionException>()),
      );
      expect(identical(notifier.state.single, before), isTrue);
    });

    test("sealed content can't be moved to another note", () async {
      final id = await lockedNote();
      final other = notifier.addNote(title: 'Other');
      await notifier.lockNote(other, key);
      final moved = notifier.state
          .firstWhere((n) => n.id == other)
          .locked(notifier.state.firstWhere((n) => n.id == id).lockedContent!);

      await expectLater(
        notifier.readContent(moved, key),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('damaged sealed content reads as a decryption failure', () async {
      await lockedNote();
      final damaged = notifier.state.single.locked({'cipher': 'other'});
      await expectLater(
        notifier.readContent(damaged, key),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('content of a locked note only changes encrypted', () async {
      final id = await lockedNote();
      expect(
        () => notifier.updateNote(id, content: 'plain'),
        throwsStateError,
      );
      // The title stays plain text, so it can change directly.
      notifier.updateNote(id, title: 'Bank 2');
      expect(notifier.state.single.title, 'Bank 2');

      await notifier.updateLockedNote(id, content: 'new secret', key: key);
      final note = notifier.state.single;
      expect(note.content, isEmpty);
      expect(await notifier.readContent(note, key), 'new secret');
    });

    test('updateLockedNote changes nothing unless something differs', () async {
      final id = await lockedNote();
      final before = notifier.state.single;

      await notifier.updateLockedNote(
        id,
        title: 'Bank',
        content: 'secret',
        key: key,
      );
      expect(identical(notifier.state.single, before), isTrue);

      await notifier.updateLockedNote(id, title: 'Renamed', key: key);
      final renamed = notifier.state.single;
      expect(renamed.title, 'Renamed');
      expect(renamed.lockedContent, same(before.lockedContent));
    });

    test('the saved file never contains the locked content', () async {
      final dir = Directory.systemTemp.createTempSync('locked_notes');
      addTearDown(() => dir.deleteSync(recursive: true));
      final storage = await AppStorage.open(directory: dir);
      notifier = NotesNotifier(storage);

      final id = await lockedNote(content: 'PIN 4711');
      await notifier.updateLockedNote(id, content: 'PIN 9876', key: key);
      await storage.flush();

      final file = File('${dir.path}/notes.json').readAsStringSync();
      expect(file, contains('lockedContent'));
      expect(file, isNot(contains('4711')));
      expect(file, isNot(contains('9876')));

      // And it loads back, still locked and readable with the key.
      final reloaded = (await AppStorage.open(directory: dir)).initialNotes;
      expect(reloaded.single.isLocked, isTrue);
      expect(await notifier.readContent(reloaded.single, key), 'PIN 9876');
    });

    test('encrypted updates land in the order they were made', () async {
      final id = await lockedNote();
      final first = notifier.updateLockedNote(id, content: 'one', key: key);
      final second = notifier.updateLockedNote(id, content: 'two', key: key);
      await Future.wait([first, second]);
      expect(await notifier.readContent(notifier.state.single, key), 'two');
    });

    test('an encrypted update never undoes a restore made meanwhile', () async {
      final id = await lockedNote();
      final original = notifier.state.single;

      final update = notifier.updateLockedNote(id, content: 'edit', key: key);
      notifier.restoreNote(original); // e.g. Discard while sealing
      await update;

      expect(identical(notifier.state.single, original), isTrue);
    });

    test('a failed unlock does not block later changes', () async {
      final id = await lockedNote();
      await expectLater(
        notifier.unlockNote(id, otherKey),
        throwsA(isA<DecryptionException>()),
      );
      await notifier.unlockNote(id, key);
      expect(notifier.state.single.content, 'secret');
    });

    test('unlockAll unlocks every locked note in one change', () async {
      final a = await lockedNote(content: 'one');
      final b = notifier.addNote(title: 'B', content: 'two');
      await notifier.lockNote(b, key);
      notifier.addNote(title: 'Plain', content: 'three');
      var changes = 0;
      notifier.addListener((_) => changes++, fireImmediately: false);

      await notifier.unlockAll(key);

      expect(changes, 1);
      expect(notifier.state.any((n) => n.isLocked), isFalse);
      expect(
        notifier.state.map((n) => n.content),
        containsAll(['one', 'two', 'three']),
      );
      expect(notifier.state.firstWhere((n) => n.id == a).title, 'Bank');
    });

    test('unlockAll changes nothing if one note does not open', () async {
      await lockedNote();
      final other = notifier.addNote(title: 'Other', content: 'x');
      await notifier.lockNote(other, otherKey);
      final before = notifier.state;

      await expectLater(
        notifier.unlockAll(key),
        throwsA(isA<DecryptionException>()),
      );
      expect(identical(notifier.state, before), isTrue);
    });
  });
}
