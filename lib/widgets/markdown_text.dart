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
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCheckboxBoxes renderObject,
  ) {
    renderObject
      ..controller = controller
      ..colour = context.colors.accent
      ..tick = context.colors.background;
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

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final painted = <({Rect rect, bool ticked})>[];
    this.painted = painted;
    final editable = _editable();
    if (editable == null || !editable.hasSize) return;
    final toHere = editable.getTransformTo(this);
    final canvas = context.canvas;
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
