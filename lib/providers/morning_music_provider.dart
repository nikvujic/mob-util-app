import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/morning_music_alarm.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// Keeps the phone's Spotify alarm (Round 93) as set on its page: set
/// when the app starts (in case Android lost it), and again on every
/// change.
final morningMusicSyncProvider = Provider<void>((ref) {
  final alarm = ref.watch(morningMusicAlarmProvider);
  ref.listen(
    preferencesProvider.select((p) => p.morningMusic),
    (_, music) => alarm.set(music),
    fireImmediately: true,
  );
});
