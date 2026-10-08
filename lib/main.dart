import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:the_app/app/app.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/data/app_storage.dart';

/// Startup: load everything the app needs before the first frame, then hand
/// it to the app through provider overrides.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await AppStorage.open();
  final info = await PackageInfo.fromPlatform();
  runApp(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        appVersionProvider.overrideWithValue(
          '${info.version} (${info.buildNumber})',
        ),
      ],
      child: const MyApp(),
    ),
  );
}
