import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A scrolling list that can be pulled down past its top, into empty space,
/// so its top items come within thumb reach (one-handed use, U3).
///
/// It opens at its normal top; the empty space is above it, scrolled out of
/// view. Pulling down reveals it and the list stays where it's left;
/// scrolling back up returns to the normal top. Short lists can be pulled
/// too: they're padded below to at least a screen's height.
class PullDownList extends StatefulWidget {
  /// How much of the visible height can be pulled down.
  static const reach = 0.4;

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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final top =
            _top ??= (box.maxHeight * PullDownList.reach).floorToDouble();
        final controller =
            _controller ??= ScrollController(initialScrollOffset: top);
        return CustomScrollView(
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
        );
      },
    );
  }
}
