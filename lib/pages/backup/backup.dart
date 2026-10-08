import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/app_dialog.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/password_prompt.dart';

enum _ExportKind { plain, encrypted }

/// Export (and later import) of all app data (requirements D1–D4).
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

/// Result of opening an encrypted backup with the right password: the
/// backup, or why its (decrypted) contents can't be used.
typedef _Opened = ({RestorableBackup? backup, String? error});

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _exporting = false;
  bool _importing = false;

  bool get _busy => _exporting || _importing;

  void _showMessage(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        action: action,
        // Long enough to reach Undo.
        duration: Duration(seconds: action == null ? 4 : 10),
      ),
    );
  }

  /// The master password's key: from the unlocked session, or else asked
  /// for (which also unlocks the session). Null if cancelled.
  Future<PasswordKey?> _masterKey() async {
    final unlocked = ref.read(sessionProvider);
    if (unlocked != null) return unlocked;
    final verifier = ref.read(securityProvider);
    if (verifier == null) return null;
    final key = await showPasswordPrompt<PasswordKey>(
      context,
      title: 'Encrypt backup',
      message: "You'll need this password to restore the backup.",
      confirmLabel: 'Encrypt',
      attempt: verifier.unlock,
    );
    if (key != null) ref.read(sessionProvider.notifier).unlockWith(key);
    return key;
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
      key = await _masterKey();
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

  /// Asks for the password an encrypted backup was made with. Null if
  /// cancelled.
  Future<_Opened?> _openEncrypted(EncryptedPick file) {
    return showPasswordPrompt<_Opened>(
      context,
      title: 'Encrypted backup',
      message: 'Enter the master password this backup was made with.',
      confirmLabel: 'Open',
      attempt: (password) async {
        try {
          final backup = await file.unlock(password);
          return backup == null ? null : (backup: backup, error: null);
        } on ImportException catch (e) {
          return (backup: null, error: e.message);
        }
      },
    );
  }

  Future<void> _import() async {
    final importer = ref.read(backupImporterProvider);

    final PickedBackup? file;
    try {
      file = await importer.pick();
    } on ImportException catch (e) {
      _showMessage(e.message);
      return;
    } catch (e, st) {
      debugPrint('Import failed: $e\n$st');
      _showMessage("Couldn't open the file.");
      return;
    }
    if (file == null || !mounted) return;

    final RestorableBackup backup;
    switch (file) {
      case PlainPick(backup: final plain):
        backup = plain;
      case EncryptedPick():
        final opened = await _openEncrypted(file);
        if (opened == null || !mounted) return;
        if (opened.error != null) {
          _showMessage(opened.error!);
          return;
        }
        backup = opened.backup!;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Restore this backup?',
      message: 'Made ${formatDateTime(backup.createdAt)}\n'
          '${countOf(backup.noteCount, 'note', 'notes')} · '
          '${countOf(backup.shopItemCount, 'shop item', 'shop items')}\n\n'
          'This replaces all notes and shop items currently in the app.',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _importing = true);
    try {
      final previous = await importer.restore(backup);
      if (!mounted) return;
      _showMessage(
        'Backup restored',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => importer.undo(previous),
        ),
      );
    } catch (e, st) {
      debugPrint('Restore failed: $e\n$st');
      if (mounted) _showMessage("Couldn't restore the backup.");
    } finally {
      if (mounted) setState(() => _importing = false);
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
            // Disabled while working, so a double tap can't run twice.
            onTap: _busy ? null : _export,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Import from file'),
            subtitle: const Text(
              'Restore notes and shop list from a backup',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            trailing: _importing
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _busy ? null : _import,
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

    return AppDialog(
      title: 'Export as',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Plain file'),
            subtitle: const Text(
              'Readable in any text editor — by anyone who has the file',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            onTap: () => choose(_ExportKind.plain),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
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
      ),
      actions: [
        DialogButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
