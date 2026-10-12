import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads a text file bundled with the app (e.g. the Introduction, N16).
/// Decoded here: `loadString` hands bigger files (the CHANGELOG) to
/// another isolate, which is slower to start than the decoding itself.
final bundledTextProvider = Provider<Future<String> Function(String path)>(
  (ref) => (path) async {
    final data = await rootBundle.load(path);
    return utf8.decode(data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    ));
  },
);
