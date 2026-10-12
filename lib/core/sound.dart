import 'package:flutter/services.dart';

/// Short sounds the app plays itself (not Android's touch sounds, which
/// are often switched off).
abstract final class AppSound {
  static const _channel = MethodChannel('the_app/sound');

  /// A short click (the counters, U6). Silent where there's no player
  /// (e.g. tests).
  static Future<void> click() => _play('click');

  /// A soft gulp: something done (a dose taken, Round 16).
  static Future<void> done() => _play('done');

  /// The gulp's feel (Round 17): two soft pulses, with its two bloops.
  static Future<void> doneBuzz() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(gulpGap);
    await HapticFeedback.lightImpact();
  }

  /// Between the gulp's two bloops (see tool/make_done_sound.py).
  static const gulpGap = Duration(milliseconds: 110);

  static Future<void> _play(String sound) async {
    try {
      await _channel.invokeMethod<void>(sound);
    } on MissingPluginException {
      // Not on a phone.
    } on PlatformException {
      // No sound is better than an error.
    }
  }
}
