import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// The look shared by every dialog in the app: squarer corners and a clear
/// title / content / actions layout, with real buttons ([DialogButton]).
class AppDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final List<Widget> actions;

  const AppDialog({
    super.key,
    required this.title,
    this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: AppShapes.dialog,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: content,
      actions: actions,
    );
  }
}

/// Body text of an [AppDialog].
class DialogMessage extends StatelessWidget {
  final String text;

  const DialogMessage(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
    );
  }
}

/// A dialog action: [primary] is the main choice (filled), the others are
/// outlined. [danger] marks actions that throw something away.
class DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;

  /// Shown instead of the label (e.g. a progress indicator).
  final Widget? child;

  const DialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.danger = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final content = child ?? Text(label);
    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        style: danger
            ? FilledButton.styleFrom(
                shape: AppShapes.button,
                backgroundColor: AppColors.danger,
                foregroundColor: AppColors.background,
              )
            : FilledButton.styleFrom(shape: AppShapes.button),
        child: content,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: AppShapes.button,
        foregroundColor: danger ? AppColors.danger : AppColors.textPrimary,
        side: BorderSide(
          color: danger ? AppColors.danger : AppColors.textHint,
        ),
      ),
      child: content,
    );
  }
}
