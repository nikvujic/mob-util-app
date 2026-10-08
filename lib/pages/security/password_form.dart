import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/security_provider.dart';

enum PasswordFormMode {
  set(
    title: 'Set master password',
    action: 'Set password',
    done: 'Master password set',
    warning: 'A forgotten master password can\'t be recovered. Locked notes '
        'and encrypted backups can only be opened with it.',
  ),
  change(
    title: 'Change master password',
    action: 'Change password',
    done: 'Master password changed',
    warning: 'Encrypted backups made before the change still need the old '
        'password to be restored.',
  ),
  remove(
    title: 'Remove master password',
    action: 'Remove password',
    done: 'Master password removed',
    warning: 'Encrypted backups made with this password still need it to be '
        'restored.',
  );

  const PasswordFormMode({
    required this.title,
    required this.action,
    required this.done,
    required this.warning,
  });

  final String title;
  final String action;

  /// Shown after success (returned to the previous page).
  final String done;
  final String warning;

  bool get needsCurrent => this != set;
  bool get choosesNew => this != remove;
}

/// One form for setting, changing and removing the master password. Pops
/// with [PasswordFormMode.done] on success.
class PasswordFormPage extends ConsumerStatefulWidget {
  final PasswordFormMode mode;

  const PasswordFormPage({super.key, required this.mode});

  @override
  ConsumerState<PasswordFormPage> createState() => _PasswordFormPageState();
}

class _PasswordFormPageState extends ConsumerState<PasswordFormPage> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();

  String? _currentError;
  String? _newError;
  String? _repeatError;
  bool _busy = false;

  PasswordFormMode get _mode => widget.mode;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  /// Checks the fields; returns true if the form can be submitted.
  bool _validate() {
    setState(() {
      _currentError = _mode.needsCurrent && _current.text.isEmpty
          ? 'Enter your current password'
          : null;
      _newError =
          _mode.choosesNew ? MasterPasswordRules.validate(_new.text) : null;
      _repeatError = _mode.choosesNew && _newError == null
          ? (_repeat.text != _new.text ? 'Passwords don\'t match' : null)
          : null;
    });
    return _currentError == null && _newError == null && _repeatError == null;
  }

  Future<void> _submit() async {
    if (_busy || !_validate()) return;
    setState(() => _busy = true);
    final security = ref.read(securityProvider.notifier);
    try {
      switch (_mode) {
        case PasswordFormMode.set:
          await security.setPassword(_new.text);
        case PasswordFormMode.change:
          await security.changePassword(_current.text, _new.text);
        case PasswordFormMode.remove:
          await security.removePassword(_current.text);
      }
      if (mounted) Navigator.of(context).pop(_mode.done);
    } on WrongPasswordException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _currentError = 'Wrong password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      if (_mode.needsCurrent)
        _PasswordField(
          key: const Key('currentPassword'),
          controller: _current,
          label: 'Current password',
          error: _currentError,
          enabled: !_busy,
          autofocus: true,
          last: !_mode.choosesNew,
          onSubmitted: _submit,
        ),
      if (_mode.choosesNew) ...[
        _PasswordField(
          key: const Key('newPassword'),
          controller: _new,
          label: 'New password',
          helper: 'At least ${MasterPasswordRules.minLength} characters',
          error: _newError,
          enabled: !_busy,
          autofocus: !_mode.needsCurrent,
          isNew: true,
          onSubmitted: _submit,
        ),
        _PasswordField(
          key: const Key('repeatPassword'),
          controller: _repeat,
          label: 'Repeat new password',
          error: _repeatError,
          enabled: !_busy,
          isNew: true,
          last: true,
          onSubmitted: _submit,
        ),
      ],
    ];

    return PopScope(
      // Don't leave halfway through changing the password.
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(_mode.title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Warning(text: _mode.warning),
            const SizedBox(height: 16),
            for (final field in fields) ...[
              field,
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_mode.action),
            ),
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  final String text;

  const _Warning({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// A password input with a show/hide toggle. Never auto-corrected or
/// suggested by the keyboard.
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? error;
  final bool enabled;
  final bool autofocus;
  final bool isNew;
  final bool last;
  final VoidCallback onSubmitted;

  const _PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.onSubmitted,
    this.helper,
    this.error,
    this.enabled = true,
    this.autofocus = false,
    this.isNew = false,
    this.last = false,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        widget.isNew ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction:
          widget.last ? TextInputAction.done : TextInputAction.next,
      onSubmitted: widget.last ? (_) => widget.onSubmitted() : null,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        errorText: widget.error,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
          tooltip: _visible ? 'Hide password' : 'Show password',
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}
