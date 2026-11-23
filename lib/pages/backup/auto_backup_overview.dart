import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/auto_backup_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/app_dialog.dart';
import 'package:the_app/widgets/confirm_dialog.dart';

/// The automatic backups in the folder: "5 backups · 23 pictures ·
/// 120 MB"; a tap opens their overview.
class AutoBackupChip extends ConsumerWidget {
  const AutoBackupChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(autoBackupFolderProvider).valueOrNull;
    final label = state == null
        ? 'Backups in the folder'
        : [
            countOf(state.backups.length, 'backup', 'backups'),
            if (state.pictures > 0)
              countOf(state.pictures, 'picture', 'pictures'),
            formatBytes(state.bytes),
          ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          key: const Key('autoBackupChip'),
          avatar: const Icon(Icons.inventory_2_outlined, size: 18),
          label: Text(label),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _AutoBackupOverview(),
          ),
        ),
      ),
    );
  }
}

/// Each automatic backup with its date and size, and how many to keep.
class _AutoBackupOverview extends ConsumerWidget {
  const _AutoBackupOverview();

  /// Keeps [keep]; if the folder holds more than that ([there]), the
  /// oldest would be deleted at once: asked first.
  static Future<void> _keepFewer(
      BuildContext context, WidgetRef ref, int keep, int there) async {
    final gone = there - keep;
    if (gone > 0) {
      final confirmed = await showConfirmDialog(
        context,
        title: gone == 1
            ? 'Delete the oldest backup?'
            : 'Delete the $gone oldest backups?',
        message: 'Keeping $keep deletes ${gone == 1 ? 'it' : 'them'} from '
            'the folder now.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (!confirmed) return;
    }
    await ref.read(autoBackupProvider).setKeep(keep);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keep = ref.watch(preferencesProvider.select((p) => p.autoBackupKeep));
    final state = ref.watch(autoBackupFolderProvider);
    final muted = TextStyle(color: context.colors.textSecondary);
    return AppDialog(
      title: 'Automatic backups',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: switch (state) {
              AsyncData(value: final s?) when s.backups.isNotEmpty =>
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final b in s.backups)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(b.modified == null
                                    ? b.name
                                    : formatDateTime(b.modified!, gap: ' ')),
                              ),
                              Text(formatBytes(b.bytes), style: muted),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              AsyncData() || AsyncError() => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    state.hasError || state.value == null
                        ? "The folder can't be read: pick it again"
                        : 'None yet',
                    style: muted,
                  ),
                ),
              _ => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text('Keep the latest')),
              IconButton(
                key: const Key('autoBackupKeepLess'),
                icon: const Icon(Icons.remove),
                onPressed: keep <= 1
                    ? null
                    : () => _keepFewer(context, ref, keep - 1,
                        state.valueOrNull?.backups.length ?? 0),
              ),
              SizedBox(
                width: 28,
                child: Text('$keep',
                    key: const Key('autoBackupKeep'),
                    textAlign: TextAlign.center),
              ),
              IconButton(
                key: const Key('autoBackupKeepMore'),
                icon: const Icon(Icons.add),
                onPressed: keep >= AutoBackup.maxKeep
                    ? null
                    : () => ref.read(autoBackupProvider).setKeep(keep + 1),
              ),
            ],
          ),
        ],
      ),
      actions: [
        DialogButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
