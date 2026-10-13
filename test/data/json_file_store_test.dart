import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/storage_error.dart';
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

  test('a failed write is reported by flush, until one succeeds', () async {
    await store.write({'n': 1});
    // A folder where the temporary file goes: writing fails.
    final blocker = Directory('${store.file.path}.tmp')..createSync();

    await store.write({'n': 2}); // doesn't throw: the app keeps running
    await expectLater(store.flush(), throwsA(isA<StorageWriteException>()));
    expect(await store.read(), {'n': 1}, reason: 'the old version stays');

    blocker.deleteSync();
    await store.write({'n': 3});
    await store.flush();
    expect(await store.read(), {'n': 3});
  });

  test('a failed write is retried once it can be (D6, Round 23)', () async {
    await store.write({'n': 1});
    final blocker = Directory('${store.file.path}.tmp')..createSync();
    await store.write({'n': 2});
    expect(store.failing.value, isTrue);

    await store.retry(); // still blocked: still failing, nothing lost
    expect(store.failing.value, isTrue);

    blocker.deleteSync(); // space was freed
    await store.retry();
    expect(store.failing.value, isFalse);
    expect(await store.read(), {'n': 2}, reason: 'what failed is saved');
    await store.retry(); // nothing to do
    expect(await store.read(), {'n': 2});
  });

  test('a retry never writes the failed version over a newer one (Round 24)',
      () async {
    final blocker = Directory('${store.file.path}.tmp')
      ..createSync(recursive: true);
    await store.write({'n': 1}); // fails
    expect(store.failing.value, isTrue);
    blocker.deleteSync();

    final newer = store.write({'n': 2}); // on its way
    await store.retry(); // e.g. the app came back meanwhile
    await newer;
    await store.flush();
    expect(await store.read(), {'n': 2});
    expect(store.failing.value, isFalse);
  });
}
