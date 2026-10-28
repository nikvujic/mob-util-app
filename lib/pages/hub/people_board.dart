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

  /// Round 109: people move on springs (a little past, then back) and
  /// squash a little the way they go, as if soft: each one's speed
  /// (board units a second), and that speed smoothed for the squash.
  final _vel = <String, Offset>{};
  final _jelly = <String, Offset>{};
  final _prev = <String, Offset>{};

  /// Just dropped: where they were left, until the book says so (else the
  /// first frame springs them back towards where they were).
  final _landing = <String, Offset>{};

  static const _stiffness = 170.0;
  static const _damping = 15.0; // a little under critical: one soft overshoot

  /// The zoom gliding back to 100% (a tap on the zoom handle).
  double? _zoomTo;

  /// New relations' lines, drawing in (0 → 1).
  final _lineIn = <String, double>{};
  late Set<String> _relations = {for (final r in widget.book.relations) r.id};

  // Round 109: opened on the main person, when there is one.
  late Offset _center = switch (widget.book.main) {
    final m? => Offset(m.x, m.y),
    null => Offset(widget.book.view.x, widget.book.view.y),
  };
  late double _zoom = widget.book.view.zoom;
  Offset? _centerTo;
  Size _size = Size.zero;

  // Dragging a person (Round 114: only them, nobody follows): who, and
  // where from.
  String? _dragId;
  Offset _dragStart = Offset.zero;
  final _dragFrom = <String, Offset>{};

  /// Where the last finger went down: a drag or pan starts there, not
  /// where it's noticed (past the touch slop), so nothing jumps.
  Offset _downAt = Offset.zero;

  /// A finger went down with no other on the screen, and no gesture has
  /// started from it yet.
  bool _freshDown = false;
  int _pointers = 0;

  // Panning and zooming.
  /// Round 112: a double tap held and moved zooms (as in maps): down in,
  /// up out, about where it was tapped. The last quick tap (when, where),
  /// and whether this finger is such a second tap.
  Duration? _tapAt;
  Offset _tapPos = Offset.zero;
  Duration _downTime = Duration.zero;
  bool _quickZoom = false;
  static const _doubleTapGap = Duration(milliseconds: 300);

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
    _landing.clear();
    _wake();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Offset _target(Person p) => _landing[p.id] ?? Offset(p.x, p.y);

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
    var moving = _dragId != null;
    final soften = 1 - math.exp(-18 * dt);
    for (final p in widget.book.people) {
      final at = _shown[p.id]!;
      var v = Offset.zero;
      if (p.id == _dragId || _dragFrom.containsKey(p.id)) {
        // Held: their speed is how the finger moves them.
        v = (at - (_prev[p.id] ?? at)) / dt;
        _vel[p.id] = v;
      } else {
        final to = _target(p);
        var vel = _vel[p.id] ?? Offset.zero;
        if ((to - at).distance < 0.2 && vel.distance < 4) {
          _shown[p.id] = to;
          _vel.remove(p.id);
        } else {
          // A damped spring, in small steps so a long frame stays steady.
          var x = at;
          const steps = 4;
          final h = dt / steps;
          for (var i = 0; i < steps; i++) {
            vel += ((to - x) * _stiffness - vel * _damping) * h;
            x += vel * h;
          }
          _shown[p.id] = x;
          _vel[p.id] = vel;
          v = vel;
          moving = true;
        }
      }
      _prev[p.id] = _shown[p.id]!;
      final j = Offset.lerp(_jelly[p.id] ?? Offset.zero, v, soften)!;
      if (j.distance < 2 && v == Offset.zero) {
        _jelly.remove(p.id);
      } else {
        _jelly[p.id] = j;
        moving = true;
      }
    }
    final zoomTo = _zoomTo;
    if (zoomTo != null) {
      if ((zoomTo - _zoom).abs() < 0.002) {
        _zoom = zoomTo;
        _zoomTo = null;
        _reportView();
      } else {
        _zoom += (zoomTo - _zoom) * k;
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

  // Round 109: every box the same size (highlighted ones were bigger).
  Rect _rectOf(Person p) => Rect.fromCenter(
        center: _shown[p.id] ?? _target(p),
        width: BoardSizes.boxWidth,
        height: BoardSizes.boxHeight,
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
    _zoomTo = null;
    // Round 109: only a gesture starting with a finger just down may drag
    // someone, and from where it went down; a pinch's last finger left on
    // the screen pans from where it is (it used to start at a finger's old
    // touch-down: the board, or a person, jumped).
    final one = d.pointerCount == 1 && _freshDown;
    _freshDown = false;
    if (_quickZoom && d.pointerCount == 1) {
      _dragId = null;
      _panFocal = _downAt;
      _panCenter = _center;
      _panZoom = _zoom;
      return;
    }
    final id = one ? _personAt(_downAt) : null;
    if (id != null) {
      _dragId = id;
      _dragStart = _toWorld(_downAt);
      _dragFrom
        ..clear()
        ..[id] = _shown[id]!;
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
      _wake();
      setState(() => _shown[id] = _dragFrom[id]! + moved);
      return;
    }
    if (_quickZoom) {
      setState(() {
        final mid = _size.center(Offset.zero);
        final held = (_panFocal - mid) / _panZoom + _panCenter;
        final dy = d.localFocalPoint.dy - _panFocal.dy;
        _zoom = (_panZoom * math.exp(dy / 150))
            .clamp(BoardView.minZoom, BoardView.maxZoom);
        // The tapped spot stays put.
        _center = held - (_panFocal - mid) / _zoom;
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
    for (final MapEntry(:key, value: (x, y)) in moved.entries) {
      _landing[key] = Offset(x, y);
    }
    _wake();
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
      final family = widget.book.familyShown;
      final board = ClipRect(
        child: Listener(
          onPointerDown: (e) {
            _downAt = e.localPosition;
            _downTime = e.timeStamp;
            _freshDown = ++_pointers == 1;
            final tapAt = _tapAt;
            _quickZoom = _freshDown &&
                tapAt != null &&
                e.timeStamp - tapAt < _doubleTapGap &&
                (e.localPosition - _tapPos).distance < 40;
          },
          onPointerUp: (e) {
            _pointers = math.max(0, _pointers - 1);
            // A quick tap (short, not moved) may start a double tap.
            final tap = !_quickZoom &&
                e.timeStamp - _downTime < _doubleTapGap &&
                (e.localPosition - _downAt).distance < 18;
            _tapAt = tap ? e.timeStamp : null;
            _tapPos = e.localPosition;
            _quickZoom = false;
          },
          onPointerCancel: (_) => _pointers = math.max(0, _pointers - 1),
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
                      child: Transform(
                        alignment: Alignment.center,
                        transform: _squash(_jelly[p.id]),
                        child: FittedBox(
                          child: SizedBox(
                            width: r.width,
                            height: r.height,
                            child: _PersonBox(
                              person: p,
                              now: widget.now,
                              selected: p.id == widget.selectedId,
                              zoom: _zoom,
                              main: p.id == widget.book.mainId,
                              family: family.contains(p.id),
                            ),
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
      return Stack(
        children: [
          Positioned.fill(child: board),
          Positioned(right: 12, bottom: 12, child: _zoomHandle(colors)),
        ],
      );
    });
  }

  /// Stretched the way they move, a little (up to 14%), as if soft.
  static Matrix4 _squash(Offset? velocity) {
    if (velocity == null) return Matrix4.identity();
    final s = (velocity.distance / 2000).clamp(0.0, 0.14);
    final a = velocity.direction;
    return Matrix4.identity()
      ..rotateZ(a)
      ..scale(1 + s, 1 / (1 + s))
      ..rotateZ(-a);
  }

  /// Round 109: zoom with one thumb. Pulled down, out; up, in; a tap
  /// goes back to 100%.
  Widget _zoomHandle(AppPalette colors) => GestureDetector(
        key: const Key('peopleZoom'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _centerTo = null;
          _zoomTo = 1;
          _wake();
        },
        onVerticalDragStart: (_) => _zoomTo = null,
        onVerticalDragUpdate: (d) => setState(() {
          _zoom = (_zoom * math.exp(-d.delta.dy / 120))
              .clamp(BoardView.minZoom, BoardView.maxZoom);
        }),
        onVerticalDragEnd: (_) => _reportView(),
        child: Container(
          width: 44,
          height: 72,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.expand_less, size: 18, color: colors.textSecondary),
              Text('${(_zoom * 100).round()}%',
                  key: const Key('peopleZoomLevel'),
                  style: TextStyle(fontSize: 11, color: colors.textSecondary)),
              Icon(Icons.expand_more, size: 18, color: colors.textSecondary),
            ],
          ),
        ),
      );
}

/// A person's box (spec 4.2): face, name, age; a plain grey border, or
/// their colour when highlighted, grey when deceased, the accent when
/// selected.
class _PersonBox extends StatelessWidget {
  final Person person;
  final DateTime now;
  final bool selected;

  /// The board's zoom: zoomed out, names grow and faces shrink (Round
  /// 109), so they stay readable.
  final double zoom;

  /// The main person (a star), and in their highlighted family (a ring).
  final bool main;
  final bool family;

  const _PersonBox({
    required this.person,
    required this.now,
    required this.selected,
    this.zoom = 1,
    this.main = false,
    this.family = false,
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
            : family
                ? PeopleFamilyColours.ring
                : colors.divider;
    final strong = p.highlighted || selected;
    // Text in board units, so it shrinks with the zoom: grown back as the
    // board zooms out (up to about 2.2×), the face giving way.
    // Round 111: gentler (up to 1.6×), so the face stays near its size
    // rather than dwarfed; Round 112: the name still on two lines, so a
    // first and last name are shown whole (only a long one cut short).
    final text = (1 / zoom).clamp(1.0, 1.6);
    final name = p.deceased ? '† ${p.name}' : p.name;
    final nameStyle = TextStyle(
      fontSize: 12.5 * text,
      height: 1.15,
      fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
      color: p.deceased || !strong ? colors.textSecondary : colors.textPrimary,
    );
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: family && !selected
            ? Color.alphaBlend(
                PeopleFamilyColours.ring.withValues(alpha: 0.14), colors.card)
            : colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: strong || family ? 3 : 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
        child: Column(
          children: [
            // The face gives way to the text only when room runs short.
            Flexible(
              child: FittedBox(
                child: PeopleAvatar(
                  age: p.ageGroupAt(now).index,
                  female: female,
                  grey: p.deceased,
                  size: 78,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: _fitWords(name, nameStyle, BoardSizes.boxWidth - 12),
            ),
            if (line.isNotEmpty || birthdayToday)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (birthdayToday) ...[
                    Icon(Icons.cake, size: 12 * text, color: colors.accent),
                    if (line.isNotEmpty) SizedBox(width: 4 * text),
                  ],
                  Text(
                    line,
                    style:
                        TextStyle(fontSize: 11 * text, color: colors.textHint),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
    if (!main) return box;
    // Round 111: the main person's star on the box's corner.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: box),
        Positioned(
          right: -8,
          top: -8,
          child: Icon(Icons.star,
              key: const Key('mainStar'),
              size: 24 * text,
              color: PeopleFamilyColours.ring,
              shadows: const [
                Shadow(blurRadius: 2, color: PeopleFamilyColours.starShadow)
              ]),
        ),
      ],
    );
  }
}

/// Round 112: [style] made smaller, if need be, until the longest word
/// of [text] fits [width], so a name breaks between words, never inside
/// one or cut short (only past two lines).
TextStyle _fitWords(String text, TextStyle style, double width) {
  var widest = 0.0;
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  if (widest <= width) return style;
  return style.copyWith(fontSize: style.fontSize! * width / widest * 0.98);
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
    return Rect.fromCenter(
      center: at,
      width: BoardSizes.boxWidth,
      height: BoardSizes.boxHeight,
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

    // Siblings (with no parent in common entered): a bar over them.
    for (final r in book.relations) {
      if (r.kind != RelationKind.sibling) continue;
      if (!book.drawsSiblingBar(r)) continue;
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
