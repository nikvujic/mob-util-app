import 'package:flutter/material.dart';
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
        MdRole.listMarker => s.copyWith(
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
    bool shown(MdRun run) =>
        run.role != MdRole.marker ||
        (run.start >= revealed.start && run.end <= revealed.end);
    final spans = <TextSpan>[];
    for (final run in markdownRuns(text)) {
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
      for (var i = 0; i < cuts.length - 1; i++) {
        final from = cuts[i], to = cuts[i + 1];
        final inWord = from >= composing.start && to <= composing.end;
        spans.add(
          TextSpan(
            text: text.substring(from, to),
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
