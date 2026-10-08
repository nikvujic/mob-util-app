import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/backup_provider.dart';

/// Export (and later import) of all app data (requirements D1–D4).
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(backupExporterProvider).export();
      if (result == ExportResult.saved) {
        messenger.showSnackBar(const SnackBar(content: Text('Backup saved')));
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
