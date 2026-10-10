import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/app_dialog.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/password_prompt.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/providers/fingerprint_provider.dart';

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
    if (unlocked != null) return unlocked.passwordKey;
    final verifier = ref.read(securityProvider);
    if (verifier == null) return null;
    final key = await showPasswordPrompt<PasswordKey>(
      context,
      title: 'Encrypt backup',
      message: "You'll need this password to restore the backup.",
      confirmLabel: 'Encrypt',
      attempt: verifier.unlock,
    );
    if (key != null) await ref.read(sessionProvider.notifier).unlockWith(key);
    return key;
  }

  /// While a section is locked and the app is locked, backups need the
  /// app unlocked: they'd contain (or replace) that section's data.
  /// False if the user cancels.
  Future<bool> _unlockIfSectionsClosed() async {
    if (!ref.read(anySectionClosedProvider)) return true;
    final keys = await showPasswordPrompt<UnlockedKeys>(
      context,
      title: 'Unlock',
      message: 'Some sections are locked. Enter the master password to '
          'back up or restore.',
      confirmLabel: 'Unlock',
      attempt: ref.read(sessionProvider.notifier).unlock,
      alternative: PromptAlternative.fingerprint(
        attempt: ref.read(fingerprintProvider.notifier).unlock,
        isOffered: () => ref.read(fingerprintProvider),
      ),
    );
    return keys != null;
  }

  Future<void> _export() async {
    if (!await _unlockIfSectionsClosed() || !mounted) return;
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

  /// Runs [ask] (a prompt during restoring) without the busy indicator:
  /// the app is waiting for the user then, not working.
  Future<T?> _asking<T>(Future<T?> Function() ask) async {
    if (!mounted) return null;
    setState(() => _importing = false);
    try {
      return await ask();
    } finally {
      if (mounted) setState(() => _importing = true);
    }
  }

  /// Restoring locked notes on a locked app: unlock it first.
  Future<DataKey?> _askThisAppKey() => _asking(() async {
        final keys = await showPasswordPrompt<UnlockedKeys>(
          context,
          title: 'Unlock',
          message: 'This backup has locked notes. Enter your master password '
              'to restore them.',
          confirmLabel: 'Unlock',
          attempt: ref.read(sessionProvider.notifier).unlock,
          alternative: PromptAlternative.fingerprint(
            attempt: ref.read(fingerprintProvider.notifier).unlock,
            isOffered: () => ref.read(fingerprintProvider),
          ),
        );
        return keys?.dataKey;
      });

  /// Locked notes from another master password: ask for that one.
  Future<DataKey?> _askBackupKey(PasswordVerifier record) =>
      _asking(() => showPasswordPrompt<DataKey>(
            context,
            title: 'Locked notes',
            message:
                "This backup's locked notes use a different master password. "
                'Enter the master password the backup was made with; they will '
                'then open with your current one.',
            confirmLabel: 'OK',
            attempt: (password) async {
              final key = await record.unlock(password);
              return key == null ? null : record.unwrapDataKey(key);
            },
          ));

  Future<void> _import() async {
    if (!await _unlockIfSectionsClosed() || !mounted) return;
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
          '${countOf(backup.noteCount, 'note', 'notes')}'
          '${backup.lockedNoteCount > 0 ? ' (${backup.lockedNoteCount} locked)' : ''}'
          ' · '
          '${countOf(backup.shopItemCount, 'shop item', 'shop items')} · '
          '${countOf(backup.plannerTaskCount, 'task', 'tasks')} · '
          '${countOf(backup.counterCount, 'counter', 'counters')}\n\n'
          'This replaces all notes, shop items, planner tasks and counters '
          'currently in the app.',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _importing = true);
    try {
      final previous = await importer.restore(
        backup,
        thisAppKey: _askThisAppKey,
        backupKey: _askBackupKey,
      );
      if (previous == null || !mounted) return;
      _showMessage(
        previous.adoptedMasterPassword
            ? "Backup restored. Its master password is now this app's "
                'master password.'
            : 'Backup restored',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => importer.undo(previous),
        ),
      );
    } on ImportException catch (e) {
      if (mounted) _showMessage(e.message);
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
      body: PullDownList.children(
        children: [
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Export all data'),
            subtitle: Text(
              'Save all your data to a file you choose',
              style: TextStyle(color: context.colors.textSecondary),
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
            subtitle: Text(
              'Restore all your data from a backup',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            trailing: _importing
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _busy ? null : _import,
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Keep a backup somewhere other than this phone, such as Google '
              'Drive, so you can restore your data on a new phone or after '
              'reinstalling the app.',
              style: TextStyle(color: context.colors.textMuted),
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
            subtitle: Text(
              'Readable in any text editor — by anyone who has the file',
              style: TextStyle(color: context.colors.textSecondary),
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
              style: TextStyle(color: context.colors.textSecondary),
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
