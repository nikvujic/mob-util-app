import 'package:flutter/material.dart';
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
/// **Save**. Resolves to `true` for Save **and** when the dialog is
/// dismissed (tap outside, back): only an explicit Discard throws changes
/// away.
Future<bool> showSaveChangesDialog(
  BuildContext context, {
  String title = 'Save changes?',
  String? message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
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
    ),
  );
  return result ?? true;
}
