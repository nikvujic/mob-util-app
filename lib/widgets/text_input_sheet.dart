import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// Bottom sheet with a single text field.
///
/// With [keepOpen] the sheet stays open after each submit (the field is
/// cleared and keeps focus) so several entries can be added in a row; each
/// non-blank entry is passed to [onSubmit]. Otherwise the sheet closes and
/// returns the entered text.
class TextInputSheet extends StatefulWidget {
  final String hint;
  final String initialValue;
  final String submitLabel;
  final bool keepOpen;
  final ValueChanged<String>? onSubmit;

  const TextInputSheet({
    super.key,
    required this.hint,
    this.initialValue = '',
    this.submitLabel = 'Save',
    this.keepOpen = false,
    this.onSubmit,
  });

  @override
  State<TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<TextInputSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialValue.length,
        );
  final FocusNode _focusNode = FocusNode();

  /// Whether the on-screen keyboard has been shown for this sheet.
  bool _keyboardShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Closing the keyboard (e.g. its back key) means the user is done:
    // close the sheet too, instead of leaving it hanging over a dimmed
    // page. Only while this sheet is the top route — if it's already
    // closing, the keyboard hiding must not close the page below.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (keyboardOpen) {
      _keyboardShown = true;
    } else if (_keyboardShown) {
      _keyboardShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isCurrent) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (!widget.keepOpen) Navigator.of(context).pop();
      return;
    }
    widget.onSubmit?.call(text);
    if (widget.keepOpen) {
      _controller.clear();
      _focusNode.requestFocus();
    } else {
      Navigator.of(context).pop(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction:
                  widget.keepOpen ? TextInputAction.send : TextInputAction.done,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: context.colors.textHint),
                border: InputBorder.none,
              ),
              // Keep the keyboard up between entries in keepOpen mode.
              onEditingComplete: widget.keepOpen ? () {} : null,
              onSubmitted: (_) => _submit(),
            ),
          ),
          TextButton(
            onPressed: _submit,
            child: Text(
              widget.submitLabel,
              style: TextStyle(color: context.colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a [TextInputSheet]. Resolves to the entered text (single mode), or
/// null when dismissed or when [keepOpen] is used.
Future<String?> showTextInputSheet(
  BuildContext context, {
  required String hint,
  String initialValue = '',
  String submitLabel = 'Save',
  bool keepOpen = false,
  ValueChanged<String>? onSubmit,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TextInputSheet(
      hint: hint,
      initialValue: initialValue,
      submitLabel: submitLabel,
      keepOpen: keepOpen,
      onSubmit: onSubmit,
    ),
  );
}
