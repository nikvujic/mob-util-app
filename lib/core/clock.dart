import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time. Overridden in tests so time-based behaviour (e.g.
/// auto-lock after 5 minutes) can be tested without waiting.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
