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

  /// Edits this text directly, live (e.g. a note's title), instead of
  /// returning a new one; it may be left empty.
  final TextEditingController? controller;

  /// E.g. numbers for an amount; text by default.
  final TextInputType? keyboardType;

  /// What's already there that matches the typed text (Round 58: Shop's
  /// items not on the list), offered above the field as you type; a tap
  /// submits it. Asked again on each change, so it's always current.
  final List<String> Function(String typed)? suggestions;

  /// How many suggestions show at most.
  static const mostSuggestions = 6;

  const TextInputSheet({
    super.key,
    required this.hint,
    this.initialValue = '',
    this.submitLabel = 'Save',
    this.keepOpen = false,
    this.onSubmit,
    this.controller,
    this.keyboardType,
    this.suggestions,
  });

  @override
  State<TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<TextInputSheet> {
  late final TextEditingController _controller = widget.controller ??
      (TextEditingController(text: widget.initialValue)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialValue.length,
        ));
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
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit([String? picked]) {
    // Edited live: nothing to hand back.
    if (widget.controller != null) {
      Navigator.of(context).pop();
      return;
    }
    final text = (picked ?? _controller.text).trim();
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

  /// The suggestions for what's typed, as chips in a row that scrolls
  /// sideways; nothing while nothing's typed or nothing matches.
  Widget _suggestions(BuildContext context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final typed = _controller.text.trim();
          final found = typed.isEmpty
              ? const <String>[]
              : widget.suggestions!(typed)
                  .take(TextInputSheet.mostSuggestions)
                  .toList();
          if (found.isEmpty) return const SizedBox.shrink();
          return SingleChildScrollView(
            key: const Key('textSuggestions'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                for (final name in found)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      key: Key('suggestion-$name'),
                      avatar: const Icon(Icons.history, size: 18),
                      label: Text(name),
                      onPressed: () => _submit(name),
                    ),
                  ),
              ],
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final field = _field(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
      ),
      child: widget.suggestions == null
          ? field
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_suggestions(context), field],
            ),
    );
  }

  Widget _field(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: widget.keyboardType,
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
  TextEditingController? controller,
  TextInputType? keyboardType,
  List<String> Function(String typed)? suggestions,
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
      controller: controller,
      keyboardType: keyboardType,
      suggestions: suggestions,
    ),
  );
}
