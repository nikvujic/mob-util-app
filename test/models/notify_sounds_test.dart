import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/notify_settings.dart';

/// The notification sounds to pick from (Round 39: 8-bit ones).
void main() {
  final kotlin = File(
    'android/app/src/main/kotlin/com/nikvujic/the_app/MainActivity.kt',
  ).readAsStringSync();

  test('each has its file, and a preview in the picker', () {
    for (final sound in NotifySound.values) {
      final resource = sound.resource;
      if (resource == null) continue;
      expect(File('android/app/src/main/res/raw/$resource.wav').existsSync(),
          isTrue,
          reason: resource);
      expect(
          kotlin,
          contains('notifySounds["$resource"] = '
              'pool.load(this, R.raw.$resource, 1)'),
          reason: resource);
    }
  });

  test('several 8-bit ones; Chime, Bell and Soft are gone', () {
    expect(NotifySound.values.where((s) => s.resource != null).length,
        greaterThanOrEqualTo(5));
    for (final gone in ['notify_chime', 'notify_bell', 'notify_soft']) {
      expect(
          File('android/app/src/main/res/raw/$gone.wav').existsSync(), isFalse,
          reason: gone);
      expect(kotlin, isNot(contains(gone)));
    }
    expect(File('tool/make_notify_sounds.py').readAsStringSync(),
        contains('8-bit'));
  });

  test('a page set to a gone one gets the nearest new one', () {
    expect(NotifySound.fromName('chime'), NotifySound.coin);
    expect(NotifySound.fromName('bell'), NotifySound.alert);
    expect(NotifySound.fromName('soft'), NotifySound.blip);
    expect(NotifySound.fromName('zap'), NotifySound.zap);
    expect(NotifySound.fromName('who knows'), NotifySound.phone);
    expect(NotifySound.fromName(null), NotifySound.phone);
    expect(
        NotifyStyle.fromJson(const {'sound': 'bell'}).sound, NotifySound.alert);
  });
}
