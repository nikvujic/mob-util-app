import 'package:flutter/material.dart';
import 'package:the_app/widgets/app_dialog.dart';
import 'package:the_app/widgets/password_field.dart';

/// Asks for a password and checks it with [attempt], which returns a result
/// for the right password and null for a wrong one. The dialog stays open
/// (showing "Wrong password") until the password is right or the user
/// cancels. Resolves to [attempt]'s result, or null if cancelled.
///
/// [attempt] may be slow (key derivation): the dialog shows progress and
/// can't be dismissed meanwhile.
///
/// With an [alternative] (e.g. a fingerprint), that is tried first, as the
/// prompt opens; if it gives nothing, the password field is there, with a
/// button to try the alternative again.
Future<T?> showPasswordPrompt<T extends Object>(
  BuildContext context, {
  required String title,
  required Future<T?> Function(String password) attempt,
  String? message,
  String confirmLabel = 'OK',
  PromptAlternative<T>? alternative,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PasswordPromptDialog<T>(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      attempt: attempt,
      alternative: alternative,
    ),
  );
}

/// Another way than typing the password for [showPasswordPrompt].
class PromptAlternative<T extends Object> {
  final String label;
  final IconData icon;

  /// Gets the result, or null (cancelled or failed).
  final Future<T?> Function() attempt;

  /// Whether to keep offering it (e.g. false once it's been turned off).
  final bool Function() isOffered;

  const PromptAlternative({
    required this.label,
    required this.icon,
    required this.attempt,
    required this.isOffered,
  });

  /// Unlocking with a fingerprint (L6).
  const PromptAlternative.fingerprint({
    required this.attempt,
    required this.isOffered,
  })  : label = 'Use fingerprint',
        icon = Icons.fingerprint;
}

/// The dialog behind [showPasswordPrompt].
class PasswordPromptDialog<T extends Object> extends StatefulWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final Future<T?> Function(String password) attempt;
  final PromptAlternative<T>? alternative;

  const PasswordPromptDialog({
    super.key,
    required this.title,
    required this.attempt,
    this.message,
    this.confirmLabel = 'OK',
    this.alternative,
  });

  @override
  State<PasswordPromptDialog<T>> createState() =>
      _PasswordPromptDialogState<T>();
}

class _PasswordPromptDialogState<T extends Object>
    extends State<PasswordPromptDialog<T>> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _busy = false;

  /// Whether the [PasswordPromptDialog.alternative] is still offered.
  late bool _alternative = widget.alternative?.isOffered() ?? false;

  @override
  void initState() {
    super.initState();
    if (_alternative) {
      // Straight to the fingerprint (or whatever it is), once shown.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryAlternative());
    }
  }

  Future<void> _tryAlternative() async {
    final alternative = widget.alternative;
    if (_busy || alternative == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await alternative.attempt();
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
      return;
    }
    setState(() {
      _busy = false;
      _alternative = alternative.isOffered();
    });
    _focus.requestFocus(); // on to the password
  }

  @override
  void dispose() {
    _password.dispose();
    _focus.dispose();
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
      child: AppDialog(
        title: widget.title,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.message != null) ...[
              DialogMessage(widget.message!),
              const SizedBox(height: 16),
            ],
            PasswordField(
              key: const Key('promptPassword'),
              controller: _password,
              label: 'Master password',
              error: _error,
              enabled: !_busy,
              focusNode: _focus,
              // With an alternative, the keyboard waits until it's done.
              autofocus: !_alternative,
              last: true,
              onSubmitted: _submit,
            ),
            if (_alternative) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: Icon(widget.alternative!.icon),
                  label: Text(widget.alternative!.label),
                  onPressed: _busy ? null : _tryAlternative,
                ),
              ),
            ],
          ],
        ),
        actions: [
          DialogButton(
            label: 'Cancel',
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          DialogButton(
            label: widget.confirmLabel,
            primary: true,
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
