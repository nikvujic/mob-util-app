import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/other_tool.dart';
import 'package:the_app/pages/other/tools.dart';
import 'package:the_app/providers/layout_provider.dart';
import 'package:the_app/widgets/main_app_bar.dart';

/// Lists additional tools as square icon tiles, filled in from the bottom
/// right (thumb reach, O3), in the order the user set (O8): hold a tile
/// and drag it to move it. Each opens as its own page on top, and back
/// returns here (O1). The tools come from [OtherTool] (O9).
class OtherPage extends ConsumerWidget {
  const OtherPage({super.key});

  static const _tileSize = 104.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(layoutProvider).other;
    final layout = ref.read(layoutProvider.notifier);
    return Scaffold(
      appBar: const MainAppBar(title: 'Other'),
      // Right to left, bottom to top: the first tool sits in the bottom
      // right corner.
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: GridView.extent(
          reverse: true,
          maxCrossAxisExtent: _tileSize,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final (index, tool) in order.indexed)
              _MovableTile(
                key: ValueKey(tool),
                tool: tool,
                // Dragged over another tile: takes its place at once.
                onHover: (dragged) => layout.moveInOther(dragged, index),
                onMove: (by) => layout.moveInOther(tool, index + by),
                canMoveBy: (by) => index + by >= 0 && index + by < order.length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => tool.page()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A tile that can be held and dragged to a new place (O8); screen readers
/// get "Move earlier" / "Move later" instead.
class _MovableTile extends StatelessWidget {
  final OtherTool tool;
  final ValueChanged<OtherTool> onHover;
  final ValueChanged<int> onMove;
  final bool Function(int by) canMoveBy;
  final VoidCallback onTap;

  const _MovableTile({
    super.key,
    required this.tool,
    required this.onHover,
    required this.onMove,
    required this.canMoveBy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = _ToolTile(icon: tool.icon, label: tool.label, onTap: onTap);
    return DragTarget<OtherTool>(
      onWillAcceptWithDetails: (details) {
        if (details.data != tool) onHover(details.data);
        return true;
      },
      builder: (context, _, __) => Semantics(
        customSemanticsActions: {
          if (canMoveBy(-1))
            const CustomSemanticsAction(label: 'Move earlier'): () =>
                onMove(-1),
          if (canMoveBy(1))
            const CustomSemanticsAction(label: 'Move later'): () => onMove(1),
        },
        child: LayoutBuilder(
          builder: (context, box) => LongPressDraggable<OtherTool>(
            data: tool,
            onDragStarted: HapticFeedback.selectionClick,
            // The tile under the finger, a little lifted.
            feedback: SizedBox(
              width: box.maxWidth,
              height: box.maxHeight,
              child: Opacity(opacity: 0.9, child: tile),
            ),
            // Its place stays marked while it moves.
            childWhenDragging: Opacity(opacity: 0.3, child: tile),
            child: tile,
          ),
        ),
      ),
    );
  }
}

/// A square tile with only an icon; its name is the tooltip and what
/// screen readers say.
class _ToolTile extends StatelessWidget {
  /// The icon: an SVG asset drawn in black, shown in the accent colour.
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      // Never on a long press: that picks the tile up to move it (O8).
      triggerMode: TooltipTriggerMode.manual,
      child: Material(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: SvgPicture.asset(
              icon,
              width: 44,
              height: 44,
              colorFilter: ColorFilter.mode(
                context.colors.accent,
                BlendMode.srcIn,
              ),
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
