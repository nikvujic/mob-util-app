import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:the_app/core/theme.dart';

/// Line numbers beside a multi-line [TextField] (N12), like a code editor:
/// one number per paragraph (text between line breaks), level with its
/// first row on screen; a wrapped paragraph keeps one number.
///
/// Place it left of the field (e.g. in a [Row]); [field] is the field's
/// key and [scroll] its scroll controller. The numbers are read from the
/// field's own layout, so headings, wrapping and hidden symbols all line
/// up. Screen readers skip them: they're only a visual aid.
class LineNumbers extends LeafRenderObjectWidget {
  final TextEditingController controller;
  final ScrollController scroll;
  final GlobalKey field;

  const LineNumbers({
    super.key,
    required this.controller,
    required this.scroll,
    required this.field,
  });

  @override
  RenderLineNumbers createRenderObject(BuildContext context) =>
      RenderLineNumbers(
        controller: controller,
        scroll: scroll,
        field: field,
        style: _style(context),
        textScaler: MediaQuery.textScalerOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLineNumbers renderObject,
  ) {
    renderObject
      ..controller = controller
      ..scroll = scroll
      ..field = field
      ..style = _style(context)
      ..textScaler = MediaQuery.textScalerOf(context);
  }

  static TextStyle _style(BuildContext context) => TextStyle(
        color: context.colors.textMuted,
        fontSize: 12,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Paints the [LineNumbers].
class RenderLineNumbers extends RenderBox {
  /// Space right of the numbers, before the text.
  static const gap = 8.0;

  RenderLineNumbers({
    required TextEditingController controller,
    required ScrollController scroll,
    required GlobalKey field,
    required TextStyle style,
    required TextScaler textScaler,
  })  : _controller = controller,
        _scroll = scroll,
        _field = field,
        _style = style,
        _textScaler = textScaler;

  TextEditingController _controller;
  set controller(TextEditingController value) {
    if (identical(value, _controller)) return;
    if (attached) _controller.removeListener(_changed);
    _controller = value;
    if (attached) _controller.addListener(_changed);
    _changed();
  }

  ScrollController _scroll;
  set scroll(ScrollController value) {
    if (identical(value, _scroll)) return;
    if (attached) _scroll.removeListener(markNeedsPaint);
    _scroll = value;
    if (attached) _scroll.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  GlobalKey _field;
  set field(GlobalKey value) {
    _field = value;
    markNeedsPaint();
  }

  TextStyle _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    markNeedsLayout();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    markNeedsLayout();
  }

  /// The numbers last painted, with the middle of their row: for tests.
  @visibleForTesting
  List<({int number, double y})> painted = const [];

  int get _lineCount => '\n'.allMatches(_controller.text).length + 1;

  /// Width depends on the digits needed; relayout only when that changes.
  int _digits = 0;

  void _changed() {
    final digits = '$_lineCount'.length;
    if (digits != _digits) markNeedsLayout();
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(_changed);
    _scroll.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _controller.removeListener(_changed);
    _scroll.removeListener(markNeedsPaint);
    super.detach();
  }

  TextPainter _painter(String text) => TextPainter(
        text: TextSpan(text: text, style: _style),
        textDirection: TextDirection.ltr,
        textScaler: _textScaler,
      )..layout();

  @override
  void performLayout() {
    _digits = '$_lineCount'.length;
    // At least two digits wide, so it doesn't jump at line 10.
    final widest = _painter('8' * (_digits < 2 ? 2 : _digits));
    size = constraints.constrain(
      Size(widest.width + gap, constraints.maxHeight),
    );
    widest.dispose();
  }

  /// The field's text layout, if it's on screen.
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

    final root = _field.currentContext?.findRenderObject();
    if (root != null) visit(root);
    return found;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final editable = _editable();
    final painted = <({int number, double y})>[];
    this.painted = painted;
    if (editable == null || !editable.hasSize || !editable.attached) return;

    // From the field's coordinates to this box's.
    final shift = globalToLocal(editable.localToGlobal(Offset.zero));
    final canvas = context.canvas
      ..save()
      ..clipRect(offset & size);
    final text = _controller.text;
    var number = 1;
    for (var start = 0; start <= text.length;) {
      final row = editable
          .getLocalRectForCaret(TextPosition(offset: start))
          .shift(shift);
      if (row.top > size.height) break; // the rest is below the screen
      if (row.bottom >= 0) {
        final label = _painter('$number');
        final y = row.center.dy;
        label.paint(
          canvas,
          offset + Offset(size.width - gap - label.width, y - label.height / 2),
        );
        label.dispose();
        painted.add((number: number, y: y));
      }
      final next = text.indexOf('\n', start);
      if (next == -1) break;
      start = next + 1;
      number++;
    }
    canvas.restore();
  }
}
