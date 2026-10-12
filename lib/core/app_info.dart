import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app version shown to the user, e.g. "0.3.0 (3)" — from pubspec.yaml
/// via the installed package. Provided in `main()`.
final appVersionProvider = Provider<String>((ref) {
  throw UnimplementedError('appVersionProvider must be overridden');
});

/// The app version this start is (N16), for the Introduction note; null:
/// the app has no Introduction (most tests). Provided in `main()`.
final startedVersionProvider = Provider<String?>((ref) => null);
