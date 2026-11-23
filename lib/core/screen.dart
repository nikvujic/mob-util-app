import 'package:flutter/services.dart';

/// Keeps the screen from going dark (a recipe open while
/// cooking, the phone set aside). Android only keeps it on while the app
/// is in front, so it's off again on its own in the background.
///
/// Counted: a page holding it on that closes after another took over
/// (e.g. a duplicated recipe replacing the first) doesn't let it go dark.
abstract final class KeepScreenOn {
  static const channel = MethodChannel('the_app/screen');

  static int _holders = 0;

  /// One more page wants the screen on.
  static void hold() {
    if (++_holders == 1) _set(true);
  }

  /// One page fewer.
  static void release() {
    if (_holders == 0) return;
    if (--_holders == 0) _set(false);
  }

  static Future<void> _set(bool on) async {
    try {
      await channel.invokeMethod<void>('keepOn', on);
    } on MissingPluginException {
      // Not on a phone.
    } on PlatformException {
      // The screen going dark is no reason for an error.
    }
  }
}

/// The screen at full brightness (a barcode shown, to be scanned), and
/// back to the phone's own when it closes. Android applies it to the
/// app's window only, so leaving the app gives the phone's back too.
abstract final class FullBrightness {
  static Future<void> on() => _set(1.0);
  static Future<void> off() => _set(null);

  static Future<void> _set(double? level) async {
    try {
      await KeepScreenOn.channel.invokeMethod<void>('brightness', level);
    } on MissingPluginException {
      // Not on a phone.
    } on PlatformException {
      // Brightness is no reason for an error.
    }
  }
}
