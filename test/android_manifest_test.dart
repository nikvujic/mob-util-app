import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android manifest's settings that matter to how the app behaves.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('one task: no empty taskAffinity (Round 32)', () {
    // With one, opening the app from the installer (after an update) or a
    // notification started a second task: two of it in the recent apps.
    expect(manifest, isNot(contains('android:taskAffinity=""')));
    expect(manifest, contains('android:launchMode="singleTop"'));
  });
}
