import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// A password input with a show/hide toggle. Never auto-corrected or
/// suggested by the keyboard.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? error;
  final bool enabled;
  final bool autofocus;

  /// A password being chosen (vs. one being entered), for autofill.
  final bool isNew;

  /// The last field of its form: the keyboard shows "done" and submitting
  /// calls [onSubmitted] (other fields move to the next one).
  final bool last;
  final VoidCallback onSubmitted;

  const PasswordField({
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
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
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
