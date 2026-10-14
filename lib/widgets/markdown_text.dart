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
/// The font code is set in (Round 41): bundled, so it works offline.
const codeFont = 'JetBrainsMono';

/// How far a code block's panel reaches past the text on each side; the
/// page leaves this much room inside its scroll, so it isn't cut off.
const codeInset = 8.0;

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

  /// What stands in the text for a checkbox's `[` and its mark: a
  /// square, empty space (an em space and a zero-width one, two for two,
  /// so positions stay the same). [CheckboxBoxes] draws the box over it
  /// (Round 16): the phone's fonts drew ☐ / ☑ at their own size and
  /// colour, whatever the app asked for.
  static const boxRoom = '\u2003\u200B';

  /// The checkboxes drawn as boxes now: where each one's `[` is, and
  /// whether it's ticked. Not on the line being edited, where the symbols
  /// show instead.
  List<({int box, bool ticked})> drawnBoxes() {
    final revealed = _revealed();
    return [
      for (final run in markdownRuns(text))
        if (run.role == MdRole.checkbox &&
            !(run.start >= revealed.start && run.end <= revealed.end))
          for (var i = run.start; i < run.end - 1; i++)
            if (text[i] == '[') (box: i, ticked: text[i + 1] != ' '),
    ];
  }

  bool _onRevealed(int start, int end, TextRange revealed) =>
      !revealed.isCollapsed && start >= revealed.start && end <= revealed.end;

  /// Where each divider drawn as a line starts (N17); not on the line
  /// being edited, where its symbols show instead.
  List<int> drawnDividers() {
    final revealed = _revealed();
    return [
      for (final run in markdownRuns(text))
        if (run.role == MdRole.divider &&
            !_onRevealed(run.start, run.end, revealed))
          run.start,
    ];
  }

  /// Each quote line's bar (N17): where its `>` is and where the line
  /// ends; not on the line being edited.
  List<({int start, int end})> drawnQuoteBars() {
    final revealed = _revealed();
    return [
      for (final run in markdownRuns(text))
        if (run.role == MdRole.quoteMarker &&
            !_onRevealed(run.start, run.end, revealed))
          (start: run.start, end: _lineEnd(run.start)),
    ];
  }

  /// Each ``` code block (N17), fences included: drawn on a panel. Only
  /// closed ones (Round 29), as [markdownRuns] reads them.
  List<({int start, int end})> codeBlocks() {
    final blocks = <({int start, int end})>[];
    int? open;
    var lineStart = 0;
    while (lineStart <= text.length) {
      final end = _lineEnd(lineStart);
      if (isFence(text.substring(lineStart, end))) {
        if (open == null) {
          open = lineStart;
        } else {
          blocks.add((start: open, end: end));
          open = null;
        }
      }
      if (end >= text.length) break;
      lineStart = end + 1;
    }
    // Not closed (Round 29): not a block, just text.
    return blocks;
  }

  /// Whether a code block's ``` fences show (Round 42): while [editing]
  /// with the cursor anywhere in the block, fences included, so an empty
  /// block can be found and deleted. Elsewhere they're hidden.
  bool fencesShown(({int start, int end}) block) {
    final selection = value.selection;
    if (!_editing || !selection.isValid) return false;
    return selection.start <= block.end && selection.end >= block.start;
  }

  int _lineEnd(int from) {
    final next = text.indexOf('\n', from);
    return next == -1 ? text.length : next;
  }

  /// Heading sizes, relative to the body text: `#` to `####` (Round 27:
  /// `####` just a little bigger than the text, bold).
  static const headingScale = [1.5, 1.3, 1.15, 1.05];

  /// A bullet's dot, bigger than the text's (Round 27), at the same line
  /// height.
  static const bulletScale = 1.35;

  /// Code's size, relative to the text around it (Round 29).
  static const codeScale = 0.88;

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
      // N17: code in a fixed-width font (on a tint when inline; a block
      // gets a whole panel), highlights on the accent, quotes muted and
      // slanted.
      if (run.code) {
        // A little smaller than the text (Round 29: wide letters made it
        // hard to read).
        s = s.copyWith(
          // Round 41: JetBrains Mono, bundled with the app.
          fontFamily: codeFont,
          fontFamilyFallback: const ['monospace', 'Roboto Mono'],
          fontSize: (s.fontSize ?? 16) * codeScale,
          backgroundColor: run.block ? null : colors.card,
        );
      }
      if (run.highlight) {
        s = s.copyWith(
          backgroundColor: colors.accent.withValues(alpha: 0.3),
        );
      }
      if (run.quote) {
        s = s.copyWith(
          color: colors.textSecondary,
          fontStyle: FontStyle.italic,
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
        // Shown (muted) only on the line being edited; elsewhere drawn
        // (a bar, a line).
        MdRole.quoteMarker || MdRole.divider => s.copyWith(
            color: colors.textMuted,
            fontStyle: FontStyle.normal,
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
    // The fences of the code block the cursor is in show too (Round 42).
    final openBlocks = codeBlocks().where(fencesShown).toList();
    bool inOpenBlock(MdRun run) =>
        openBlocks.any((b) => run.start >= b.start && run.end <= b.end + 1);
    bool shown(MdRun run) =>
        run.role != MdRole.marker ||
        onRevealedLine(run) ||
        (run.block && inOpenBlock(run));
    final spans = <InlineSpan>[];
    for (final run in markdownRuns(text)) {
      // A checkbox off the line being edited: its `[` drawn as a box, the
      // other symbols as nothing, the space after it kept (N15).
      if (run.role == MdRole.checkbox && !onRevealedLine(run)) {
        for (var i = run.start; i < run.end; i++) {
          final char = text[i];
          if (char == '[') {
            // Room for the box, drawn over it by [CheckboxBoxes].
            spans.add(TextSpan(
              text: boxRoom,
              style: base.copyWith(
                color: Colors.transparent,
                letterSpacing: 0,
                decoration: TextDecoration.none,
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
      // A quote's `>` off the line being edited: room for its bar, the
      // space after it kept (N17). One character for one.
      if (run.role == MdRole.quoteMarker && !onRevealedLine(run)) {
        for (var i = run.start; i < run.end; i++) {
          spans.add(TextSpan(
            text: text[i] == '>' ? '\u2003' : text[i],
            style: base.copyWith(color: Colors.transparent),
          ));
        }
        continue;
      }
      // A divider off the line being edited: its symbols there, unseen;
      // the line is drawn across instead (N17).
      if (run.role == MdRole.divider && !onRevealedLine(run)) {
        spans.add(TextSpan(
          text: text.substring(run.start, run.end),
          style: base.copyWith(color: Colors.transparent),
        ));
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
        if (bullet && from == run.start) {
          // The dot on its own: drawn, centred on the text's middle
          // (Round 29: a bigger "•" sat above it). One character still.
          final size = style.fontSize ?? 16;
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            style: style,
            child: SizedBox(
              key: const Key('listDot'),
              width: size * 0.55,
              height: size * bulletScale * 0.3,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: style.color,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(dimension: size * bulletScale * 0.3),
                ),
              ),
            ),
          ));
          piece = piece.substring(1);
          if (piece.isEmpty) continue;
        }
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

/// Draws the checkboxes of a note's text (N15) over the field in [child]:
/// a rounded square in the accent, filled with a tick when ticked. Drawn
/// by the app, so they look the same on every phone (Round 16: the font's
/// ☐ / ☑ came out small or grey). Where they go comes from the field's
/// own layout, at the room [MarkdownEditingController] leaves for them.
class CheckboxBoxes extends SingleChildRenderObjectWidget {
  final MarkdownEditingController controller;

  const CheckboxBoxes({
    super.key,
    required this.controller,
    required Widget super.child,
  });

  @override
  RenderCheckboxBoxes createRenderObject(BuildContext context) =>
      RenderCheckboxBoxes(
        controller: controller,
        colour: context.colors.accent,
        tick: context.colors.background,
      )
        ..rule = context.colors.textMuted
        ..panel = context.colors.card;

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCheckboxBoxes renderObject,
  ) {
    renderObject
      ..controller = controller
      ..colour = context.colors.accent
      ..tick = context.colors.background
      ..rule = context.colors.textMuted
      ..panel = context.colors.card;
  }
}

/// Paints the [CheckboxBoxes] over its child.
class RenderCheckboxBoxes extends RenderProxyBox {
  RenderCheckboxBoxes({
    required MarkdownEditingController controller,
    required Color colour,
    required Color tick,
  })  : _controller = controller,
        _colour = colour,
        _tick = tick;

  MarkdownEditingController _controller;
  set controller(MarkdownEditingController value) {
    if (identical(value, _controller)) return;
    if (attached) _controller.removeListener(markNeedsPaint);
    _controller = value;
    if (attached) _controller.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color _colour;
  Color get colour => _colour;
  set colour(Color value) {
    if (value == _colour) return;
    _colour = value;
    markNeedsPaint();
  }

  Color _tick;
  set tick(Color value) {
    if (value == _tick) return;
    _tick = value;
    markNeedsPaint();
  }

  /// Dividers' lines (N17).
  Color _rule = Colors.transparent;
  set rule(Color value) {
    if (value == _rule) return;
    _rule = value;
    markNeedsPaint();
  }

  /// Code blocks' panels (N17).
  Color _panel = Colors.transparent;
  set panel(Color value) {
    if (value == _panel) return;
    _panel = value;
    markNeedsPaint();
  }

  /// The quote bars, divider lines and code panels last painted, in this
  /// box's coordinates: for tests.
  @visibleForTesting
  List<Rect> paintedBars = const [];
  @visibleForTesting
  List<Rect> paintedRules = const [];
  @visibleForTesting
  List<Rect> paintedPanels = const [];

  /// The boxes last painted, in this box's coordinates: for tests.
  @visibleForTesting
  List<({Rect rect, bool ticked})> painted = const [];

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _controller.removeListener(markNeedsPaint);
    super.detach();
  }

  RenderEditable? _editable() {
    RenderEditable? found;
    void visit(RenderObject child) {
      if (found != null) return;
      if (child is RenderEditable) {
        found = child;
      } else {
        child.visitChildren(visit);
      }
    }

    if (child != null) visit(child!);
    return found;
  }

  /// The rectangle (here) around [start] to [end] of the text, as laid out.
  Rect? _around(RenderEditable editable, Matrix4 toHere, int start, int end) {
    final rows = editable.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    if (rows.isEmpty) return null;
    var rect = rows.first.toRect();
    for (final row in rows.skip(1)) {
      rect = rect.expandToInclude(row.toRect());
    }
    return MatrixUtils.transformRect(toHere, rect);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final editable = _editable();
    final laidOut = editable != null && editable.hasSize;
    final toHere = laidOut ? editable.getTransformTo(this) : null;

    // Code blocks' panels, under the text (N17): the field's full width.
    final panels = <Rect>[];
    if (laidOut) {
      final width =
          MatrixUtils.transformRect(toHere!, Offset.zero & editable.size);
      final text = _controller.text;
      for (final block in _controller.codeBlocks()) {
        final (:start, :end) = block;
        // Round 42: around the code lines only, the same room above and
        // below: hidden fences still keep some height of their own,
        // unequal. With the fences showing (or no code), around them too.
        final first = text.indexOf('\n', start) + 1;
        final last = text.lastIndexOf('\n', end - 1);
        final codeOnly = !_controller.fencesShown(block) && first < last;
        final around = codeOnly
            ? _around(editable, toHere, first, last)
            : _around(editable, toHere, start, end);
        if (around == null) continue;
        // Round 41: room around the code ([codeInset]), rounded corners
        // that show (the field's scroll leaves room for them).
        final rect = Rect.fromLTRB(width.left - codeInset, around.top - 6,
            width.right + codeInset, around.bottom + 6);
        panels.add(rect);
        context.canvas.drawRRect(
          RRect.fromRectAndRadius(rect.shift(offset), const Radius.circular(6)),
          Paint()..color = _panel,
        );
      }
    }
    paintedPanels = panels;

    super.paint(context, offset);
    final painted = <({Rect rect, bool ticked})>[];
    this.painted = painted;
    paintedBars = const [];
    paintedRules = const [];
    if (!laidOut) return;
    final canvas = context.canvas;

    // Quotes' bars (N17): down the quoted line, in the `>`'s room.
    final bars = <Rect>[];
    for (final (:start, :end) in _controller.drawnQuoteBars()) {
      final room = _around(editable, toHere!, start, start + 1);
      final line = _around(editable, toHere, start, end);
      if (room == null || line == null) continue;
      final bar =
          Rect.fromLTWH(room.left + room.width * 0.3, line.top, 3, line.height);
      bars.add(bar);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar.shift(offset), const Radius.circular(1.5)),
        Paint()..color = _colour,
      );
    }
    paintedBars = bars;

    // Dividers (N17): a line across, through the middle of their line.
    final rules = <Rect>[];
    final width =
        MatrixUtils.transformRect(toHere!, Offset.zero & editable.size);
    for (final start in _controller.drawnDividers()) {
      final line = _around(editable, toHere, start, start + 1);
      if (line == null) continue;
      final rule =
          Rect.fromLTWH(width.left, line.center.dy - 0.75, width.width, 1.5);
      rules.add(rule);
      canvas.drawRect(rule.shift(offset), Paint()..color = _rule);
    }
    paintedRules = rules;
    for (final (:box, :ticked) in _controller.drawnBoxes()) {
      final rows = editable.getBoxesForSelection(
        TextSelection(baseOffset: box, extentOffset: box + 2),
      );
      if (rows.isEmpty) continue;
      final room = MatrixUtils.transformRect(toHere, rows.first.toRect());
      // A square a little smaller than the room, centred in it.
      final side = room.width * 0.9;
      final square = Rect.fromCenter(
        center: room.center,
        width: side,
        height: side,
      );
      painted.add((rect: square, ticked: ticked));
      final shape = RRect.fromRectAndRadius(
        square.shift(offset),
        Radius.circular(side * 0.18),
      );
      if (ticked) {
        canvas.drawRRect(shape, Paint()..color = _colour);
        final r = square.shift(offset);
        canvas.drawPath(
          Path()
            ..moveTo(r.left + side * 0.24, r.top + side * 0.52)
            ..lineTo(r.left + side * 0.43, r.top + side * 0.71)
            ..lineTo(r.left + side * 0.77, r.top + side * 0.31),
          Paint()
            ..color = _tick
            ..style = PaintingStyle.stroke
            ..strokeWidth = side * 0.13
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      } else {
        canvas.drawRRect(
          shape.deflate(side * 0.05),
          Paint()
            ..color = _colour
            ..style = PaintingStyle.stroke
            ..strokeWidth = side * 0.1,
        );
      }
    }
  }
}
