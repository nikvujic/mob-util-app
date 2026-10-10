import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/dashed_border.dart';
import 'package:the_app/widgets/selection.dart';

/// A block on a [PlannerTimeline]: a task, or a routine (P8).
class TimelineBlock {
  final String id;
  final String title;
  final int start;
  final int end;
  final bool done;

  /// A routine: marked ↻.
  final bool repeats;

  /// Its colour (P9), if any.
  final BlockColor? color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Ticks it off; null: no checkbox (e.g. on the Routines screen).
  final VoidCallback? onToggleDone;

  const TimelineBlock({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.onTap,
    this.done = false,
    this.repeats = false,
    this.color,
    this.selected = false,
    this.onLongPress,
    this.onToggleDone,
  });
}

/// A day's timeline (P7): hour marks from 00:00 to 24:00, [blocks] and the
/// free time between them, which can be tapped to add something there.
class PlannerTimeline extends StatelessWidget {
  /// Height of one hour: a 30-minute block (less the gap between
  /// blocks) is one touch target (48 dp) high.
  static const hourHeight = 100.0;

  static const _labelWidth = 56.0;

  /// Free stretches shorter than this aren't offered for adding.
  static const _minFreeMinutes = 5;

  /// Space above 00:00, so its label (centred on the line) isn't cut off.
  static const _topInset = 12.0;

  final List<TimelineBlock> blocks;

  /// Null while selecting.
  final ValueChanged<FreeSlot>? onAdd;

  /// What adding in free time makes, for screen readers ("a task").
  final String adds;

  const PlannerTimeline({
    super.key,
    required this.blocks,
    required this.onAdd,
    this.adds = 'a task',
  });

  static double _y(int minutes) => _topInset + minutes * hourHeight / 60;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      // Room below 24:00 so the last hours can scroll clear of buttons.
      height: _y(PlannerTask.dayMinutes) + BottomActions.contentClearance,
      child: Stack(
        children: [
          for (var hour = 0; hour <= 24; hour++)
            Positioned(
              top: _y(hour * 60) - 8,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    SizedBox(
                      width: _labelWidth,
                      child: Text(
                        formatMinutes(hour * 60),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider(color: colors.divider, height: 16)),
                  ],
                ),
              ),
            ),
          for (final slot in freeSlotsAround([
            for (final b in blocks) (start: b.start, end: b.end),
          ]))
            if (slot.end - slot.start >= _minFreeMinutes)
              Positioned(
                top: _y(slot.start),
                height: _y(slot.end) - _y(slot.start),
                left: _labelWidth,
                right: 8,
                child: _FreeTime(
                  slot: slot,
                  adds: adds,
                  onTap: onAdd == null ? null : () => onAdd!(slot),
                ),
              ),
          for (final block in blocks)
            Positioned(
              top: _y(block.start),
              height: _y(block.end) - _y(block.start),
              left: _labelWidth,
              right: 8,
              child: _Block(block),
            ),
        ],
      ),
    );
  }
}

/// Free time: a see-through block with a dotted border, the size of the
/// gap; tapping it adds something there.
class _FreeTime extends StatelessWidget {
  /// Corners matching the blocks.
  static const _radius = 6.0;

  final FreeSlot slot;
  final String adds;
  final VoidCallback? onTap;

  const _FreeTime(
      {required this.slot, required this.adds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final range = '${formatMinutes(slot.start)}–${formatMinutes(slot.end)}';
    return Semantics(
      button: true,
      label: 'Free time, $range. Add $adds',
      excludeSemantics: true,
      child: Padding(
        // The same gap between blocks as the blocks have.
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: DashedBorder(
          color: context.colors.textHint,
          radius: _radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_radius),
            // Too short for the label: just the dotted block.
            child: LayoutBuilder(
              builder: (context, box) => box.maxHeight < 24
                  ? const SizedBox.expand()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Free · $range',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A block from its start to its end, with its title and time (↻ for a
/// routine), and a checkbox in the top-right corner to tick it off.
class _Block extends StatelessWidget {
  final TimelineBlock block;

  const _Block(this.block);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final range = '${formatMinutes(block.start)}–${formatMinutes(block.end)}';
    final hasCheckbox = block.onToggleDone != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: LayoutBuilder(
        builder: (context, box) {
          // Short blocks put everything on one line.
          final compact = box.maxHeight < 56;
          final text = Text(
            block.title,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: block.done ? colors.textSecondary : colors.textPrimary,
              fontWeight: FontWeight.w600,
              decoration: block.done ? TextDecoration.lineThrough : null,
              decorationColor: colors.textSecondary,
            ),
          );
          final Widget title = block.repeats
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.repeat,
                        size: 14,
                        color: colors.textSecondary,
                        semanticLabel: 'Routine',
                      ),
                    ),
                    Flexible(child: text),
                  ],
                )
              : text;
          final time = Text(
            range,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          );
          final color = block.color;
          return SelectableCard(
            selected: block.selected,
            color: color?.fill,
            onTap: block.onTap,
            onLongPress: block.onLongPress ?? block.onTap,
            child: Stack(
              children: [
                // A coloured block has a bright stripe on its left edge.
                if (color != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.stripe,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, hasCheckbox ? 48 : 12, 4),
                  child: compact
                      ? Row(
                          children: [
                            Flexible(child: title),
                            const SizedBox(width: 8),
                            time,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [title, time],
                        ),
                ),
                if (hasCheckbox)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Checkbox(
                      value: block.done,
                      semanticLabel: 'Done: ${block.title}',
                      // A full touch target where the block has room.
                      materialTapTargetSize: box.maxHeight < 48
                          ? MaterialTapTargetSize.shrinkWrap
                          : MaterialTapTargetSize.padded,
                      visualDensity:
                          box.maxHeight < 48 ? VisualDensity.compact : null,
                      onChanged: (_) => block.onToggleDone!(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
