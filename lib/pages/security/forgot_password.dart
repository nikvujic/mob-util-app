import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/password_reset_provider.dart';
import 'package:the_app/widgets/app_dialog.dart';

/// Asks to reset a forgotten master password (L7), listing what [plan]
/// deletes. When anything will be deleted, the user has to type [resetConfirmWord].
/// Resolves to true if confirmed.
Future<bool> showForgotPasswordDialog(
  BuildContext context,
  PasswordResetPlan plan,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ForgotPasswordDialog(plan),
  );
  return result ?? false;
}

/// What the user types to confirm deleting.
const resetConfirmWord = 'RESET';

class _ForgotPasswordDialog extends StatefulWidget {
  final PasswordResetPlan plan;

  const _ForgotPasswordDialog(this.plan);

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
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

  bool get _deletes => widget.plan.deletesAnything;

  bool get _confirmed =>
      !_deletes || _confirm.text.trim().toUpperCase() == resetConfirmWord;

  static String _what(AppSection section, int count) => switch (section) {
        AppSection.notes => countOf(count, 'note', 'notes'),
        AppSection.shop => countOf(count, 'item', 'items'),
        AppSection.planner => countOf(count, 'planner item', 'planner items'),
        AppSection.other => countOf(count, 'counter', 'counters'),
      };

  List<String> get _lines => [
        if (widget.plan.lockedNotes > 0)
          countOf(widget.plan.lockedNotes, 'locked note', 'locked notes'),
        for (final MapEntry(key: section, value: count)
            in widget.plan.sections.entries)
          if (count > 0)
            '${section.label} (locked section): ${_what(section, count)}',
      ];

  @override
  Widget build(BuildContext context) {
    const backups = 'Encrypted backups made with this password still need '
        'it to be restored.';
    return AppDialog(
      title: 'Reset master password?',
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_deletes)
            const DialogMessage('Nothing is locked, so nothing will be '
                'deleted. $backups')
          else ...[
            const DialogMessage(
              'The password can\'t be recovered. Resetting it deletes, for '
              'good, everything it locks:',
            ),
            const SizedBox(height: 8),
            for (final line in _lines)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '•  $line',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const DialogMessage('Everything else stays. $backups'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('resetConfirm'),
              controller: _confirm,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Type $resetConfirmWord to confirm',
              ),
            ),
          ],
        ],
      ),
      actions: [
        DialogButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogButton(
          label: 'Reset',
          primary: true,
          danger: true,
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}
