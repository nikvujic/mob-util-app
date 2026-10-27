import 'package:flutter/material.dart';
import 'package:the_app/widgets/low_handles.dart';
import 'package:the_app/widgets/app_dialog.dart';

/// A generic yes/no confirmation dialog.
///
/// Use [showConfirmDialog] (or [showDeleteConfirmDialog]) rather than building
/// this widget directly.
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;

  /// Styles the confirm action as dangerous (e.g. delete).
  final bool destructive;

  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: title,
      content: message == null ? null : DialogMessage(message!),
      actions: [
        DialogButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogButton(
          label: confirmLabel,
          primary: true,
          danger: destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// What the user types to confirm deleting for good (password reset,
/// clear data).
const resetConfirmWord = 'RESET';

/// Shows a [ConfirmDialog] and resolves to `true` only if the user confirmed.
/// Dismissing the dialog (tap outside, back) counts as cancel.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

/// Confirmation for deleting [count] items, e.g. "Delete 3 notes?".
Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  required int count,
  required String singular,
  required String plural,
}) {
  final noun = count == 1 ? singular : plural;
  return showConfirmDialog(
    context,
    title: count == 1 ? 'Delete $noun?' : 'Delete $count $noun?',
    message: 'This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
}

/// Asks whether to keep changes when leaving an editor: **Discard** or
/// **Save**. Resolves to `true` for Save and for back (only an explicit
/// Discard throws changes away), `false` for Discard, and `null` for a tap
/// outside: that just closes the dialog, staying in the editor.
Future<bool?> showSaveChangesDialog(
  BuildContext context, {
  String title = 'Save changes?',
  String? message,
}) {
  // Back pops with no result (→ Save); a tap outside is told apart by
  // its own layer under the dialog.
  const stay = #stay;
  return showDialog<Object>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            label: 'Keep editing',
            child: GestureDetector(
              key: const Key('outsideDialog'),
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(stay),
            ),
          ),
        ),
        _saveChanges(context, title, message),
      ],
    ),
  ).then((result) => result == stay ? null : (result as bool?) ?? true);
}

Widget _saveChanges(BuildContext context, String title, String? message) =>
    AppDialog(
      title: title,
      content: message == null ? null : DialogMessage(message),
      actions: [
        DialogButton(
          label: 'Discard',
          danger: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DialogButton(
          label: 'Save',
          primary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );

/// Asks to type [word] (DELETE) before something that matters goes for
/// good (Round 32: an important medicine). True only once typed and
/// confirmed.
Future<bool> showTypeToConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String word = 'DELETE',
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _TypeToConfirmDialog(
      title: title,
      message: message,
      word: word,
      confirmLabel: confirmLabel,
    ),
  );
  return result ?? false;
}

class _TypeToConfirmDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String word;
  final String confirmLabel;

  const _TypeToConfirmDialog({
    required this.title,
    required this.message,
    required this.word,
    required this.confirmLabel,
  });

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _typed = TextEditingController();

  @override
  void initState() {
    super.initState();
    _typed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _confirmed => _typed.text.trim().toUpperCase() == widget.word;

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message case final message?) DialogMessage(message),
          const SizedBox(height: 16),
          TextField(
            selectionControls: lowHandles,
            key: const Key('typeToConfirm'),
            controller: _typed,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Type ${widget.word} to confirm',
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
          label: widget.confirmLabel,
          primary: true,
          danger: true,
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}
