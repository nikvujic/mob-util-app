import 'dart:io';
import 'dart:typed_data';

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

  group('volume (Round 41)', () {
    /// A wav file's loudest sample.
    int peakOf(String resource) {
      final bytes =
          File('android/app/src/main/res/raw/$resource.wav').readAsBytesSync();
      final data = ByteData.sublistView(bytes, 44);
      var peak = 0;
      for (var i = 0; i + 1 < data.lengthInBytes; i += 2) {
        final v = data.getInt16(i, Endian.little).abs();
        if (v > peak) peak = v;
      }
      return peak;
    }

    test('each sound at each volume, quieter as it goes', () {
      for (final sound in NotifySound.values) {
        if (sound.resource == null) {
          expect(NotifyVolume.quiet.resourceOf(sound), isNull);
          continue;
        }
        final peaks = [
          for (final v in NotifyVolume.values) peakOf(v.resourceOf(sound)!),
        ];
        expect(peaks[1], closeTo(peaks[0] / 2, peaks[0] * 0.02),
            reason: '${sound.name}: medium is half');
        expect(peaks[2], closeTo(peaks[0] / 4, peaks[0] * 0.02),
            reason: '${sound.name}: quiet is a quarter');
      }
      expect(NotifyVolume.medium.resourceOf(NotifySound.coin),
          'notify_coin_medium');
    });

    test('quieter copies are kept in release builds', () {
      expect(File('android/app/src/main/res/raw/keep.xml').readAsStringSync(),
          contains('@raw/notify_*'));
    });

    test('the preview plays at the volume picked', () {
      expect(kotlin, contains('args?.get("volume")'));
    });

    test('kept with the page\'s style; loud unless set', () {
      expect(const NotifyStyle().volume, NotifyVolume.loud);
      const quiet =
          NotifyStyle(sound: NotifySound.zap, volume: NotifyVolume.quiet);
      expect(NotifyStyle.fromJson(quiet.toJson()), quiet);
      expect(
          const NotifyStyle(sound: NotifySound.zap)
              .toJson()
              .containsKey('volume'),
          isFalse);
    });
  });
}
