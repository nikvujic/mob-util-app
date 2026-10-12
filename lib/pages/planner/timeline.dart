import 'package:flutter/foundation.dart';
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

  /// Whether it has a reminder (P10): shown with a bell.
  final bool reminds;

  /// Shown under the time when the block has room (P20).
  final String? description;
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
    this.description,
    this.selected = false,
    this.onLongPress,
    this.onToggleDone,
  });
}

/// A reminder on a [PlannerTimeline] (P14): a time, no end.
class TimelinePin {
  final String id;
  final String title;
  final int time;

  /// Null while selecting.
  final VoidCallback? onTap;

  /// Ticks it off (which deletes it); null while selecting.
  final VoidCallback? onDone;

  const TimelinePin({
    required this.id,
    required this.title,
    required this.time,
    this.onTap,
    this.onDone,
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

/// Where each minute of the day goes on a [PlannerTimeline] (Round 10): an
/// hour is [PlannerTimeline.hourHeight] tall, but a block too short for a
/// touch target stretches the timeline where it is (Nikola: that hour is a
/// bit taller than the others), so no block is squeezed. It's a picture of
/// the day, not to scale everywhere.
class TimeScale {
  /// Minutes where the scale may change (0, 24:00 and every block's start
  /// and end), and the height of the stretch after each.
  final List<int> _cuts;
  final List<double> _heights;

  TimeScale._(this._cuts, this._heights);

  /// The scale for [blocks] (their times; overlapping ones too).
  factory TimeScale.forBlocks(Iterable<TimeSpan> blocks) {
    final spans = blocks.toList()..sort((a, b) => a.start.compareTo(b.start));
    final cuts = {
      0,
      PlannerTask.dayMinutes,
      for (final b in spans) ...[b.start, b.end],
    }.toList()
      ..sort();
    const perMinute = PlannerTimeline.hourHeight / 60;
    final heights = [
      for (var i = 0; i + 1 < cuts.length; i++)
        (cuts[i + 1] - cuts[i]) * perMinute,
    ];
    // Each block gets at least its minimum: the stretches it covers grow,
    // each by its share of the block's time. Growing never undoes an
    // earlier block's minimum, so one pass is enough.
    for (final b in spans) {
      final first = cuts.indexOf(b.start);
      final last = cuts.indexOf(b.end);
      var height = 0.0;
      for (var i = first; i < last; i++) {
        height += heights[i];
      }
      final missing = PlannerTimeline.minBlockHeight - height;
      if (missing <= 0) continue;
      for (var i = first; i < last; i++) {
        heights[i] += missing * (cuts[i + 1] - cuts[i]) / (b.end - b.start);
      }
    }
    return TimeScale._(cuts, heights);
  }

  /// How far down the day [minutes] past midnight is (00:00 at 0).
  double y(int minutes) {
    var top = 0.0;
    for (var i = 0; i < _heights.length; i++) {
      final (start, end) = (_cuts[i], _cuts[i + 1]);
      if (minutes <= end) {
        return top + _heights[i] * (minutes - start) / (end - start);
      }
      top += _heights[i];
    }
    return top;
  }
}

/// A day's timeline (P7): hour marks from 00:00 to 24:00, [blocks] and the
/// free time between them, which can be tapped to add something there.
/// A task and a routine at the same time sit side by side (P12).
class PlannerTimeline extends StatelessWidget {
  /// Height of one hour: a 30-minute block (less the gap between blocks)
  /// is one touch target (48 dp) high.
  static const hourHeight = 108.0;

  /// The least room a block takes, gap included: a shorter one stretches
  /// the timeline ([TimeScale]).
  static const minBlockHeight = 48.0 + gap;

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

  /// Reminders (P14), drawn over everything at their time.
  final List<TimelinePin> pins;

  /// A reminder's height: one touch target.
  static const pinHeight = 48.0;

  final TimeScale _scale;

  PlannerTimeline({
    super.key,
    required this.blocks,
    required this.onAdd,
    this.adds = 'a task',
    this.pins = const [],
  }) : _scale = scaleFor(blocks);

  /// The [TimeScale] a timeline with [blocks] uses.
  static TimeScale scaleFor(Iterable<TimelineBlock> blocks) =>
      TimeScale.forBlocks(
          [for (final b in blocks) (start: b.start, end: b.end)]);

  /// Where each reminder goes: at its time, or just below the one before
  /// if they'd cover each other.
  List<(TimelinePin, double)> _pinPlaces() {
    final sorted = [...pins]..sort((a, b) => a.time.compareTo(b.time));
    final places = <(TimelinePin, double)>[];
    var free = 0.0;
    for (final pin in sorted) {
      final top = _y(pin.time) > free ? _y(pin.time) : free;
      places.add((pin, top));
      free = top + pinHeight + gap;
    }
    return places;
  }

  /// Where [minutes] past midnight is on a timeline with [scale].
  static double offsetOf(int minutes, TimeScale scale) =>
      _topInset + scale.y(minutes);

  double _y(int minutes) => offsetOf(minutes, _scale);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      // Room below 24:00 so the last hours can scroll clear of buttons.
      height: _y(PlannerTask.dayMinutes) + BottomActions.contentClearance,
      child: Stack(
        children: [
          for (var minutes = 0;
              minutes <= PlannerTask.dayMinutes;
              minutes += 60)
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
                y: (minutes) => _scale.y(minutes) - _scale.y(block.start),
              ),
            ),
          for (final (pin, top) in _pinPlaces())
            Positioned(
              top: top,
              height: pinHeight,
              // Indented, so what's under it still shows on the left.
              left: _labelWidth + 24,
              right: 8,
              child: _Pin(pin),
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

  /// How far down the block [minutes] is, from its start.
  final double Function(int minutes) y;

  const _Block(
    this.block, {
    required this.pieces,
    required this.y,
  });

  /// [pieces] as rectangles in the block's box of [size] (already inset
  /// by half the gap above and below): side by side, the gap between them
  /// too; none between a block's own pieces.
  List<Rect> _rects(Size size) {
    const gap = PlannerTimeline.gap;
    double at(int minutes) => (y(minutes) - gap / 2).clamp(0.0, size.height);
    final half = size.width / 2;
    return [
      for (final piece in pieces)
        Rect.fromLTRB(
          !piece.shared || !block.repeats ? 0 : half + gap / 2,
          at(piece.start),
          !piece.shared || block.repeats ? size.width : half - gap / 2,
          at(piece.end),
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
                            // The time beside the title leaves a line
                            // below for the description (Round 12).
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(child: title),
                                      const SizedBox(width: 8),
                                      Flexible(child: time),
                                    ],
                                  ),
                                  if (block.description != null)
                                    Expanded(
                                      child: _FittedLines(
                                        block.description!,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  title,
                                  time,
                                  // As many lines as fit below (P20).
                                  if (block.description != null)
                                    Expanded(
                                      child: _FittedLines(
                                        block.description!,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
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

/// A reminder (P14): a short see-through block with a dashed outline, a
/// bell, its title and time, and a checkbox that ticks it off.
class _Pin extends StatelessWidget {
  static const _radius = 6.0;

  final TimelinePin pin;

  const _Pin(this.pin);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DashedBorder(
      color: colors.accent,
      radius: _radius,
      child: Material(
        // See-through: what's under it shows a little.
        color: colors.background.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: pin.onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 18,
                  color: colors.accent,
                  semanticLabel: 'Reminder',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pin.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMinutes(pin.time),
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                Checkbox(
                  value: false,
                  semanticLabel: 'Done: ${pin.title}',
                  onChanged: pin.onDone == null ? null : (_) => pin.onDone!(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [text] in as many whole lines as fit the height it's given (none if
/// not even one does), the last one ending in "…" if it's cut.
class _FittedLines extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _FittedLines(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final scaled = MediaQuery.textScalerOf(context).scale(style.fontSize!);
        final lineHeight = scaled * 1.4;
        final lines = ((box.maxHeight - 2) / lineHeight).floor();
        if (lines < 1) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            text,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(height: 1.4),
          ),
        );
      },
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
