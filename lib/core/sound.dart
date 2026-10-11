import 'package:flutter/services.dart';

/// Short sounds the app plays itself (not Android's touch sounds, which
/// are often switched off).
abstract final class AppSound {
  static const _channel = MethodChannel('the_app/sound');

  /// A short click (the counters, U6). Silent where there's no player
  /// (e.g. tests).
  static Future<void> click() async {
    try {
      await _channel.invokeMethod<void>('click');
    } on MissingPluginException {
      // Not on a phone.
    } on PlatformException {
      // No sound is better than an error.
    }
  }
}
