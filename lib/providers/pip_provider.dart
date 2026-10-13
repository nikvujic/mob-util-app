import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/providers/pip_life_provider.dart';

/// Pip (Round 26): one for the app's run, so he comes out of the ground
/// only the first time the menu opens, and is where he was the next. An
/// egg until he's hatched (Round 34).
final pipBrainProvider = Provider<PipBrain>(
  (ref) => PipBrain(hatched: ref.read(pipLifeProvider).hatched),
);

/// Whether Pip moves (off in tests, where an endless animation would
/// never settle; his own tests turn it on).
final pipAnimatesProvider = Provider<bool>((ref) => true);
