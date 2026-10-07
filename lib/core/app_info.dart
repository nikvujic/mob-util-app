import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app version shown to the user, e.g. "0.3.0 (3)" — from pubspec.yaml
/// via the installed package. Provided in `main()`.
final appVersionProvider = Provider<String>((ref) {
  throw UnimplementedError('appVersionProvider must be overridden');
});
