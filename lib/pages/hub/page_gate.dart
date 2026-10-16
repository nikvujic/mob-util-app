import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/providers/fingerprint_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/locked_screen.dart';
import 'package:the_app/widgets/password_prompt.dart';

/// Shows [child] (one of the Hub's pages), or a lock screen while the page
/// is closed (O7): locked, with the app locked. Like a section's gate, the
/// page isn't built meanwhile; unlocked, it opens in place.
class PageGate extends ConsumerWidget {
  final HubTool page;
  final Widget child;

  const PageGate({super.key, required this.page, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(pageClosedProvider(page))) return child;
    return LockedScreen(
      title: page.label,
      askAtOnce: true,
      appBar: AppBar(title: Text(page.label)),
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
