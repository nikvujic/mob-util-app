import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/picture_crop.dart';
import 'package:the_app/core/screen.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/document_item.dart';
import 'package:the_app/pages/hub/document_pictures.dart';
import 'package:the_app/providers/documents_provider.dart';

/// The crop step: a frame dragged over [picture] (shown turned) to take
/// its barcode. Its corners resize it, its middle moves it. Pops the crop
/// (a PNG), or null if cancelled.
class BarcodeCropPage extends ConsumerStatefulWidget {
  final DocPicture picture;

  const BarcodeCropPage({super.key, required this.picture});

  @override
  ConsumerState<BarcodeCropPage> createState() => _BarcodeCropPageState();
}

/// Which part of the frame a drag took.
enum _Grip { move, topLeft, topRight, bottomLeft, bottomRight }

class _BarcodeCropPageState extends ConsumerState<BarcodeCropPage> {
  /// The frame, as a fraction of the shown picture: a wide band in the
  /// middle to start (a barcode's shape).
  Rect _area = const Rect.fromLTRB(0.1, 0.35, 0.9, 0.65);

  /// The picture's shown size, once read.
  Size? _size;
  _Grip? _grip;
  bool _saving = false;

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
    final size = await pictureSize(bytes);
    if (mounted) setState(() => _size = turnedSize(size, widget.picture.turns));
  }

  /// Where the picture sits in [box] (contained, centred).
  Rect _shown(Size box) {
    final size = _size!;
    final scale = (box.width / size.width) < (box.height / size.height)
        ? box.width / size.width
        : box.height / size.height;
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
    setState(() => _area = a);
  }

  Future<void> _done() async {
    setState(() => _saving = true);
    final bytes = await ref
        .read(documentsProvider.notifier)
        .readPicture(widget.picture.id);
    Uint8List? crop;
    if (bytes != null) {
      crop = await cropPicture(bytes, turns: widget.picture.turns, area: _area);
    }
    if (mounted) Navigator.of(context).pop(crop);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: ViewerColours.background,
      appBar: AppBar(
        backgroundColor: ViewerColours.background,
        foregroundColor: ViewerColours.foreground,
        title: const Text('Frame the barcode'),
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
                  FilledButton.icon(
                    key: const Key('barcodeCropDone'),
                    // Cutting it out takes a moment on a big picture.
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Use this'),
                    onPressed: _size == null || _saving ? null : _done,
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

/// A barcode shown to be scanned: full screen on white, the screen at
/// full brightness and kept on; both given back when it closes. A tap
/// closes it.
class ShowBarcodePage extends StatefulWidget {
  final String barcodeId;
  final String title;

  const ShowBarcodePage({super.key, required this.barcodeId, this.title = ''});

  @override
  State<ShowBarcodePage> createState() => _ShowBarcodePageState();
}

class _ShowBarcodePageState extends State<ShowBarcodePage> {
  @override
  void initState() {
    super.initState();
    KeepScreenOn.hold();
    FullBrightness.on();
  }

  @override
  void dispose() {
    FullBrightness.off();
    KeepScreenOn.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ViewerColours.paper,
        appBar: AppBar(
          backgroundColor: ViewerColours.paper,
          foregroundColor: ViewerColours.ink,
          title: Text(widget.title),
        ),
        body: GestureDetector(
          key: const Key('shownBarcode'),
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DocThumb(
                picture: DocPicture(widget.barcodeId),
                cacheWidth: 2000,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
}
