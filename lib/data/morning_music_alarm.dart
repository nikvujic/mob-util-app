import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/models/morning_music.dart';

/// Spotify in the morning (Round 93) on the phone: the alarm that, at the
/// set time, sets the music volume and presses play. Android keeps it
/// (and sets the next one each time it plays, and after a restart), so it
/// plays with the app closed.
abstract interface class MorningMusicAlarm {
  /// Sets it to [music] (off: none).
  Future<void> set(MorningMusic music);
}

/// [MorningMusicAlarm] through the app's own Android code (MainActivity,
/// MorningMusic.kt).
class AndroidMorningMusicAlarm implements MorningMusicAlarm {
  const AndroidMorningMusicAlarm();

  static const _channel = MethodChannel('the_app/morning_music');

  @override
  Future<void> set(MorningMusic music) async {
    try {
      await _channel.invokeMethod<void>('set', {
        'on': music.on,
        'minutes': music.minutes,
        'weekdays': [...music.weekdays]..sort(),
        'volume': music.volume,
      });
    } on PlatformException {
      // Nothing more to do: it shows as set; it just won't play.
    } on MissingPluginException {
      // Not on Android (tests).
    }
  }
}

final morningMusicAlarmProvider = Provider<MorningMusicAlarm>(
  (ref) => const AndroidMorningMusicAlarm(),
);
