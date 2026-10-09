import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/shop_provider.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('app_storage_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('starts empty when nothing has been saved', () async {
    final storage = await AppStorage.open(directory: dir);
    expect(storage.initialNotes, isEmpty);
    expect(storage.initialShopItems, isEmpty);
  });

  test('notes and shop items survive a restart, including order', () async {
    final storage = await AppStorage.open(directory: dir);
    final notes = NotesNotifier(storage);
    final shop = ShopNotifier(storage);

    final id = notes.addNote(title: 'First', content: 'Body\nwith lines');
    notes.addNote(title: 'Second');
    notes.reorder(0, 2); // Second below First
    notes.updateNote(id, content: 'Edited');

    shop
      ..addItem('Milk')
      ..addItem('Eggs')
      ..addItem('Bread');
    shop.toggle(shop.state.firstWhere((i) => i.name == 'Eggs').id);
    await storage.flush();

    final reopened = await AppStorage.open(directory: dir);
    expect(reopened.initialNotes.map((n) => n.title), ['First', 'Second']);
    final first = reopened.initialNotes.first;
    expect(first.content, 'Edited');
    expect(first.modifiedAt, notes.state.first.modifiedAt);
    expect(first.createdAt, notes.state.first.createdAt);

    expect(
      reopened.initialShopItems.map((i) => '${i.name}:${i.toBuy}'),
      ['Eggs:false', 'Milk:true', 'Bread:true'],
    );
  });

  test('deletions are saved', () async {
    final storage = await AppStorage.open(directory: dir);
    final notes = NotesNotifier(storage);
    final id = notes.addNote(title: 'Gone');
    notes.removeNotes({id});
    await storage.flush();

    final reopened = await AppStorage.open(directory: dir);
    expect(reopened.initialNotes, isEmpty);
  });

  test('an unreadable file is kept aside, not overwritten', () async {
    final file = File('${dir.path}/notes.json')..writeAsStringSync('{broken');

    final storage = await AppStorage.open(directory: dir);
    expect(storage.initialNotes, isEmpty);
    expect(file.existsSync(), isFalse);

    final backups = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('notes.json.corrupt-'))
        .toList();
    expect(backups, hasLength(1));
    expect(backups.single.readAsStringSync(), '{broken');
  });
}
