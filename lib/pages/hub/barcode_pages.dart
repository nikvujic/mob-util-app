import 'dart:math' as math;

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/barcode_reader.dart';
import 'package:the_app/core/picture_crop.dart';
import 'package:the_app/core/screen.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/pages/hub/document_pictures.dart';
import 'package:the_app/providers/documents_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// What a kind's code is looked for as: a QR code's only QR; the others
/// any (a shop barcode first).
Set<CodeFormat> formatsFor(DocKind kind) =>
    kind == DocKind.qr ? const {CodeFormat.qr} : const {...CodeFormat.values};

/// What the crop step gave: the crop (a PNG of its own) and, if *Scan
/// this* read it, what it says.
typedef BarcodeCrop = ({Uint8List crop, ScannedCode? scanned});

/// The crop step: a frame dragged over [picture] (shown turned) to take
/// its barcode; square for a QR code. Its corners resize it, its middle
/// moves it. *Use this* keeps the crop as it is; *Scan this* reads the
/// code in it first (or else in the whole picture) and says so if there's
/// none. Pops the result, or null if cancelled.
class BarcodeCropPage extends ConsumerStatefulWidget {
  final DocPicture picture;
  final DocKind kind;

  const BarcodeCropPage({
    super.key,
    required this.picture,
    this.kind = DocKind.barcode,
  });

  @override
  ConsumerState<BarcodeCropPage> createState() => _BarcodeCropPageState();
}

/// Which part of the frame a drag took.
enum _Grip { move, topLeft, topRight, bottomLeft, bottomRight }

class _BarcodeCropPageState extends ConsumerState<BarcodeCropPage> {
  /// The frame, as a fraction of the shown picture: a wide band in the
  /// middle to start (a barcode's shape), a square for a QR code.
  Rect _area = const Rect.fromLTRB(0.1, 0.35, 0.9, 0.65);

  /// The picture's shown size, once read.
  Size? _size;
  _Grip? _grip;
  bool _saving = false;
  bool _scanning = false;

  bool get _square => widget.kind.squareCrop;

  static const _smallest = 0.05;

  @override
  void initState() {
    super.initState();
    _readSize();
  }

  Future<void> _readSize() async {
    final bytes = await ref
        .read(documentsProvider.notifier)
        .readPicture(widget.picture.id);
    if (bytes == null) return;
    final size = turnedSize(await pictureSize(bytes), widget.picture.turns);
    if (!mounted) return;
    setState(() {
      _size = size;
      if (_square) {
        // 60% of the shorter side, in the middle.
        final side = 0.6 * math.min(size.width, size.height);
        final w = side / size.width, h = side / size.height;
        _area = Rect.fromLTWH((1 - w) / 2, (1 - h) / 2, w, h);
      }
    });
  }

  /// Where the picture sits in [box] (contained, centred).
  Rect _shown(Size box) {
    final size = _size!;
    final scale = math.min(box.width / size.width, box.height / size.height);
    final w = size.width * scale, h = size.height * scale;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  Rect _frame(Rect shown) => Rect.fromLTRB(
        shown.left + _area.left * shown.width,
        shown.top + _area.top * shown.height,
        shown.left + _area.right * shown.width,
        shown.top + _area.bottom * shown.height,
      );

  void _start(Offset at, Rect shown) {
    final frame = _frame(shown);
    const reach = 36.0;
    bool near(Offset corner) => (corner - at).distance < reach;
    _grip = near(frame.topLeft)
        ? _Grip.topLeft
        : near(frame.topRight)
            ? _Grip.topRight
            : near(frame.bottomLeft)
                ? _Grip.bottomLeft
                : near(frame.bottomRight)
                    ? _Grip.bottomRight
                    : _Grip.move;
  }

  void _drag(Offset by, Rect shown) {
    final dx = by.dx / shown.width, dy = by.dy / shown.height;
    var a = _area;
    switch (_grip) {
      case _Grip.move:
        final x = (a.left + dx).clamp(0.0, 1 - a.width);
        final y = (a.top + dy).clamp(0.0, 1 - a.height);
        a = Rect.fromLTWH(x, y, a.width, a.height);
      case _Grip.topLeft:
        a = Rect.fromLTRB((a.left + dx).clamp(0.0, a.right - _smallest),
            (a.top + dy).clamp(0.0, a.bottom - _smallest), a.right, a.bottom);
      case _Grip.topRight:
        a = Rect.fromLTRB(a.left, (a.top + dy).clamp(0.0, a.bottom - _smallest),
            (a.right + dx).clamp(a.left + _smallest, 1.0), a.bottom);
      case _Grip.bottomLeft:
        a = Rect.fromLTRB((a.left + dx).clamp(0.0, a.right - _smallest), a.top,
            a.right, (a.bottom + dy).clamp(a.top + _smallest, 1.0));
      case _Grip.bottomRight:
        a = Rect.fromLTRB(
            a.left,
            a.top,
            (a.right + dx).clamp(a.left + _smallest, 1.0),
            (a.bottom + dy).clamp(a.top + _smallest, 1.0));
      case null:
        return;
    }
    if (_square && _grip != _Grip.move) a = _squared(a);
    setState(() => _area = a);
  }

  /// [a] made square on the picture, kept at the corner opposite the one
  /// dragged, and inside the picture.
  Rect _squared(Rect a) {
    final size = _size!;
    final px = Rect.fromLTRB(a.left * size.width, a.top * size.height,
        a.right * size.width, a.bottom * size.height);
    var side = math.max(px.width, px.height);
    final (ax, ay) = switch (_grip) {
      _Grip.topLeft => (px.right, px.bottom),
      _Grip.topRight => (px.left, px.bottom),
      _Grip.bottomLeft => (px.right, px.top),
      _ => (px.left, px.top),
    };
    final grows = switch (_grip) {
      _Grip.topLeft => (-1.0, -1.0),
      _Grip.topRight => (1.0, -1.0),
      _Grip.bottomLeft => (-1.0, 1.0),
      _ => (1.0, 1.0),
    };
    // Room towards the dragged corner.
    final roomX = grows.$1 < 0 ? ax : size.width - ax;
    final roomY = grows.$2 < 0 ? ay : size.height - ay;
    side = math.min(side, math.min(roomX, roomY));
    final left = grows.$1 < 0 ? ax - side : ax;
    final top = grows.$2 < 0 ? ay - side : ay;
    return Rect.fromLTWH(left / size.width, top / size.height,
        side / size.width, side / size.height);
  }

  Future<Uint8List?> _picture() =>
      ref.read(documentsProvider.notifier).readPicture(widget.picture.id);

  Future<void> _done() async {
    setState(() => _saving = true);
    final bytes = await _picture();
    BarcodeCrop? result;
    if (bytes != null) {
      result = (
        crop:
            await cropPicture(bytes, turns: widget.picture.turns, area: _area),
        scanned: null,
      );
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final bytes = await _picture();
    final scanned = bytes == null
        ? null
        : await scanPicture(bytes,
            turns: widget.picture.turns,
            area: _area,
            formats: formatsFor(widget.kind));
    if (!mounted) return;
    if (scanned == null) {
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        // Above the buttons, so they can still be tapped.
        ..showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 88),
          content: Text("No code found. Frame it closer, or use the picture "
              'as it is.'),
        ));
      return;
    }
    final crop =
        await cropPicture(bytes!, turns: widget.picture.turns, area: _area);
    if (mounted) Navigator.of(context).pop((crop: crop, scanned: scanned));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final busy = _size == null || _saving || _scanning;
    Widget progress() => const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    return Scaffold(
      backgroundColor: ViewerColours.background,
      appBar: AppBar(
        backgroundColor: ViewerColours.background,
        foregroundColor: ViewerColours.foreground,
        title: Text(_square ? 'Frame the QR code' : 'Frame the barcode'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _size == null
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(builder: (context, box) {
                      final shown = _shown(box.biggest);
                      return GestureDetector(
                        key: const Key('barcodeCropArea'),
                        onPanStart: (d) => _start(d.localPosition, shown),
                        onPanUpdate: (d) => _drag(d.delta, shown),
                        onPanEnd: (_) => _grip = null,
                        child: Stack(
                          children: [
                            Positioned.fromRect(
                              rect: shown,
                              child: DocThumb(
                                picture: widget.picture,
                                cacheWidth: 2000,
                                fit: BoxFit.fill,
                              ),
                            ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _FramePainter(
                                  frame: _frame(shown),
                                  shade: ViewerColours.background
                                      .withValues(alpha: 0.55),
                                  edge: colors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: ViewerColours.foreground),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    key: const Key('barcodeCropUse'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: ViewerColours.foreground),
                    icon: _saving ? progress() : const Icon(Icons.crop),
                    label: const Text('Use this'),
                    onPressed: busy ? null : _done,
                  ),
                  const SizedBox(width: 8),
                  // Reading it can take a moment on a big picture.
                  FilledButton.icon(
                    key: const Key('barcodeCropScan'),
                    icon: _scanning
                        ? progress()
                        : const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan this'),
                    onPressed: busy ? null : _scan,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The frame: the picture shaded outside it, its edge and corners drawn.
class _FramePainter extends CustomPainter {
  final Rect frame;
  final Color shade;
  final Color edge;

  _FramePainter({required this.frame, required this.shade, required this.edge});

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(outside, Paint()..color = shade);
    final line = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(frame, line);
    final corner = Paint()..color = edge;
    for (final c in [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight
    ]) {
      canvas.drawCircle(c, 8, corner);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.shade != shade || old.edge != edge;
}

/// A document's code as the reader's: null if it's of a kind this app
/// can't draw (a newer app's).
ScannedCode? scannedOf(DocCode? code) => switch (code) {
      null => null,
      _ => switch (CodeFormat.fromId(code.format)) {
          null => null,
          final f => ScannedCode(code.text, f),
        },
    };

/// The reader's code, as a document keeps it.
DocCode docCodeOf(ScannedCode code) => DocCode(code.text, code.format.name);

/// A code drawn sharp from what it says, black on white, its number
/// under it.
class DrawnCode extends StatelessWidget {
  final ScannedCode code;

  const DrawnCode({super.key, required this.code});

  static Barcode _drawer(CodeFormat format) => switch (format) {
        CodeFormat.ean13 => Barcode.ean13(),
        CodeFormat.ean8 => Barcode.ean8(),
        CodeFormat.upcA => Barcode.upcA(),
        CodeFormat.code128 => Barcode.code128(),
        CodeFormat.qr => Barcode.qrCode(),
      };

  @override
  Widget build(BuildContext context) {
    final linear = code.format.linear;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: linear ? 2.4 : 1,
          child: CustomPaint(
            key: Key('drawnCode-${code.format.name}'),
            painter: _CodePainter(_drawer(code.format), code.text),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          code.text,
          key: const Key('drawnCodeText'),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ViewerColours.ink,
            fontSize: linear ? 20 : 14,
            letterSpacing: linear ? 2 : 0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _CodePainter extends CustomPainter {
  final Barcode drawer;
  final String text;

  _CodePainter(this.drawer, this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = ViewerColours.ink;
    try {
      for (final e
          in drawer.make(text, width: size.width, height: size.height)) {
        if (e is BarcodeBar && e.black) {
          canvas.drawRect(Rect.fromLTWH(e.left, e.top, e.width, e.height), ink);
        }
      }
    } on BarcodeException {
      // Not drawable as this kind: left blank (the photo is there).
    }
  }

  @override
  bool shouldRepaint(_CodePainter old) =>
      old.text != text || old.drawer.name != drawer.name;
}

/// A document's barcode shown to be scanned, on white, the screen kept on
/// and as bright as last set (75% at first; the slider at the bottom
/// left changes it). A drag anywhere moves it up or down; zoomed in past
/// the screen's sides, also left and right (never past its edges).
/// Pinch, or tap twice and drag (down: in, up: out), to zoom. Where it's
/// left is shown again next time; the button at the bottom right puts it
/// back. The one beside it switches between the code drawn from what it
/// says and its photo (reading it first, if it hasn't been).
class ShowBarcodePage extends ConsumerStatefulWidget {
  final String documentId;

  const ShowBarcodePage({super.key, required this.documentId});

  @override
  ConsumerState<ShowBarcodePage> createState() => _ShowBarcodePageState();
}

class _ShowBarcodePageState extends ConsumerState<ShowBarcodePage> {
  late double _brightness = ref.read(preferencesProvider).barcodeBrightness;
  late CodeView _view = _item?.codeView ?? CodeView.centred;
  bool _scanning = false;

  /// The pointers down, and the gesture they make.
  final _pointers = <int, Offset>{};
  bool _zoomDrag = false;
  DateTime? _lastTapAt;
  Offset? _lastTapAt2;
  DateTime? _downAt;
  Offset? _downPos;
  double _moved = 0;

  /// The viewport and the code's own width in it.
  Size _box = Size.zero;

  static const _minScale = 0.4, _maxScale = 6.0;

  DocItem? get _item => ref.read(documentsProvider).byId(widget.documentId);

  @override
  void initState() {
    super.initState();
    KeepScreenOn.hold();
    FullBrightness.set(_brightness);
  }

  @override
  void dispose() {
    FullBrightness.off();
    KeepScreenOn.release();
    super.dispose();
  }

  /// The code's width as laid out (before zooming).
  double get _baseWidth => math.max(0, _box.width - 32);

  CodeView _clamped(CodeView v) {
    final scale = v.scale.clamp(_minScale, _maxScale).toDouble();
    // Sideways only as far as it's wider than the screen.
    final reachX = math.max(0.0, (_baseWidth * scale - _box.width) / 2);
    final reachY = _box.height / 2;
    return CodeView(
      dx: v.dx.clamp(-reachX, reachX).toDouble(),
      dy: v.dy.clamp(-reachY, reachY).toDouble(),
      scale: scale,
    );
  }

  void _move(CodeView v) => setState(() => _view = _clamped(v));

  void _keep() {
    final item = _item;
    if (item == null || item.codeView == _view) return;
    ref.read(documentsProvider.notifier).save(item.copyWith(codeView: _view));
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      final now = DateTime.now();
      // A second tap held: dragging it zooms.
      _zoomDrag = _lastTapAt != null &&
          now.difference(_lastTapAt!) < const Duration(milliseconds: 300) &&
          (e.localPosition - _lastTapAt2!).distance < 48;
      _downAt = now;
      _downPos = e.localPosition;
      _moved = 0;
    } else {
      _zoomDrag = false;
    }
  }

  void _moveBy(PointerMoveEvent e) {
    final before = _pointers[e.pointer];
    if (before == null) return;
    if (_pointers.length >= 2) {
      final others = _pointers.entries.where((p) => p.key != e.pointer);
      final other = others.first.value;
      final was = (before - other).distance;
      final now = (e.localPosition - other).distance;
      _pointers[e.pointer] = e.localPosition;
      final focus = (e.localPosition - before) / 2;
      _move(CodeView(
        dx: _view.dx + focus.dx,
        dy: _view.dy + focus.dy,
        scale: was < 1 ? _view.scale : _view.scale * now / was,
      ));
      return;
    }
    final delta = e.localPosition - before;
    _pointers[e.pointer] = e.localPosition;
    _moved += delta.distance;
    if (_zoomDrag) {
      _move(CodeView(
        dx: _view.dx,
        dy: _view.dy,
        scale: _view.scale * math.exp(delta.dy / 150),
      ));
    } else {
      _move(CodeView(
        dx: _view.dx + delta.dx,
        dy: _view.dy + delta.dy,
        scale: _view.scale,
      ));
    }
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) return;
    final quick = _downAt != null &&
        DateTime.now().difference(_downAt!) < const Duration(milliseconds: 250);
    if (!_zoomDrag && quick && _moved < 12) {
      _lastTapAt = DateTime.now();
      _lastTapAt2 = _downPos;
    } else {
      _lastTapAt = null;
    }
    _zoomDrag = false;
    _keep();
  }

  void _reset() {
    setState(() => _view = CodeView.centred);
    _keep();
  }

  void _setBrightness(double level) {
    setState(() => _brightness = level);
    FullBrightness.set(level);
  }

  /// The drawn code or the photo; drawing one not read yet reads it first.
  Future<void> _toggle() async {
    final item = _item;
    if (item == null) return;
    final notifier = ref.read(documentsProvider.notifier);
    if (scannedOf(item.scanned) != null) {
      notifier.save(item.copyWith(showPhoto: !item.showPhoto));
      return;
    }
    setState(() => _scanning = true);
    final bytes = await notifier.readPicture(item.barcode!);
    final scanned = bytes == null
        ? null
        : await scanPicture(bytes, formats: formatsFor(item.kind));
    if (!mounted) return;
    setState(() => _scanning = false);
    if (scanned == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 88),
          content: Text("No code found in it: its photo stays. Framing it "
              'again on its picture may help.'),
        ));
      return;
    }
    final now = _item;
    if (now == null) return;
    notifier.save(
        now.copyWith(scanned: () => docCodeOf(scanned), showPhoto: false));
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(documentsProvider).byId(widget.documentId);
    final colors = context.colors;
    if (item == null || item.barcode == null) {
      return const Scaffold(backgroundColor: ViewerColours.paper);
    }
    final readable = scannedOf(item.scanned);
    final drawn = readable != null && !item.showPhoto;
    return Scaffold(
      backgroundColor: ViewerColours.paper,
      appBar: AppBar(
        backgroundColor: ViewerColours.paper,
        foregroundColor: ViewerColours.ink,
        title: Text(item.name),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                _box = box.biggest;
                final view = _clamped(_view);
                return Listener(
                  key: const Key('shownBarcode'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _down,
                  onPointerMove: _moveBy,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  child: ClipRect(
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(view.dx, view.dy),
                        child: Transform.scale(
                          key: const Key('shownBarcodeCode'),
                          scale: view.scale,
                          child: SizedBox(
                            width: _baseWidth,
                            child: drawn
                                ? DrawnCode(code: readable)
                                : DocThumb(
                                    picture: DocPicture(item.barcode!),
                                    cacheWidth: 2000,
                                    fit: BoxFit.contain,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.brightness_6_outlined, color: colors.textMuted),
                  Expanded(
                    child: Slider(
                      key: const Key('barcodeBrightness'),
                      min: 0.05,
                      max: 1,
                      value: _brightness,
                      onChanged: _setBrightness,
                      onChangeEnd: ref
                          .read(preferencesProvider.notifier)
                          .setBarcodeBrightness,
                    ),
                  ),
                  IconButton(
                    key: const Key('barcodeToggle'),
                    tooltip: drawn ? 'Show its photo' : 'Show it drawn',
                    color: ViewerColours.ink,
                    icon: _scanning
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(drawn
                            ? Icons.photo_outlined
                            : Icons.qr_code_2_outlined),
                    onPressed: _scanning ? null : _toggle,
                  ),
                  IconButton(
                    key: const Key('barcodeReset'),
                    tooltip: 'Back to the middle',
                    color: ViewerColours.ink,
                    icon: const Icon(Icons.center_focus_strong_outlined),
                    onPressed: _view.isCentred ? null : _reset,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
