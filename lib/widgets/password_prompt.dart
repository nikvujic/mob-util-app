import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/password_field.dart';

/// Asks for a password and checks it with [attempt], which returns a result
/// for the right password and null for a wrong one. The dialog stays open
/// (showing "Wrong password") until the password is right or the user
/// cancels. Resolves to [attempt]'s result, or null if cancelled.
///
/// [attempt] may be slow (key derivation): the dialog shows progress and
/// can't be dismissed meanwhile.
Future<T?> showPasswordPrompt<T extends Object>(
  BuildContext context, {
  required String title,
  required Future<T?> Function(String password) attempt,
  String? message,
  String confirmLabel = 'OK',
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PasswordPromptDialog<T>(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      attempt: attempt,
    ),
  );
}

/// The dialog behind [showPasswordPrompt].
class PasswordPromptDialog<T extends Object> extends StatefulWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final Future<T?> Function(String password) attempt;

  const PasswordPromptDialog({
    super.key,
    required this.title,
    required this.attempt,
    this.message,
    this.confirmLabel = 'OK',
  });

  @override
  State<PasswordPromptDialog<T>> createState() =>
      _PasswordPromptDialogState<T>();
}

class _PasswordPromptDialogState<T extends Object>
    extends State<PasswordPromptDialog<T>> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter the password');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.attempt(_password.text);
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      setState(() {
        _busy = false;
        _error = 'Wrong password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.message != null) ...[
              Text(
                widget.message!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
            ],
            PasswordField(
              key: const Key('promptPassword'),
              controller: _password,
              label: 'Master password',
              error: _error,
              enabled: !_busy,
              autofocus: true,
              last: true,
              onSubmitted: _submit,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.confirmLabel,
                    style: const TextStyle(color: AppColors.accent),
                  ),
          ),
        ],
      ),
    );
  }
}
