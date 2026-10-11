import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';

/// The data files that couldn't be read at startup and were set aside, so
/// the app started without them (e.g. `notes.json`); empty normally.
final unreadableFilesProvider = Provider<List<String>>(
  (ref) => ref.watch(appStorageProvider).unreadable,
);
