import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A scrolling list with a *reach mode* for one-handed use (U3): pulling
/// the list down while it's already at its top shifts it down, so its first
/// rows come within thumb reach.
///
/// - Entering takes a new gesture that starts at the top: scrolling towards
///   the top from further down stops at the normal top, as usual.
/// - In reach mode the list stays shifted; any scroll the other way leaves
///   the mode and the list snaps back to its normal top. There's no
///   half-way position: a small pull springs back.
/// - Short lists work the same: they're padded below to a screen's height.
///
/// Under a [PullDownReset], the list also returns to its normal top when the
/// reset fires (e.g. on going to the section again, G13).
class PullDownList extends StatefulWidget {
  /// How far the list shifts down in reach mode, as a share of its height.
  static const reach = 0.2;

  /// How far a pull from the top must go to enter reach mode.
  static const enterDistance = 24.0;

  final List<Widget> slivers;

  /// Space below the last row (e.g. to clear floating buttons).
  final double bottomSpace;

  /// How far beyond the screen rows are built (see
  /// [ScrollView.cacheExtent]); larger keeps rows ready for [reveal].
  final double? cacheExtent;

  const PullDownList({
    super.key,
    required this.slivers,
    this.bottomSpace = 0,
    this.cacheExtent,
  });

  /// A plain list of [children] (like a `ListView`), with reach mode.
  PullDownList.children({
    super.key,
    required List<Widget> children,
    this.bottomSpace = 0,
  })  : slivers = [SliverList.list(children: children)],
        cacheExtent = null;

  /// Scrolls the list around [row] just enough to show it whole, with
  /// [obscuredBottom] of the list's bottom treated as covered (e.g. by a
  /// sheet). Leaves reach mode if needed; never moves into its space.
  static void reveal(BuildContext row, {double obscuredBottom = 0}) {
    row
        .findAncestorStateOfType<_PullDownListState>()
        ?._reveal(row, obscuredBottom);
  }

  @override
  State<PullDownList> createState() => _PullDownListState();
}

class _PullDownListState extends State<PullDownList> {
  ScrollController? _controller;

  /// Height of the space above the list (the reach-mode shift). Fixed once
  /// known, so the list doesn't jump when the visible height changes (e.g.
  /// the keyboard).
  double? _top;

  /// In reach mode: shifted down, first rows in thumb reach.
  bool _inReach = false;

  /// Whether the current gesture started with the list at its normal top
  /// (or in reach mode): only then may it move into the space above.
  bool _gestureFromTop = false;

  /// Where the current gesture started.
  double _gestureStart = 0;

  Listenable? _reset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reset = PullDownReset.maybeOf(context);
    if (!identical(reset, _reset)) {
      _reset?.removeListener(_toTop);
      _reset = reset?..addListener(_toTop);
    }
  }

  @override
  void dispose() {
    _reset?.removeListener(_toTop);
    _controller?.dispose();
    super.dispose();
  }

  /// Back to the normal top, out of reach mode.
  void _toTop() {
    _inReach = false;
    final controller = _controller, top = _top;
    if (controller == null || top == null || !controller.hasClients) return;
    if (controller.offset < top) controller.jumpTo(top);
  }

  void _animateTo(double offset) {
    // After the notification: the scroll that just ended must finish.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _controller;
      if (!mounted || controller == null || !controller.hasClients) return;
      controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _reveal(BuildContext row, double obscuredBottom) {
    final controller = _controller, top = _top;
    final box = row.findRenderObject();
    if (controller == null || top == null || box == null) return;
    if (!controller.hasClients || !box.attached) return;
    final viewport = RenderAbstractViewport.of(box);
    final position = controller.position;
    final atTop = viewport.getOffsetToReveal(box, 0).offset;
    final atBottom =
        viewport.getOffsetToReveal(box, 1).offset + obscuredBottom;
    final double target;
    if (position.pixels > atTop) {
      target = atTop;
    } else if (position.pixels < atBottom) {
      target = atBottom;
    } else {
      return; // already in view
    }
    _inReach = false;
    controller.animateTo(
      target.clamp(top, math.max(top, position.maxScrollExtent)),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// May the list move into the space above its rows right now?
  bool get _spaceAllowed => _inReach || _gestureFromTop;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final top = _top!, offset = notification.metrics.pixels;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _gestureStart = offset;
      _gestureFromTop = _inReach || (offset - top).abs() < 0.5;
    } else if (notification is ScrollEndNotification) {
      if (_inReach) {
        // Any scroll in reach mode leaves it: back to the normal top, or
        // on into the list if it was scrolled that far.
        if (offset > _gestureStart + 0.5) {
          _inReach = false;
          if (offset < top) _animateTo(top);
        }
      } else if (offset < top - 0.5) {
        // A pull from the top: far enough enters reach mode, else back.
        _inReach = top - offset >= PullDownList.enterDistance;
        _animateTo(_inReach ? 0 : top);
      }
      _gestureFromTop = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final top =
            _top ??= (box.maxHeight * PullDownList.reach).floorToDouble();
        final controller =
            _controller ??= ScrollController(initialScrollOffset: top);
        return NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: CustomScrollView(
            controller: controller,
            cacheExtent: widget.cacheExtent,
            physics: _ReachPhysics(
              top: top,
              spaceAllowed: () => _spaceAllowed,
            ),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: top)),
              ...widget.slivers,
              // At least enough below the rows that the list can always be
              // scrolled up to its normal top.
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final rows = constraints.precedingScrollExtent - top;
                  final fill = math.max(
                    widget.bottomSpace,
                    constraints.viewportMainAxisExtent - rows,
                  );
                  return SliverToBoxAdapter(child: SizedBox(height: fill));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Scrolls as usual, except that the space above the rows (offsets below
/// [top]) is a wall unless [spaceAllowed]: scrolling towards the top from
/// further down stops at the normal top.
class _ReachPhysics extends ScrollPhysics {
  final double top;
  final bool Function() spaceAllowed;

  const _ReachPhysics({
    required this.top,
    required this.spaceAllowed,
    super.parent,
  });

  @override
  _ReachPhysics applyTo(ScrollPhysics? ancestor) => _ReachPhysics(
        top: top,
        spaceAllowed: spaceAllowed,
        parent: buildParent(
          const AlwaysScrollableScrollPhysics().applyTo(ancestor),
        ),
      );

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (!spaceAllowed() && value < top && value < position.pixels) {
      // Moving into the space above: stop at the normal top.
      return position.pixels <= top ? value - position.pixels : value - top;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

/// Sends [PullDownList]s below it back to their normal top whenever
/// [signal] fires (e.g. the home screen fires it on going to a section).
class PullDownReset extends InheritedWidget {
  final Listenable signal;

  const PullDownReset({super.key, required this.signal, required super.child});

  static Listenable? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PullDownReset>()?.signal;

  @override
  bool updateShouldNotify(PullDownReset old) => signal != old.signal;
}
