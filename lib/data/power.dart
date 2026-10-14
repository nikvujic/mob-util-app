import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the phone is plugged in (Round 44: Pip's charging station),
/// from Android: no permission needed. Charging or already full, it's
/// plugged in all the same.
abstract interface class PowerSource {
  /// Plugged in now; false if it can't be told.
  Future<bool> plugged();

  /// Plugged in or out, as it happens, while the app is open.
  Stream<bool> get changes;
}

/// [PowerSource] through the app's own Android code (MainActivity).
class AndroidPower implements PowerSource {
  const AndroidPower();

  static const _channel = MethodChannel('the_app/power');
  static const _changes = EventChannel('the_app/power_changes');

  @override
  Future<bool> plugged() async {
    try {
      return await _channel.invokeMethod<bool>('plugged') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Stream<bool> get changes => _changes
      .receiveBroadcastStream()
      .map((plugged) => plugged == true)
      .handleError((Object _) {}, test: (e) => e is MissingPluginException);
}

final powerSourceProvider = Provider<PowerSource>(
  (ref) => const AndroidPower(),
);
