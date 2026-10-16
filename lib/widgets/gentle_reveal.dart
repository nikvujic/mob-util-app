import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A scroll controller whose jumps (a text field's `showOnScreen`,
/// revealing the caret) go at most [step] at a time while [gentle] says
/// so (Round 61: dragging a selection's handle past the note's top or
/// bottom made it race a screen at a time, so it overshot and jumped
/// about; now it creeps along with the finger). Scrolling by hand isn't
/// a jump: it's left alone.
class GentleRevealController extends ScrollController {
  final bool Function() gentle;
  final double step;

  GentleRevealController({required this.gentle, this.step = 12});

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) =>
      _GentlePosition(
        physics: physics,
        context: context,
        oldPosition: oldPosition,
        controller: this,
      );
}

class _GentlePosition extends ScrollPositionWithSingleContext {
  final GentleRevealController controller;

  _GentlePosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.controller,
  });

  @override
  void jumpTo(double value) {
    if (controller.gentle()) {
      final step = controller.step;
      value = value.clamp(pixels - step, pixels + step);
      value = math.max(minScrollExtent, math.min(maxScrollExtent, value));
    }
    super.jumpTo(value);
  }
}

/// Scrolls a text field's scroll view on while a finger holds a
/// selection's handle beyond its top or bottom (Round 61, as Android
/// does): steadily, faster the further out, the selection's end on that
/// side following along. (A handle only moves the selection as the
/// finger moves; held still past the edge, nothing happened.)
class HandleEdgeScroll {
  final ScrollController scroll;
  final TextEditingController text;

  /// The scroll view's box (its visible part).
  final GlobalKey view;

  /// The text's render object, to find a position at a point.
  final RenderEditable? Function() editable;

  HandleEdgeScroll({
    required this.scroll,
    required this.text,
    required this.view,
    required this.editable,
  });

  /// Pixels a second at most, and at the edge.
  static const fastest = 900.0;
  static const slowest = 120.0;

  late final Ticker _ticker = Ticker(_tick, debugLabel: 'HandleEdgeScroll');
  int? _pointer;
  Offset? _at;
  Duration? _last;

  void start() => GestureBinding.instance.pointerRouter.addGlobalRoute(_route);

  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
    _ticker.dispose();
  }

  void _route(PointerEvent event) {
    if (event is PointerDownEvent) {
      // A finger down with a range selected: a handle, most likely.
      if (_pointer != null || text.selection.isCollapsed) return;
      _pointer = event.pointer;
      _at = event.position;
      _last = null;
      if (!_ticker.isActive) _ticker.start();
      return;
    }
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      _at = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointer = null;
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    final at = _at;
    final box = view.currentContext?.findRenderObject() as RenderBox?;
    final field = editable();
    if (last == null || at == null || box == null || field == null) return;
    if (!box.attached || !field.attached || !scroll.hasClients) return;
    final selection = text.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final double out;
    if (at.dy < top) {
      out = at.dy - top;
    } else if (at.dy > bottom) {
      out = at.dy - bottom;
    } else {
      return;
    }
    final seconds = (elapsed - last).inMicroseconds / 1e6;
    final speed = (slowest + out.abs() * 12).clamp(slowest, fastest);
    final position = scroll.position;
    final to = (position.pixels + out.sign * speed * seconds)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (to == position.pixels) return;
    position.jumpTo(to);
    // The selection's end on that side, where the edge now is.
    final edge = Offset(at.dx, out < 0 ? top + 1 : bottom - 1);
    final offset = field.getPositionForPoint(edge).offset;
    if (out < 0 && offset < selection.end) {
      text.selection =
          TextSelection(baseOffset: offset, extentOffset: selection.end);
    } else if (out > 0 && offset > selection.start) {
      text.selection =
          TextSelection(baseOffset: selection.start, extentOffset: offset);
    }
  }
}
