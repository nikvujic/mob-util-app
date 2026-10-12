import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:the_app/core/markdown.dart';
import 'package:the_app/core/theme.dart';

/// A text controller that shows its text with the Markdown basics styled
/// (N9) as it's typed: headings, bold, italic, strike and list markers.
/// Formatting symbols (`##`, `**`, …) are hidden, except on the line being
/// edited while [editing] (live preview): there they show, muted, so they
/// can be changed. The text itself is never changed, only how it looks.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  /// How hidden symbols are drawn: no width, no colour. (Flutter can't
  /// leave characters out of an editable text, but it can draw them as
  /// nothing.)
  static const _hidden = TextStyle(
    fontSize: 0.01,
    letterSpacing: 0,
    color: Colors.transparent,
    decoration: TextDecoration.none,
  );

  bool _editing = false;

  /// Whether the user is typing in the field (it has focus): then the
  /// symbols on the cursor's line show.
  bool get editing => _editing;
  set editing(bool value) {
    if (value == _editing) return;
    _editing = value;
    notifyListeners(); // redraw
  }

  /// The lines the cursor (or selection) is on, while [editing].
  TextRange _revealed() {
    final selection = value.selection;
    if (!_editing || !selection.isValid) return TextRange.empty;
    final start = selection.start == 0
        ? 0
        : text.lastIndexOf('\n', selection.start - 1) + 1;
    final next = text.indexOf('\n', selection.end);
    return TextRange(start: start, end: next == -1 ? text.length : next);
  }

  /// The `[` of the checkbox drawn as a box at [offset] (a tap there
  /// ticks it, N15), or null. Not on the line being edited, where the
  /// symbols show instead.
  int? boxAt(int offset) {
    final checkbox = checkboxOnLine(text, offset);
    if (checkbox == null || offset > checkbox.box + 3) return null;
    final revealed = _revealed();
    if (checkbox.start >= revealed.start &&
        checkbox.start <= revealed.end &&
        !revealed.isCollapsed) {
      return null;
    }
    return checkbox.box;
  }

  /// Ticks or unticks the checkbox whose `[` is at [box]; the cursor stays.
  void toggleBox(int box) {
    value = value.copyWith(
      text: toggleCheckbox(text, box),
      composing: TextRange.empty,
    );
  }

  /// Drawn instead of a checkbox's `[`.
  static const unchecked = '☐';
  static const checked = '☑';

  /// How much bigger the boxes are drawn than the text.
  static const boxScale = 1.15;

  /// Unicode's "show the one before as text, not as an emoji" (VS15).
  static const textStyle = '\uFE0E';

  /// Heading sizes, relative to the body text: `#`, `##`, `###`.
  static const headingScale = [1.5, 1.3, 1.15];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final colors = context.colors;
    final base = style ?? const TextStyle();
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;

    TextStyle look(MdRun run) {
      var s = base;
      if (run.heading > 0) {
        s = s.copyWith(
          fontSize: (base.fontSize ?? 16) * headingScale[run.heading - 1],
          fontWeight: FontWeight.w700,
        );
      }
      if (run.bold) s = s.copyWith(fontWeight: FontWeight.w700);
      if (run.italic) s = s.copyWith(fontStyle: FontStyle.italic);
      if (run.done) {
        s = s.copyWith(
          color: colors.textSecondary,
          decoration: TextDecoration.lineThrough,
          decorationColor: colors.textSecondary,
        );
      }
      if (run.strike) {
        s = s.copyWith(
          decoration: TextDecoration.lineThrough,
          decorationColor: colors.textSecondary,
        );
      }
      return switch (run.role) {
        MdRole.text => s,
        // Faint, yet readable (muted keeps the contrast rule).
        MdRole.marker => s.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
            decoration: TextDecoration.none,
          ),
        MdRole.listMarker || MdRole.checkbox => s.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w700,
          ),
      };
    }

    // The keyboard's word in progress is underlined, as in any text field.
    final underline = base.merge(
      const TextStyle(decoration: TextDecoration.underline),
    );
    final revealed = _revealed();
    bool onRevealedLine(MdRun run) =>
        run.start >= revealed.start && run.end <= revealed.end;
    bool shown(MdRun run) => run.role != MdRole.marker || onRevealedLine(run);
    final spans = <TextSpan>[];
    for (final run in markdownRuns(text)) {
      // A checkbox off the line being edited: its `[` drawn as a box, the
      // other symbols as nothing, the space after it kept (N15).
      if (run.role == MdRole.checkbox && !onRevealedLine(run)) {
        final box = look(run);
        for (var i = run.start; i < run.end; i++) {
          final char = text[i];
          if (char == '[') {
            final ticked = text[i + 1] != ' ';
            // The box stands for "[" and the mark after it ("x" or " "),
            // two characters for two, so positions stay the same. The
            // second is "text style, please": without it the phone drew
            // ☑ as a white emoji, bigger and lower than ☐ (Nikola). Both
            // the same size, a bit bigger than the text, in the accent.
            final size = base.fontSize ?? 16;
            spans.add(TextSpan(
              text: '${ticked ? checked : unchecked}$textStyle',
              style: box.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w400,
                fontSize: size * boxScale,
                height: 1 / boxScale,
              ),
            ));
            i++; // its mark is in the box
          } else {
            final last = i == run.end - 1;
            spans.add(TextSpan(text: char, style: last ? base : _hidden));
          }
        }
        continue;
      }
      final style = shown(run) ? look(run) : _hidden;
      // Split where the composing word starts and ends.
      final cuts = {
        run.start,
        if (composing.start > run.start && composing.start < run.end)
          composing.start,
        if (composing.end > run.start && composing.end < run.end) composing.end,
        run.end,
      }.toList()
        ..sort();
      // A bullet's "-" (or * / +) shows as a dot, except on the line being
      // edited (N13). One character for one, so positions stay the same.
      final bullet = run.role == MdRole.listMarker &&
          !onRevealedLine(run) &&
          '-*+'.contains(text[run.start]);
      for (var i = 0; i < cuts.length - 1; i++) {
        final from = cuts[i], to = cuts[i + 1];
        final inWord = from >= composing.start && to <= composing.end;
        var piece = text.substring(from, to);
        if (bullet && from == run.start) piece = '•${piece.substring(1)}';
        spans.add(
          TextSpan(
            text: piece,
            style: inWord
                ? style.copyWith(
                    decoration: underline.decoration,
                    decorationColor: style.color,
                  )
                : style,
          ),
        );
      }
    }
    return TextSpan(style: base, children: spans);
  }
}

/// Continues a Markdown list on Enter, or ends it on an empty item (N9).
class MarkdownListFormatter extends TextInputFormatter {
  const MarkdownListFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only a single line break typed at the cursor.
    final at = oldValue.selection.start;
    if (!oldValue.selection.isCollapsed ||
        !newValue.selection.isCollapsed ||
        at < 0 ||
        newValue.selection.start != at + 1 ||
        newValue.text !=
            '${oldValue.text.substring(0, at)}\n'
                '${oldValue.text.substring(at)}') {
      return newValue;
    }
    final edit = continueList(newValue.text, at + 1);
    if (edit == null) return newValue;
    return TextEditingValue(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.cursor),
    );
  }
}

/// Ticks a checkbox drawn by [controller] when its box is tapped (N15),
/// without starting to edit; any other touch goes to the text field in
/// [child] as usual.
class CheckboxTaps extends StatelessWidget {
  final MarkdownEditingController controller;
  final Widget child;

  const CheckboxTaps({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _BoxTapRecognizer:
            GestureRecognizerFactoryWithHandlers<_BoxTapRecognizer>(
          () => _BoxTapRecognizer(),
          (recognizer) => recognizer
            ..boxAt = ((position) => _boxAt(context, position))
            ..onTap = controller.toggleBox,
        ),
      },
      child: child,
    );
  }

  /// The box under [position] (global), if any.
  int? _boxAt(BuildContext context, Offset position) {
    final editable = _findEditable(context.findRenderObject());
    if (editable == null || !editable.attached) return null;
    final offset = editable.getPositionForPoint(position).offset;
    final box = controller.boxAt(offset);
    if (box == null) return null;
    // Only on the box itself, not anywhere along its line.
    // The box is drawn for two characters ("[" and its mark).
    final rects = editable.getBoxesForSelection(
      TextSelection(baseOffset: box, extentOffset: box + 2),
    );
    if (rects.isEmpty) return null;
    final local = editable.globalToLocal(position);
    final rect = rects.first.toRect().inflate(12);
    return rect.contains(local) ? box : null;
  }

  static RenderEditable? _findEditable(RenderObject? root) {
    if (root == null) return null;
    if (root is RenderEditable) return root;
    RenderEditable? found;
    root.visitChildren((child) => found ??= _findEditable(child));
    return found;
  }
}

/// Claims a touch at once when it lands on a checkbox's box, so the text
/// field underneath doesn't start editing; rejects every other touch.
class _BoxTapRecognizer extends OneSequenceGestureRecognizer {
  int? Function(Offset position)? boxAt;
  ValueChanged<int>? onTap;

  int? _box;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _box == null && (boxAt?.call(event.position) != null);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _box = boxAt?.call(event.position);
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) {
      final box = _box;
      if (box != null) onTap?.call(box);
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) => _box = null;

  @override
  String get debugDescription => 'checkbox tap';
}
