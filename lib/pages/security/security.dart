import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/security/password_form.dart';
import 'package:the_app/providers/security_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPassword = ref.watch(securityProvider) != null;

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
