import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/models/people_layout.dart';
import 'package:the_app/widgets/people_avatar.dart';

/// The People page's board (Round 108, spec 4–5): everyone as a box on a
/// plane you pan and zoom, their family lines under them. A tap on a
/// person centres on them; dragging one moves them, their family
/// following once the drag goes far (spec 5.3). People glide to new
/// places, and a new relation's line draws itself in.
class PeopleBoard extends StatefulWidget {
  final PeopleBook book;
  final DateTime now;
  final String? selectedId;

  /// A person tapped (centred on), or the empty board (null).
  final ValueChanged<String?> onTap;

  /// People dragged to new places (board units).
  final ValueChanged<Map<String, (double, double)>> onMoved;

  /// Where it's looking now, after a pan, zoom or centring.
  final ValueChanged<BoardView> onView;

  const PeopleBoard({
    super.key,
    required this.book,
    required this.now,
    required this.selectedId,
    required this.onTap,
    required this.onMoved,
    required this.onView,
  });

  @override
  State<PeopleBoard> createState() => PeopleBoardState();
}

class PeopleBoardState extends State<PeopleBoard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Where each person is drawn (board units), gliding to where they are.
  final _shown = <String, Offset>{};

  /// New relations' lines, drawing in (0 → 1).
  final _lineIn = <String, double>{};
  late Set<String> _relations = {for (final r in widget.book.relations) r.id};

  late Offset _center = Offset(widget.book.view.x, widget.book.view.y);
  late double _zoom = widget.book.view.zoom;
  Offset? _centerTo;
  Size _size = Size.zero;

  // Dragging a person: who, where from, and their family as it was.
  String? _dragId;
  Offset _dragStart = Offset.zero;
  final _dragFrom = <String, Offset>{};
  Set<String> _partners = const {};

  /// Where the last finger went down: a drag or pan starts there, not
  /// where it's noticed (past the touch slop), so nothing jumps.
  Offset _downAt = Offset.zero;

  // Panning and zooming.
  Offset _panFocal = Offset.zero;
  Offset _panCenter = Offset.zero;
  double _panZoom = 1;

  static const _glide = 12.0; // per second
  static const _lineTime = 0.45; // seconds

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    for (final p in widget.book.people) {
      _shown[p.id] = Offset(p.x, p.y);
    }
  }

  @override
  void didUpdateWidget(PeopleBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = {for (final p in widget.book.people) p.id};
    _shown.removeWhere((id, _) => !ids.contains(id));
    for (final p in widget.book.people) {
      _shown.putIfAbsent(p.id, () => Offset(p.x, p.y));
    }
    final relations = {for (final r in widget.book.relations) r.id};
    for (final id in relations.difference(_relations)) {
      _lineIn[id] = 0;
    }
    _relations = relations;
    _wake();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Offset _target(Person p) => Offset(p.x, p.y);

  void _wake() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    final k = 1 - math.exp(-_glide * dt);
    var moving = false;
    for (final p in widget.book.people) {
      if (p.id == _dragId || _dragFrom.containsKey(p.id)) continue;
      final at = _shown[p.id]!, to = _target(p);
      if ((to - at).distance < 0.2) {
        _shown[p.id] = to;
      } else {
        _shown[p.id] = Offset.lerp(at, to, k)!;
        moving = true;
      }
    }
    for (final id in [..._lineIn.keys]) {
      final p = _lineIn[id]! + dt / _lineTime;
      if (p >= 1) {
        _lineIn.remove(id);
      } else {
        _lineIn[id] = p;
        moving = true;
      }
    }
    final to = _centerTo;
    if (to != null) {
      if ((to - _center).distance * _zoom < 0.5) {
        _center = to;
        _centerTo = null;
        _reportView();
      } else {
        _center = Offset.lerp(_center, to, k)!;
        moving = true;
      }
    }
    setState(() {});
    if (!moving) _ticker.stop();
  }

  void _reportView() =>
      widget.onView(BoardView(x: _center.dx, y: _center.dy, zoom: _zoom));

  /// Glides the board to [id] in its middle (a tap, or Find).
  void centerOn(String id) {
    final p = widget.book.byId(id);
    if (p == null) return;
    _centerTo = _target(p);
    _wake();
  }

  Offset _toWorld(Offset screen) =>
      (screen - _size.center(Offset.zero)) / _zoom + _center;

  static double _scaleOf(Person p) => p.highlighted ? 1.1 : 1;

  Rect _rectOf(Person p) => Rect.fromCenter(
        center: _shown[p.id] ?? _target(p),
        width: BoardSizes.boxWidth * _scaleOf(p),
        height: BoardSizes.boxHeight * _scaleOf(p),
      );

  /// The person at [screen], the one drawn on top first.
  String? _personAt(Offset screen) {
    final at = _toWorld(screen);
    for (final p in widget.book.people.reversed) {
      if (_rectOf(p).contains(at)) return p.id;
    }
    return null;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _centerTo = null;
    final one = d.pointerCount == 1;
    final id = one ? _personAt(_downAt) : null;
    if (id != null) {
      _dragId = id;
      _dragStart = _toWorld(_downAt);
      _dragFrom.clear();
      for (final f in widget.book.familyOf(id)) {
        _dragFrom[f] = _shown[f]!;
      }
      _partners = widget.book.partnersOf(id).toSet();
      return;
    }
    _dragId = null;
    _panFocal = one ? _downAt : d.localFocalPoint;
    _panCenter = _center;
    _panZoom = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final id = _dragId;
    if (id != null) {
      final moved = _toWorld(d.localFocalPoint) - _dragStart;
      setState(() {
        for (final MapEntry(key: f, value: from) in _dragFrom.entries) {
          final pull = f == id
              ? 1.0
              : familyPull(moved.distance, partner: _partners.contains(f));
          _shown[f] = from + moved * pull;
        }
      });
      return;
    }
    setState(() {
      _zoom = (_panZoom * d.scale).clamp(BoardView.minZoom, BoardView.maxZoom);
      final mid = _size.center(Offset.zero);
      final held = (_panFocal - mid) / _panZoom + _panCenter;
      _center = held - (d.localFocalPoint - mid) / _zoom;
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final id = _dragId;
    if (id == null) {
      _reportView();
      return;
    }
    final moved = {
      for (final f in _dragFrom.keys)
        if (_shown[f] != _dragFrom[f]) f: (_shown[f]!.dx, _shown[f]!.dy),
    };
    _dragId = null;
    _dragFrom.clear();
    if (moved.isNotEmpty) widget.onMoved(moved);
  }

  void _onTapUp(TapUpDetails d) {
    final id = _personAt(d.localPosition);
    if (id != null) centerOn(id);
    widget.onTap(id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(builder: (context, constraints) {
      _size = constraints.biggest;
      final mid = _size.center(Offset.zero);
      Offset toScreen(Offset w) => (w - _center) * _zoom + mid;
      return ClipRect(
        child: Listener(
          onPointerDown: (e) => _downAt = e.localPosition,
          child: GestureDetector(
            key: const Key('peopleBoard'),
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onTapUp: _onTapUp,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LinesPainter(
                      book: widget.book,
                      shown: _shown,
                      lineIn: _lineIn,
                      center: _center,
                      zoom: _zoom,
                      line: colors.textSecondary,
                      label: colors.textSecondary,
                    ),
                  ),
                ),
                for (final p in widget.book.people)
                  () {
                    final r = _rectOf(p);
                    final at = toScreen(r.topLeft);
                    return Positioned(
                      key: Key('person-${p.id}'),
                      left: at.dx,
                      top: at.dy,
                      width: r.width * _zoom,
                      height: r.height * _zoom,
                      child: FittedBox(
                        child: SizedBox(
                          width: r.width,
                          height: r.height,
                          child: _PersonBox(
                            person: p,
                            now: widget.now,
                            selected: p.id == widget.selectedId,
                          ),
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// A person's box (spec 4.2): face, name, age; a plain grey border, or
/// their colour when highlighted, grey when deceased, the accent when
/// selected.
class _PersonBox extends StatelessWidget {
  final Person person;
  final DateTime now;
  final bool selected;

  const _PersonBox({
    required this.person,
    required this.now,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final p = person;
    final female = p.gender == Gender.female;
    final age = p.ageAt(now);
    final b = p.birthday;
    final String line;
    if (p.deceased) {
      final died = p.diedOn?.year;
      line = [b?.year, died].every((y) => y == null)
          ? ''
          : '${b?.year ?? '?'}–${died ?? '?'}';
    } else {
      line = age != null ? '$age' : (b == null ? '' : '${b.day}.${b.month}.');
    }
    final birthdayToday =
        !p.deceased && b != null && b.day == now.day && b.month == now.month;
    final border = selected
        ? colors.accent
        : p.highlighted && !p.deceased
            ? (female ? PeopleColours.female : PeopleColours.male)
            : colors.divider;
    final strong = p.highlighted || selected;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: strong ? 3 : 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
        child: Column(
          children: [
            PeopleAvatar(
              age: p.ageGroupAt(now).index,
              female: female,
              grey: p.deceased,
              size: 78,
            ),
            const SizedBox(height: 6),
            Text(
              p.deceased ? '† ${p.name}' : p.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.15,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: p.deceased || !strong
                    ? colors.textSecondary
                    : colors.textPrimary,
              ),
            ),
            if (line.isNotEmpty || birthdayToday)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (birthdayToday)
                    Icon(Icons.cake, size: 12, color: colors.accent),
                  Text(
                    line,
                    style: TextStyle(fontSize: 11, color: colors.textHint),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The relations' lines (spec 5.2), in board units: partners joined side
/// by side; one line from a couple (or a lone parent) down to a bar their
/// children hang from; a bar over siblings; a thin line for others, with
/// its word.
class _LinesPainter extends CustomPainter {
  final PeopleBook book;
  final Map<String, Offset> shown;
  final Map<String, double> lineIn;
  final Offset center;
  final double zoom;
  final Color line;
  final Color label;

  _LinesPainter({
    required this.book,
    required this.shown,
    required this.lineIn,
    required this.center,
    required this.zoom,
    required this.line,
    required this.label,
  });

  Rect? _rect(String id) {
    final p = book.byId(id);
    final at = shown[id];
    if (p == null || at == null) return null;
    final s = p.highlighted ? 1.1 : 1.0;
    return Rect.fromCenter(
      center: at,
      width: BoardSizes.boxWidth * s,
      height: BoardSizes.boxHeight * s,
    );
  }

  /// [path] drawn as far as [progress] (a new line drawing in), dashed if
  /// [dashed].
  void _draw(Canvas canvas, Path path, Paint paint,
      {double progress = 1, bool dashed = false}) {
    for (final PathMetric m in path.computeMetrics()) {
      final end = m.length * progress;
      if (!dashed) {
        canvas.drawPath(m.extractPath(0, end), paint);
        continue;
      }
      for (var d = 0.0; d < end; d += 12) {
        canvas.drawPath(m.extractPath(d, math.min(d + 7, end)), paint);
      }
    }
  }

  /// Partners side by side: from the right of the left one to the left of
  /// the other (bent at the middle if they aren't level).
  Path _sideBySide(Rect a, Rect b) {
    final (l, r) = a.center.dx <= b.center.dx ? (a, b) : (b, a);
    final from = Offset(l.right, l.center.dy), to = Offset(r.left, r.center.dy);
    final midX = (from.dx + to.dx) / 2;
    return Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(midX, from.dy)
      ..lineTo(midX, to.dy)
      ..lineTo(to.dx, to.dy);
  }

  double _progress(Iterable<String> relationIds) =>
      relationIds.map((id) => lineIn[id] ?? 1.0).fold(1.0, math.min);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-center.dx, -center.dy);
    final paint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    // Partners.
    for (final r in book.relations) {
      if (r.kind != RelationKind.partner) continue;
      final a = _rect(r.from), b = _rect(r.to);
      if (a == null || b == null) continue;
      _draw(canvas, _sideBySide(a, b), paint,
          progress: _progress([r.id]), dashed: r.former);
    }

    // Children, grouped by their parents: one line down, one bar.
    final groups = <String, (List<String>, List<String>)>{};
    for (final p in book.people) {
      final parents = book.parentsOf(p.id)..sort();
      if (parents.isEmpty) continue;
      (groups[parents.join('+')] ??= (parents, [])).$2.add(p.id);
    }
    for (final (parents, children) in groups.values) {
      final rects = [for (final id in parents) _rect(id)].nonNulls.toList();
      final kids = [for (final id in children) _rect(id)].nonNulls.toList();
      if (rects.isEmpty || kids.isEmpty) continue;
      final ids = [
        for (final r in book.relations)
          if (r.kind == RelationKind.parent &&
              parents.contains(r.from) &&
              children.contains(r.to))
            r.id,
      ];
      final progress = _progress(ids);
      final Offset origin;
      if (rects.length == 2) {
        final joined = book.partnersOf(parents[0]).contains(parents[1]);
        // Two parents not partners: joined all the same, for their line.
        if (!joined) {
          _draw(canvas, _sideBySide(rects[0], rects[1]), paint,
              progress: progress);
        }
        origin = Offset(
          (rects[0].center.dx + rects[1].center.dx) / 2,
          (rects[0].center.dy + rects[1].center.dy) / 2,
        );
      } else {
        origin = rects[0].bottomCenter;
      }
      final parentsBottom = rects.map((r) => r.bottom).reduce(math.max);
      final kidsTop = kids.map((r) => r.top).reduce(math.min);
      final barY = kidsTop > parentsBottom
          ? (parentsBottom + kidsTop) / 2
          : kidsTop - BoardSizes.gap / 2;
      final xs = [origin.dx, for (final k in kids) k.center.dx];
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(origin.dx, barY)
        ..moveTo(xs.reduce(math.min), barY)
        ..lineTo(xs.reduce(math.max), barY);
      for (final k in kids) {
        path
          ..moveTo(k.center.dx, barY)
          ..lineTo(k.center.dx, k.top);
      }
      _draw(canvas, path, paint, progress: progress);
    }

    // Siblings (with no parents entered): a bar over them.
    for (final r in book.relations) {
      if (r.kind != RelationKind.sibling) continue;
      final a = _rect(r.from), b = _rect(r.to);
      if (a == null || b == null) continue;
      final barY = math.min(a.top, b.top) - BoardSizes.gap / 2;
      final path = Path()
        ..moveTo(a.center.dx, a.top)
        ..lineTo(a.center.dx, barY)
        ..lineTo(b.center.dx, barY)
        ..lineTo(b.center.dx, b.top);
      _draw(canvas, path, paint, progress: _progress([r.id]));
    }

    // Others: thin, straight, with their word.
    final thin = Paint()
      ..color = line.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final r in book.relations) {
      if (r.kind != RelationKind.other) continue;
      final a = _rect(r.from), b = _rect(r.to);
      if (a == null || b == null) continue;
      _draw(
          canvas,
          Path()
            ..moveTo(a.center.dx, a.center.dy)
            ..lineTo(b.center.dx, b.center.dy),
          thin,
          progress: _progress([r.id]));
      if (r.label.isEmpty) continue;
      final text = TextPainter(
        text: TextSpan(
          text: r.label,
          style: TextStyle(color: label, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = Offset.lerp(a.center, b.center, 0.5)!;
      text.paint(canvas, at - Offset(text.width / 2, text.height + 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinesPainter old) => true;
}
