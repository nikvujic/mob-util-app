import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/locked_screen.dart';
import 'package:the_app/widgets/main_app_bar.dart';
import 'package:the_app/widgets/password_prompt.dart';
import 'package:the_app/providers/fingerprint_provider.dart';

/// Shows [child] (a main section), or a lock screen while the section is
/// closed (L5): locked, with the app locked. The section's page isn't
/// built at all meanwhile, so nothing of it is on screen.
class SectionGate extends ConsumerWidget {
  final AppSection section;
  final Widget child;

  const SectionGate({super.key, required this.section, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(sectionClosedProvider(section))) return child;
    return LockedScreen(
      title: section.label,
      appBar: MainAppBar(title: section.label),
      onUnlock: () => showPasswordPrompt<UnlockedKeys>(
        context,
        title: 'Unlock',
        confirmLabel: 'Unlock',
        attempt: ref.read(sessionProvider.notifier).unlock,
        alternative: PromptAlternative.fingerprint(
          attempt: ref.read(fingerprintProvider.notifier).unlock,
          isOffered: () => ref.read(fingerprintProvider),
        ),
      ),
    );
  }
}
