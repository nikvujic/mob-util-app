import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/routes.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/password_prompt.dart';
import 'package:the_app/providers/fingerprint_provider.dart';

/// Getting the key for locked notes (N6, N7) from the UI.

/// The key for locked notes: from the unlocked session, or else after
/// asking for the master password (which unlocks the session, L4). Null if
/// cancelled or no master password is set.
Future<DataKey?> unlockNotesKey(
  BuildContext context,
  WidgetRef ref, {
  String? message,
}) async {
  final unlocked = ref.read(sessionProvider);
  if (unlocked != null) return unlocked.dataKey;
  if (ref.read(securityProvider) == null) return null;
  final session = ref.read(sessionProvider.notifier);
  final keys = await showPasswordPrompt<UnlockedKeys>(
    context,
    title: 'Unlock',
    message: message,
    confirmLabel: 'Unlock',
    attempt: session.unlock,
    alternative: PromptAlternative.fingerprint(
      attempt: ref.read(fingerprintProvider.notifier).unlock,
      isOffered: () => ref.read(fingerprintProvider),
    ),
  );
  return keys?.dataKey;
}

/// The key to lock notes with. Without a master password, first explains
/// why one is needed and opens its setup (setting it also unlocks), then
/// comes back here. Null if the user backs out.
Future<DataKey?> lockingKey(BuildContext context, WidgetRef ref) async {
  if (ref.read(securityProvider) == null) {
    final setUp = await showConfirmDialog(
      context,
      title: 'Set a master password?',
      message: 'Locked notes are encrypted with your master password. '
          'Set one first, then the note is locked.',
      confirmLabel: 'Set password',
    );
    if (!setUp || !context.mounted) return null;
    final messenger = ScaffoldMessenger.of(context);
    final done = await Navigator.of(context)
        .pushNamed<String>(AppRoutes.setMasterPassword);
    if (done == null || !context.mounted) return null;
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }
  return unlockNotesKey(
    context,
    ref,
    message: 'Enter the master password to lock notes.',
  );
}
