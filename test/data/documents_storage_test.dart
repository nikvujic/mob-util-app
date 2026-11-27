import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/document_files.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/providers/documents_provider.dart';

/// The Documents page's storage (spec: storage): its items in
/// `documents.json`, its pictures one file each, written whole or not at
/// all, files nothing refers to cleaned up, pictures sealed and opened.
void main() {
  Directory temp() {
    final dir = Directory.systemTemp.createTempSync('documents');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

  final passport = DocItem(
    id: 'p',
    kind: DocKind.document,
    name: 'Passport',
    note: 'Renew in person',
    pictures: const [DocPicture('f1'), DocPicture('f2', turns: 1)],
    expires: DateTime(2031, 3, 3),
    remind: DocRemind.sixMonths,
    createdAt: DateTime(2026, 11, 23, 9),
  );
  final receipt = DocItem(
    id: 'r',
    kind: DocKind.receipt,
    name: 'Washing machine',
    pictures: const [DocPicture('f3')],
    shop: 'Tehnomanija',
    price: '449 €',
    warranty: true,
    warrantyFrom: DateTime(2026, 11, 23),
    warrantyTo: DateTime(2028, 11, 23),
    remind: DocRemind.month,
    createdAt: DateTime(2026, 11, 23, 10),
  );
  final card = DocItem(
    id: 'c',
    kind: DocKind.barcode,
    name: 'Library card',
    pictures: const [DocPicture('f4')],
    barcode: 'f5',
    createdAt: DateTime(2026, 11, 23, 11),
  );

  test('every field survives saving and reading back', () {
    final book = DocumentBook([passport, receipt, card]);
    final again = DocumentBook.fromJson(book.toJson());
    expect(again.toJson(), book.toJson());
    expect(again.items[0].pictures[1].turns, 1);
    expect(again.items[1].warrantyTo, DateTime(2028, 11, 23));
    expect(again.fileIds, {'f1', 'f2', 'f3', 'f4', 'f5'});
    expect(passport.dueDate, DateTime(2031, 3, 3));
    expect(receipt.dueDate, DateTime(2028, 11, 23));
    expect(card.dueDate, isNull);
  });

  test("a code's reading, how it's shown and where it was left survive", () {
    final qr = DocItem(
      id: 'q',
      kind: DocKind.qr,
      name: 'Gym',
      barcode: 'f9',
      scanned: const DocCode('https://gym.example/m/1', 'qr'),
      showPhoto: true,
      codeView: const CodeView(dx: 4, dy: -120, scale: 1.5),
      createdAt: DateTime(2026, 11, 23),
    );
    final again = DocItem.fromJson(qr.toJson());
    expect(again.kind, DocKind.qr);
    expect(again.scanned, qr.scanned);
    expect(again.showPhoto, isTrue);
    expect(again.codeView, qr.codeView);
    // A kind of code from a newer app is kept as it is (shown as its
    // photo here).
    final newer = DocItem.fromJson({
      ...qr.toJson(),
      'scanned': {'text': 'x', 'format': 'aztec'},
    });
    expect(newer.scanned, const DocCode('x', 'aztec'));
  });

  test('a new document with nothing in it is empty (discarded)', () {
    final blank = DocItem(
        id: 'n', kind: DocKind.receipt, createdAt: DateTime(2026, 11, 23));
    expect(blank.isEmpty, isTrue);
    expect(blank.copyWith(name: 'x').isEmpty, isFalse);
    expect(blank.copyWith(pictures: const [DocPicture('a')]).isEmpty, isFalse);
  });

  group('pictures on disk', () {
    test('written whole, read back, listed, sized, deleted', () async {
      final files = DiskDocumentFiles(Directory('${temp().path}/documents'));
      await files.write('a', [1, 2, 3]);
      await files.write('b', [4, 5]);
      expect(await files.read('a'), [1, 2, 3]);
      expect(await files.read('missing'), isNull);
      expect(await files.ids(), {'a', 'b'});
      expect(await files.totalBytes(), 5);
      await files.delete('a');
      expect(await files.ids(), {'b'});
    });

    test(
        'a write the app didn\'t finish is never listed, and dropped at a '
        'cleanup; one being written is kept', () async {
      final dir = Directory('${temp().path}/documents')..createSync();
      File('${dir.path}/half.tmp').writeAsBytesSync([9, 9]);
      File('${dir.path}/new.tmp').writeAsBytesSync([7]);
      final files = DiskDocumentFiles(dir);
      expect(await files.ids(), isEmpty);
      await files.write('new2', [8]);
      await files.keepOnly(const {}, writing: {'new', 'new2'});
      expect(File('${dir.path}/half.tmp').existsSync(), isFalse);
      expect(File('${dir.path}/new.tmp').existsSync(), isTrue,
          reason: 'still being written');
      expect(await files.ids(), {'new2'});
      await files.clear();
      expect(dir.listSync(), isEmpty);
    });

    test('files nothing refers to are cleaned up; Clear data empties',
        () async {
      final files = DiskDocumentFiles(Directory('${temp().path}/documents'));
      for (final id in ['a', 'b', 'c']) {
        await files.write(id, [1]);
      }
      await files.keepOnly({'b'});
      expect(await files.ids(), {'b'});
      await files.clear();
      expect(await files.ids(), isEmpty);
    });
  });

  group('sealed pictures', () {
    test('sealed, they\'re not the picture; opened with the key, they are',
        () async {
      final key = DataKey.generate();
      final picture = List<int>.generate(500, (i) => i % 251);
      final sealed = await DocumentFiles.sealBytes(picture, key);
      expect(DocumentFiles.isSealed(sealed), isTrue);
      expect(DocumentFiles.isSealed(picture), isFalse);
      expect(sealed, isNot(containsAllInOrder(picture.take(32))));
      expect(await DocumentFiles.openBytes(sealed, key), picture);
    });

    test('another key, or a changed byte, fails', () async {
      final key = DataKey.generate();
      final sealed = await DocumentFiles.sealBytes([1, 2, 3, 4], key);
      expect(() => DocumentFiles.openBytes(sealed, DataKey.generate()),
          throwsA(isA<DecryptionException>()));
      final changed = [...sealed]..[sealed.length - 1] ^= 1;
      expect(() => DocumentFiles.openBytes(changed, key),
          throwsA(isA<DecryptionException>()));
    });
  });

  test(
      'saved by the page, read again on opening: the documents and their '
      'pictures; unreferenced pictures go on clean-up', () async {
    final dir = temp();
    final storage = await AppStorage.open(directory: dir);
    final notifier = DocumentsNotifier(storage);
    final first = await notifier.addPicture([1, 2, 3]);
    final second = await notifier.addPicture([4, 5, 6]);
    notifier.save(passport.copyWith(pictures: [DocPicture(first)]));
    notifier.save(receipt.copyWith(pictures: [DocPicture(second)]));
    expect(notifier.state.items.map((d) => d.id), ['r', 'p'],
        reason: 'a new one goes first');
    await storage.flush();

    final again = await AppStorage.open(directory: dir);
    final reopened = DocumentsNotifier(again);
    expect(reopened.state.items.map((d) => d.name),
        ['Washing machine', 'Passport']);
    expect(await reopened.readPicture(first), [1, 2, 3]);

    reopened.delete('r');
    await reopened.cleanUp();
    expect(await again.documentFiles.ids(), {first});
  });
}
