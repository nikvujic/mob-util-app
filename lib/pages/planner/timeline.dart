import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/providers/preferences_provider.dart';
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

  /// Whether it has a reminder (P10): shown with a bell.
  final bool reminds;
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
    this.reminds = false,
    this.selected = false,
    this.onLongPress,
    this.onToggleDone,
  });
}

/// A stretch of a block's time: [shared] while a block of the other kind (a
/// routine beside a task, or the other way round) is there too.
typedef BlockPiece = ({int start, int end, bool shared});

/// [block]'s time cut where a block of the other kind among [blocks] starts
/// or ends beside it (P12). Blocks of the same kind never overlap, so at
/// most two share any moment: the task on the left, the routine on the
/// right; alone, a block takes the full width.
List<BlockPiece> blockPieces(
  TimelineBlock block,
  Iterable<TimelineBlock> blocks,
) {
  final others = [
    for (final b in blocks)
      if (b.repeats != block.repeats &&
          b.start < block.end &&
          block.start < b.end)
        b,
  ];
  final cuts = {
    block.start,
    block.end,
    for (final o in others) ...[
      if (block.start < o.start) o.start,
      if (o.end < block.end) o.end,
    ],
  }.toList()
    ..sort();
  final pieces = <BlockPiece>[];
  for (var i = 0; i + 1 < cuts.length; i++) {
    final (start, end) = (cuts[i], cuts[i + 1]);
    final shared = others.any((o) => o.start < end && start < o.end);
    if (pieces.isNotEmpty && pieces.last.shared == shared) {
      pieces.last = (start: pieces.last.start, end: end, shared: shared);
    } else {
      pieces.add((start: start, end: end, shared: shared));
    }
  }
  return pieces;
}

/// How tall a [PlannerTimeline] is (Nikola: short blocks were too small to
/// read or tick). One bottom button cycles through them, no pinch (two
/// fingers, against the one-hand rule); the choice is remembered.
enum TimelineZoom {
  /// A 30-minute block is one touch target high.
  normal(1, 'Normal', labelEvery: 60),

  /// A 15-minute block is.
  large(2, 'Large', labelEvery: 30),

  /// A 5-minute block (the shortest there is) is.
  extraLarge(6, 'Extra large', labelEvery: 15);

  final int _factor;
  final String label;

  /// Minutes between time labels.
  final int labelEvery;

  const TimelineZoom(this._factor, this.label, {required this.labelEvery});

  double get hourHeight => PlannerTimeline.hourHeight * _factor;

  /// The next size, round to the first.
  TimelineZoom get next => values[(index + 1) % values.length];

  /// The zoom saved as [name]; normal if unknown.
  static TimelineZoom fromName(String? name) =>
      values.firstWhere((z) => z.name == name, orElse: () => normal);
}

/// The saved timeline zoom; rebuilds when it changes.
TimelineZoom watchZoom(WidgetRef ref) =>
    TimelineZoom.fromName(ref.watch(preferencesProvider).plannerZoom);

/// The zoom button (a bottom action): the next size, keeping the time in
/// the middle of [timeline] where it is.
BottomAction zoomAction(WidgetRef ref, ScrollController timeline) {
  final zoom = watchZoom(ref);
  final next = zoom.next;
  return BottomAction(
    icon: next == TimelineZoom.normal ? Icons.zoom_out : Icons.zoom_in,
    tooltip: 'Zoom: ${zoom.label}',
    onPressed: () {
      ref.read(preferencesProvider.notifier).setPlannerZoom(next.name);
      if (!timeline.hasClients) return;
      final before = timeline.position;
      final middle = before.pixels + before.viewportDimension / 2;
      // The minute in the middle, as a share of an hour's height.
      final hours =
          (middle - PlannerTimeline.offsetOf(0, zoom)) / zoom.hourHeight;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!timeline.hasClients) return;
        final after = timeline.position;
        final y = PlannerTimeline.offsetOf(0, next) + hours * next.hourHeight;
        timeline.jumpTo((y - after.viewportDimension / 2)
            .clamp(after.minScrollExtent, after.maxScrollExtent));
      });
    },
  );
}

/// A day's timeline (P7): hour marks from 00:00 to 24:00, [blocks] and the
/// free time between them, which can be tapped to add something there.
/// A task and a routine at the same time sit side by side (P12).
class PlannerTimeline extends StatelessWidget {
  /// Height of one hour at normal zoom: a 30-minute block (less the gap
  /// between blocks) is one touch target (48 dp) high.
  static const hourHeight = 108.0;

  /// Space between blocks that touch (half above, half below each).
  static const gap = 6.0;

  static const _labelWidth = 56.0;

  /// Space above 00:00, so its label (centred on the line) isn't cut off.
  static const _topInset = 12.0;

  final List<TimelineBlock> blocks;

  /// Null while selecting.
  final ValueChanged<FreeSlot>? onAdd;

  /// What adding in free time makes, for screen readers ("a task").
  final String adds;

  final TimelineZoom zoom;

  const PlannerTimeline({
    super.key,
    required this.blocks,
    required this.onAdd,
    this.adds = 'a task',
    this.zoom = TimelineZoom.normal,
  });

  /// Where [minutes] past midnight is on the timeline at [zoom].
  static double offsetOf(int minutes, TimelineZoom zoom) =>
      _topInset + minutes * zoom.hourHeight / 60;

  double _y(int minutes) => offsetOf(minutes, zoom);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      // Room below 24:00 so the last hours can scroll clear of buttons.
      height: _y(PlannerTask.dayMinutes) + BottomActions.contentClearance,
      child: Stack(
        children: [
          // Hours, and in between when zoomed in.
          for (var minutes = 0;
              minutes <= PlannerTask.dayMinutes;
              minutes += zoom.labelEvery)
            Positioned(
              top: _y(minutes) - 8,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    SizedBox(
                      width: _labelWidth,
                      child: Text(
                        formatMinutes(minutes),
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
            if (slot.end - slot.start >= PlannerTask.minMinutes)
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
              child: _Block(
                block,
                pieces: blockPieces(block, blocks),
                hourHeight: zoom.hourHeight,
              ),
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
        padding: const EdgeInsets.symmetric(vertical: PlannerTimeline.gap / 2),
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
///
/// Beside a block of the other kind it narrows to its half (a task left, a
/// routine right) and widens again where it goes on alone: one shape,
/// made of its [pieces] (P12). The title, time and checkbox go in the
/// tallest piece.
class _Block extends StatelessWidget {
  final TimelineBlock block;
  final List<BlockPiece> pieces;
  final double hourHeight;

  const _Block(
    this.block, {
    required this.pieces,
    required this.hourHeight,
  });

  /// [pieces] as rectangles in the block's box of [size] (already inset
  /// by half the gap above and below): side by side, the gap between them
  /// too; none between a block's own pieces.
  List<Rect> _rects(Size size) {
    final perMinute = hourHeight / 60;
    const gap = PlannerTimeline.gap;
    double y(int minutes) =>
        ((minutes - block.start) * perMinute - gap / 2).clamp(0.0, size.height);
    final half = size.width / 2;
    return [
      for (final piece in pieces)
        Rect.fromLTRB(
          !piece.shared || !block.repeats ? 0 : half + gap / 2,
          y(piece.start),
          !piece.shared || block.repeats ? size.width : half - gap / 2,
          y(piece.end),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final range = '${formatMinutes(block.start)}–${formatMinutes(block.end)}';
    final hasCheckbox = block.onToggleDone != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PlannerTimeline.gap / 2),
      child: LayoutBuilder(
        builder: (context, box) {
          final rects = _rects(box.biggest);
          // The tallest piece; of equal ones, the widest.
          final content = rects.reduce(
            (a, b) => b.height > a.height ||
                    (b.height == a.height && b.width > a.width)
                ? b
                : a,
          );
          // Short blocks put everything on one line.
          final compact = content.height < 56;
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
          final time = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  range,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ),
              if (block.reminds)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.notifications_none,
                    size: 14,
                    color: colors.textSecondary,
                    semanticLabel: 'Reminder',
                  ),
                ),
            ],
          );
          final color = block.color;
          return SelectableCard(
            selected: block.selected,
            color: color?.fill,
            shape: _PiecesBorder(rects),
            onTap: block.onTap,
            onLongPress: block.onLongPress ?? block.onTap,
            child: Stack(
              children: [
                // A coloured block has a bright stripe on its left edge.
                if (color != null)
                  for (final rect in rects)
                    Positioned(
                      left: rect.left,
                      top: rect.top,
                      height: rect.height,
                      width: 4,
                      child: ColoredBox(color: color.stripe),
                    ),
                Positioned.fromRect(
                  rect: content,
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            12, 4, hasCheckbox ? 48 : 12, 4),
                        child: compact
                            ? Row(
                                children: [
                                  Flexible(child: title),
                                  const SizedBox(width: 8),
                                  Flexible(child: time),
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
                            materialTapTargetSize: content.height < 48
                                ? MaterialTapTargetSize.shrinkWrap
                                : MaterialTapTargetSize.padded,
                            visualDensity: content.height < 48
                                ? VisualDensity.compact
                                : null,
                            onChanged: (_) => block.onToggleDone!(),
                          ),
                        ),
                    ],
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

/// The outline of a block made of [rects] stacked top to bottom (see
/// [_Block]): rounded on its outer corners only, so its pieces read as one.
class _PiecesBorder extends OutlinedBorder {
  static const _radius = Radius.circular(6);

  /// Within the painted box, from its top left.
  final List<Rect> rects;

  const _PiecesBorder(this.rects, {super.side});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  _PiecesBorder copyWith({BorderSide? side}) =>
      _PiecesBorder(rects, side: side ?? this.side);

  @override
  ShapeBorder scale(double t) => _PiecesBorder(rects, side: side.scale(t));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path? outline;
    for (final (i, r) in rects.indexed) {
      if (r.isEmpty) continue;
      final above = i > 0 ? rects[i - 1] : null;
      final below = i + 1 < rects.length ? rects[i + 1] : null;
      // A corner is outside unless the piece next to it covers it.
      Radius corner(Rect? next, {required bool left}) => next == null ||
              next.isEmpty ||
              (left ? next.left > r.left : next.right < r.right)
          ? _radius
          : Radius.zero;
      final piece = Path()
        ..addRRect(RRect.fromRectAndCorners(
          r.shift(rect.topLeft),
          topLeft: corner(above, left: true),
          topRight: corner(above, left: false),
          bottomLeft: corner(below, left: true),
          bottomRight: corner(below, left: false),
        ));
      outline = outline == null
          ? piece
          : Path.combine(PathOperation.union, outline, piece);
    }
    return outline ?? Path();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  /// The outline drawn inside the shape (it never changes its size).
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    final outline = getOuterPath(rect);
    canvas
      ..save()
      ..clipPath(outline)
      ..drawPath(outline, side.toPaint()..strokeWidth = side.width * 2)
      ..restore();
  }

  @override
  bool operator ==(Object other) =>
      other is _PiecesBorder &&
      other.side == side &&
      listEquals(other.rects, rects);

  @override
  int get hashCode => Object.hash(side, Object.hashAll(rects));
}
