import 'package:flutter/services.dart';

/// The phone's bars and which way up, kept in one place. The
/// app's own (what every page is laid out for) is the phone's bars shown,
/// any way up; a page that changes them (the Placard: sideways, no bars)
/// puts them back with [restore] as it goes, so it can't change how the
/// pages after it are laid out. (It used to leave the app drawn under
/// the navigation bar, edge to edge: People's bottom bar was squashed.)
abstract final class AppSystemUi {
  /// The app's own: the phone's bars shown, any way up.
  static Future<void> restore() async {
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
  }

  /// Upright (the Placard turning back before it closes).
  static Future<void> upright() => SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp]);

  /// Sideways, nothing but the page (the Placard).
  static Future<void> fullScreenSideways() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}
