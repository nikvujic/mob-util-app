import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/security/forgot_password.dart';
import 'package:the_app/pages/security/password_form.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/password_reset_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/password_prompt.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/providers/fingerprint_provider.dart';

/// Master password (L1) and section locks (L5).
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
    if (ref.read(securityProvider) == null) return;
    await showPasswordPrompt<UnlockedKeys>(
      context,
      title: 'Unlock',
      confirmLabel: 'Unlock',
      attempt: ref.read(sessionProvider.notifier).unlock,
      alternative: PromptAlternative.fingerprint(
        attempt: ref.read(fingerprintProvider.notifier).unlock,
        isOffered: () => ref.read(fingerprintProvider),
      ),
    );
  }

  /// Resets a forgotten master password (L7), after confirmation.
  Future<void> _forgot(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final reset = ref.read(passwordResetProvider);
    if (!await showForgotPasswordDialog(context, reset.plan())) return;
    await reset.run();
    messenger.showSnackBar(
      const SnackBar(content: Text('Master password reset')),
    );
  }

  /// Turns a section lock on, or off (which needs the app unlocked).
  Future<void> _setSectionLock(
    BuildContext context,
    WidgetRef ref,
    AppSection section, {
    required bool lock,
  }) async {
    final locks = ref.read(sectionLocksProvider.notifier);
    if (lock) {
      locks.lock(section);
      return;
    }
    if (ref.read(sessionProvider) == null) {
      await _unlock(context, ref);
      if (ref.read(sessionProvider) == null) return; // cancelled
    }
    locks.unlock(section);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPassword = ref.watch(securityProvider) != null;
    final locks = ref.watch(sectionLocksProvider);
    final unlocked = ref.watch(sessionProvider) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: PullDownList.children(
        children: [
          if (!hasPassword)
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Set master password'),
              subtitle: Text(
                'Protects locked notes and encrypted backups',
                style: TextStyle(color: context.colors.textSecondary),
              ),
              onTap: () => _open(context, PasswordFormMode.set),
            )
          else ...[
            ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('Master password'),
              subtitle: Text(
                'On',
                style: TextStyle(color: context.colors.accent),
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
                style: TextStyle(color: context.colors.textSecondary),
              ),
              trailing: TextButton(
                onPressed: unlocked
                    ? ref.read(sessionProvider.notifier).lock
                    : () => _unlock(context, ref),
                child: Text(unlocked ? 'Lock now' : 'Unlock'),
              ),
            ),
            _FingerprintTile(unlock: () => _unlock(context, ref)),
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
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Forgot master password?'),
              subtitle: Text(
                'Reset it by deleting what it locks',
                style: TextStyle(color: context.colors.textSecondary),
              ),
              onTap: () => _forgot(context, ref),
            ),
          ],
          Divider(color: context.colors.divider),
          const _SectionHeader('Section locks'),
          if (!hasPassword)
            ListTile(
              enabled: false,
              leading: Icon(Icons.lock_outline),
              title: Text('Lock whole sections'),
              subtitle: Text(
                'Set a master password first',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            )
          else ...[
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'A locked section opens only while the app is unlocked. '
                'It hides the section; for encrypted content, lock notes.',
                style: TextStyle(color: context.colors.textMuted),
              ),
            ),
            for (final section in AppSection.values)
              SwitchListTile(
                secondary: Icon(
                  locks.contains(section)
                      ? Icons.lock_outline
                      : Icons.lock_open_outlined,
                ),
                title: Text(section.label),
                value: locks.contains(section),
                onChanged: (lock) =>
                    _setSectionLock(context, ref, section, lock: lock),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: context.colors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Turns fingerprint unlock (L6) on or off. Only shown if the phone can
/// do it.
class _FingerprintTile extends ConsumerStatefulWidget {
  /// Asks for the master password, to unlock the app.
  final Future<void> Function() unlock;

  const _FingerprintTile({required this.unlock});

  @override
  ConsumerState<_FingerprintTile> createState() => _FingerprintTileState();
}

class _FingerprintTileState extends ConsumerState<_FingerprintTile> {
  late final Future<bool> _available =
      ref.read(fingerprintProvider.notifier).isAvailable();

  Future<void> _set(bool on) async {
    final fingerprint = ref.read(fingerprintProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    if (!on) {
      await fingerprint.turnOff();
      return;
    }
    // Storing the key needs it: from the unlocked app.
    if (ref.read(sessionProvider) == null) {
      await widget.unlock();
      if (ref.read(sessionProvider) == null) return; // cancelled
    }
    final done = await fingerprint.turnOn();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          done
              ? 'Fingerprint unlock is on'
              : 'Fingerprint unlock wasn\'t turned on',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(fingerprintProvider);
    return FutureBuilder<bool>(
      future: _available,
      builder: (context, available) {
        if (available.data != true) return const SizedBox.shrink();
        return SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: const Text('Unlock with fingerprint'),
          subtitle: Text(
            'Instead of typing the master password, on this phone',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          value: on,
          onChanged: _set,
        );
      },
    );
  }
}
