import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/storage_error.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/providers/section_data_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/widgets/app_dialog.dart';
import 'package:the_app/widgets/password_prompt.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// Settings → Clear data (D7): empties the picked sections, after typing
/// DELETE and, with a master password set, entering it.
class ClearDataPage extends ConsumerStatefulWidget {
  const ClearDataPage({super.key});

  @override
  ConsumerState<ClearDataPage> createState() => _ClearDataPageState();
}

class _ClearDataPageState extends ConsumerState<ClearDataPage> {
  final _picked = <AppSection>{};

  static String _what(AppSection section) => switch (section) {
        AppSection.notes => 'Notes, locked ones too',
        AppSection.shop => 'The shopping list',
        AppSection.planner => 'Tasks, routines and reminders',
        AppSection.other => 'Counters',
      };

  Future<void> _clear() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final sections = [
      for (final section in AppSection.values)
        if (_picked.contains(section)) section,
    ];
    if (!await _confirm(sections)) return;
    if (!mounted) return;
    if (ref.read(securityProvider) != null) {
      final keys = await showPasswordPrompt<UnlockedKeys>(
        context,
        title: 'Master password',
        message: 'Enter it to clear the data.',
        confirmLabel: 'Clear',
        attempt: ref.read(sessionProvider.notifier).unlock,
      );
      if (keys == null) return; // cancelled
    }
    try {
      await ref.read(sectionDataProvider).clearAll(sections);
    } on StorageWriteException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't save on the phone (is its storage full?). "
              'The data may come back when the app restarts.'),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
          content: Text('Cleared ${sections.map((s) => s.label).join(', ')}')),
    );
    navigator.pop();
  }

  Future<bool> _confirm(List<AppSection> sections) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ClearDataDialog(sections),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Counts that follow the data.
    ref
      ..watch(notesProvider)
      ..watch(shopProvider)
      ..watch(plannerProvider)
      ..watch(routinesProvider)
      ..watch(pinsProvider)
      ..watch(countersProvider);
    final data = ref.read(sectionDataProvider);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Clear data')),
      body: PullDownList.children(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Deletes everything in the sections you pick, for good. '
              'Settings, themes and the master password stay.',
              style: TextStyle(color: colors.textSecondary, height: 1.4),
            ),
          ),
          for (final section in AppSection.values)
            CheckboxListTile(
              key: Key('clear-${section.name}'),
              value: _picked.contains(section),
              onChanged: (on) => setState(() =>
                  on == true ? _picked.add(section) : _picked.remove(section)),
              title: Text(section.label),
              subtitle: Text(
                '${_what(section)} · '
                '${countOf(data.count(section), 'item', 'items')}',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
        ],
      ),
      // At the bottom, in reach of the thumb.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            key: const Key('clearData'),
            onPressed: _picked.isEmpty ? null : _clear,
            style: FilledButton.styleFrom(
              shape: AppShapes.button,
              backgroundColor: colors.danger,
              foregroundColor: colors.background,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Clear'),
          ),
        ),
      ),
    );
  }
}

/// What the user types to confirm clearing (Nikola: DELETE here).
const clearConfirmWord = 'DELETE';

/// Lists what goes; the user types [clearConfirmWord] to confirm.
class _ClearDataDialog extends StatefulWidget {
  final List<AppSection> sections;

  const _ClearDataDialog(this.sections);

  @override
  State<_ClearDataDialog> createState() => _ClearDataDialogState();
}

class _ClearDataDialogState extends State<_ClearDataDialog> {
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool get _confirmed => _confirm.text.trim().toUpperCase() == clearConfirmWord;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Clear data?',
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DialogMessage('This deletes, for good, everything in:'),
          const SizedBox(height: 8),
          for (final section in widget.sections)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text(
                '•  ${section.label}',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          const DialogMessage('Backups you saved are not touched.'),
          const SizedBox(height: 16),
          TextField(
            key: const Key('clearConfirm'),
            controller: _confirm,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Type $clearConfirmWord to confirm',
            ),
          ),
        ],
      ),
      actions: [
        DialogButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogButton(
          label: 'Clear',
          primary: true,
          danger: true,
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}
