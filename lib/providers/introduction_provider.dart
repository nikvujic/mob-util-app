import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/changelog.dart';
import 'package:the_app/data/bundled_text.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// Whether the app has the Introduction note at all (N16): only when
/// started from `main()` (or a test asking for it), so most tests' Notes
/// list holds only their own notes.
final introductionAvailableProvider = Provider<bool>(
  (ref) => ref.watch(startedVersionProvider) != null,
);

/// Whether the Introduction shows at the top of Notes now.
final introductionShownProvider = Provider<bool>(
  (ref) =>
      ref.watch(introductionAvailableProvider) &&
      !ref.watch(preferencesProvider.select((p) => p.introDeleted)),
);

/// The Introduction's text (N16): the guide to the app
/// (`assets/introduction.md`), then what's new in this version, from the
/// CHANGELOG.
final introductionTextProvider = FutureProvider<String>((ref) async {
  final version = versionNumber(ref.watch(appVersionProvider));
  final load = ref.watch(bundledTextProvider);
  final guide = await load('assets/introduction.md');
  final changelog = await load('CHANGELOG.md');
  final changes = changesFor(changelog, version);
  return [
    guide.trim(),
    if (changes != null) "# What's new in $version\n\n$changes",
  ].join('\n\n');
});
