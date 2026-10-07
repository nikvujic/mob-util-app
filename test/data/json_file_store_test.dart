import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/json_file_store.dart';

void main() {
  late Directory dir;
  late JsonFileStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('json_file_store_test');
    store = JsonFileStore(File('${dir.path}/sub/data.json'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('read returns null for a missing file', () async {
    expect(await store.read(), isNull);
  });

  test('round-trips JSON and leaves no temp file behind', () async {
    await store.write({
      'a': 1,
      'b': [true, 'x']
    });
    expect(await store.read(), {
      'a': 1,
      'b': [true, 'x']
    });
    expect(File('${store.file.path}.tmp').existsSync(), isFalse);
  });

  test('rapid writes end with the latest value', () async {
    for (var i = 0; i < 20; i++) {
      store.write({'n': i});
    }
    await store.flush();
    expect(await store.read(), {'n': 19});
  });

  test('read throws on invalid JSON', () async {
    store.file
      ..createSync(recursive: true)
      ..writeAsStringSync('not json');
    expect(store.read(), throwsFormatException);
  });
}
