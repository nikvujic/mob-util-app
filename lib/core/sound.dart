import 'package:flutter/services.dart';

/// Short sounds the app plays itself (not Android's touch sounds, which
/// are often switched off).
abstract final class AppSound {
  static const _channel = MethodChannel('the_app/sound');

  /// A short click (the counters, U6). Silent where there's no player
  /// (e.g. tests).
  static Future<void> click() => _play('click');

  /// Plays the click silently, so the audio is awake for the first real
  /// one (Round 18: the first tap's click lagged its buzz).
  static Future<void> warm() => _play('warm');

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

  /// The Placard filling up (Round 17): a rising sound as long as a
  /// hold; [stopInflate] stops it when the finger lifts early.
  static Future<void> inflate() => _play('inflate');
  static Future<void> stopInflate() => _play('stopInflate');

  /// The Placard popping.
  static Future<void> pop() => _play('pop');

  /// An important medicine's hold-to-take (Round 24): a glass filling up,
  /// as long as the hold; [stopFill] stops it when the finger lifts early.
  static Future<void> fill() => _play('fill');
  static Future<void> stopFill() => _play('stopFill');

  /// Pip's fanfare (Round 63): he's registered as an adventurer. On the
  /// media volume (muted: silent).
  static Future<void> fanfare() => _play('fanfare');

  /// A notification sound (Round 31), heard when picking one: its raw
  /// resource's name, e.g. `notify_coin`, at [volume] (Round 41: 0 to 1).
  static Future<void> notify(String resource, {double volume = 1}) =>
      _play('notify', {'sound': resource, 'volume': volume});

  static Future<void> _play(String sound, [Object? argument]) async {
    try {
      await _channel.invokeMethod<void>(sound, argument);
    } on MissingPluginException {
      // Not on a phone.
    } on PlatformException {
      // No sound is better than an error.
    }
  }
}
