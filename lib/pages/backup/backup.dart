import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/widgets/password_prompt.dart';

enum _ExportKind { plain, encrypted }

/// Export (and later import) of all app data (requirements D1–D4).
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _exporting = false;

  /// Asks for the master password; the key derived from it, or null if
  /// cancelled.
  Future<PasswordKey?> _askMasterPassword() {
    final verifier = ref.read(securityProvider);
    if (verifier == null) return Future.value();
    return showPasswordPrompt<PasswordKey>(
      context,
      title: 'Encrypt backup',
      message: "You'll need this password to restore the backup.",
      confirmLabel: 'Encrypt',
      attempt: verifier.unlock,
    );
  }

  Future<void> _export() async {
    final kind = await showDialog<_ExportKind>(
      context: context,
      builder: (_) => _ExportKindDialog(
        canEncrypt: ref.read(securityProvider) != null,
      ),
    );
    if (kind == null || !mounted) return;

    PasswordKey? key;
    if (kind == _ExportKind.encrypted) {
      key = await _askMasterPassword();
      if (key == null || !mounted) return;
    }

    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    final exporter = ref.read(backupExporterProvider);
    try {
      final result = key == null
          ? await exporter.export()
          : await exporter.exportEncrypted(key);
      if (result == ExportResult.saved) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              key == null ? 'Backup saved' : 'Encrypted backup saved',
            ),
          ),
        );
      }
      // Cancelled: the user closed the dialog on purpose; nothing to say.
    } catch (e, st) {
      debugPrint('Export failed: $e\n$st');
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't save the backup. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Export all data'),
            subtitle: const Text(
              'Save notes and shop list to a file you choose',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: _exporting
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            // Disabled while running, so a double tap can't export twice.
            onTap: _exporting ? null : _export,
          ),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.restore),
            title: Text('Import from file'),
            subtitle: Text(
              'Restore from a backup · coming soon',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Keep a backup somewhere other than this phone, such as Google '
              'Drive, so you can restore your data on a new phone or after '
              'reinstalling the app.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Export as": plain or encrypted. Encrypted needs a master password.
class _ExportKindDialog extends StatelessWidget {
  final bool canEncrypt;

  const _ExportKindDialog({required this.canEncrypt});

  @override
  Widget build(BuildContext context) {
    void choose(_ExportKind kind) => Navigator.of(context).pop(kind);

    return SimpleDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Export as'),
      children: [
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Plain file'),
          subtitle: const Text(
            'Readable in any text editor — by anyone who has the file',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          onTap: () => choose(_ExportKind.plain),
        ),
        ListTile(
          enabled: canEncrypt,
          leading: const Icon(Icons.lock_outline),
          title: const Text('Encrypted file'),
          subtitle: Text(
            canEncrypt
                ? 'Only readable with your master password'
                : 'Set a master password in Security first',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          onTap: () => choose(_ExportKind.encrypted),
        ),
      ],
    );
  }
}
