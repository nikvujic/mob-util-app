import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/security/password_form.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/password_prompt.dart';

/// Master password (L1) and section locks (L5, coming later).
class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  Future<void> _open(BuildContext context, PasswordFormMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => PasswordFormPage(mode: mode)),
    );
    if (done != null) {
      messenger.showSnackBar(SnackBar(content: Text(done)));
    }
  }

  Future<void> _unlock(BuildContext context, WidgetRef ref) async {
    final verifier = ref.read(securityProvider);
    if (verifier == null) return;
    final key = await showPasswordPrompt<PasswordKey>(
      context,
      title: 'Unlock',
      confirmLabel: 'Unlock',
      attempt: verifier.unlock,
    );
    if (key != null) ref.read(sessionProvider.notifier).unlockWith(key);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPassword = ref.watch(securityProvider) != null;
    final unlocked = ref.watch(sessionProvider) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        children: [
          if (!hasPassword)
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Set master password'),
              subtitle: const Text(
                'Protects locked notes and encrypted backups',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () => _open(context, PasswordFormMode.set),
            )
          else ...[
            const ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('Master password'),
              subtitle: Text(
                'On',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
            ListTile(
              leading: Icon(
                  unlocked ? Icons.lock_open_outlined : Icons.lock_outline),
              title: Text(unlocked ? 'Unlocked' : 'Locked'),
              subtitle: Text(
                unlocked
                    ? 'Locks after 5 minutes in the background or when '
                        'the app is closed'
                    : 'Enter the master password once to unlock everything',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: TextButton(
                onPressed: unlocked
                    ? ref.read(sessionProvider.notifier).lock
                    : () => _unlock(context, ref),
                child: Text(unlocked ? 'Lock now' : 'Unlock'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Change master password'),
              onTap: () => _open(context, PasswordFormMode.change),
            ),
            ListTile(
              leading: const Icon(Icons.no_encryption_outlined),
              title: const Text('Remove master password'),
              onTap: () => _open(context, PasswordFormMode.remove),
            ),
          ],
          const Divider(color: AppColors.divider),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.lock_outline),
            title: Text('Section locks'),
            subtitle: Text(
              'Lock whole sections · coming soon',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
