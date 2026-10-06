import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

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
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
      ),
      content: message == null
          ? null
          : Text(
              message!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? AppColors.danger : AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
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
