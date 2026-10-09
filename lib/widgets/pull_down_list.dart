import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A scrolling list that can be pulled down past its top, into empty space,
/// so its top items come within thumb reach (one-handed use, U3).
///
/// It opens at its normal top; the empty space is above it, scrolled out of
/// view. Pulling down reveals it and the list stays where it's left.
/// Scrolling back up returns to the normal top, and settles there if it
/// comes to rest just short of it (U4). Short lists can be pulled too:
/// they're padded below to at least a screen's height.
///
/// Under a [PullDownReset], the list also returns to its normal top when
/// the reset fires (e.g. on going to the section again, G13).
class PullDownList extends StatefulWidget {
  /// How much of the visible height can be pulled down.
  static const reach = 0.4;

  /// When scrolling up comes to rest with less than this share of the
  /// pulled-down space left, the list settles at its normal top.
  static const snapBack = 0.35;

  final List<Widget> slivers;

  /// Space below the last row (e.g. to clear floating buttons).
  final double bottomSpace;

  const PullDownList({
    super.key,
    required this.slivers,
    this.bottomSpace = 0,
  });

  @override
  State<PullDownList> createState() => _PullDownListState();
}

class _PullDownListState extends State<PullDownList> {
  ScrollController? _controller;

  /// Height of the space above the list. Fixed once known, so the list
  /// doesn't jump when the visible height changes (e.g. the keyboard).
  double? _top;

  /// Direction of the user's last scroll: [ScrollDirection.reverse] is
  /// towards later rows (scrolling "up" through the list).
  ScrollDirection _lastDirection = ScrollDirection.idle;

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

  /// Back to the normal top, if pulled down.
  void _toTop() {
    final controller = _controller, top = _top;
    if (controller == null || top == null || !controller.hasClients) return;
    if (controller.offset < top) controller.jumpTo(top);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _lastDirection = notification.direction;
    } else if (notification is ScrollEndNotification) {
      final top = _top!, offset = notification.metrics.pixels;
      final gap = top - offset;
      if (_lastDirection == ScrollDirection.reverse &&
          gap > 0 &&
          gap <= top * PullDownList.snapBack) {
        // After this notification: the scroll that just ended must finish.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final controller = _controller;
          if (!mounted || controller == null || !controller.hasClients) {
            return;
          }
          controller.animateTo(
            top,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        });
      }
      _lastDirection = ScrollDirection.idle;
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
            physics: const AlwaysScrollableScrollPhysics(),
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
