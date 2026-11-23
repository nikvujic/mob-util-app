import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:the_app/core/barcode_reader.dart';

/// A picture's size as shown: turned [turns] quarter turns clockwise.
ui.Size turnedSize(ui.Size size, int turns) =>
    turns.isOdd ? ui.Size(size.height, size.width) : size;

/// The part [area] of a picture (its [bytes], a JPEG or PNG), as shown:
/// turned [turns] quarter turns clockwise first. [area] is a fraction of
/// the turned picture (0–1 each way). The crop is a PNG, at the picture's
/// own resolution (a barcode stays sharp).
Future<Uint8List> cropPicture(
  Uint8List bytes, {
  required int turns,
  required ui.Rect area,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  final w = image.width.toDouble(), h = image.height.toDouble();
  final shown = turnedSize(ui.Size(w, h), turns);
  final fraction = area.intersect(const ui.Rect.fromLTRB(0, 0, 1, 1));
  final crop = ui.Rect.fromLTRB(
    (fraction.left * shown.width).floorToDouble(),
    (fraction.top * shown.height).floorToDouble(),
    (fraction.right * shown.width).ceilToDouble(),
    (fraction.bottom * shown.height).ceilToDouble(),
  );
  final width = math.max(1, crop.width.round());
  final height = math.max(1, crop.height.round());

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..translate(-crop.left, -crop.top);
  // The picture turned into the shown one's place.
  switch (turns % 4) {
    case 1:
      canvas
        ..translate(h, 0)
        ..rotate(math.pi / 2);
    case 2:
      canvas
        ..translate(w, h)
        ..rotate(math.pi);
    case 3:
      canvas
        ..translate(0, w)
        ..rotate(3 * math.pi / 2);
  }
  canvas.drawImage(image, ui.Offset.zero, ui.Paint());
  final picture = recorder.endRecording();
  final cropped = await picture.toImage(width, height);
  picture.dispose();
  image.dispose();
  final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
  cropped.dispose();
  return png!.buffer.asUint8List();
}

/// A picture's own size (before turning).
Future<ui.Size> pictureSize(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final size =
      ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  descriptor.dispose();
  buffer.dispose();
  return size;
}

/// The part [area] of a picture as shown (turned [turns] first), as grey
/// levels, at most [maxSide] pixels on its long side (enough to read a
/// code, and quick).
Future<GreyImage> greyPicture(
  Uint8List bytes, {
  int turns = 0,
  ui.Rect area = const ui.Rect.fromLTRB(0, 0, 1, 1),
  int maxSide = 1600,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  final w = image.width.toDouble(), h = image.height.toDouble();
  final shown = turnedSize(ui.Size(w, h), turns);
  final f = area.intersect(const ui.Rect.fromLTRB(0, 0, 1, 1));
  final crop = ui.Rect.fromLTRB(f.left * shown.width, f.top * shown.height,
      f.right * shown.width, f.bottom * shown.height);
  final long = math.max(crop.width, crop.height);
  final scale = long > maxSide ? maxSide / long : 1.0;
  final width = math.max(1, (crop.width * scale).round());
  final height = math.max(1, (crop.height * scale).round());
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..scale(scale)
    ..translate(-crop.left, -crop.top);
  switch (turns % 4) {
    case 1:
      canvas
        ..translate(h, 0)
        ..rotate(math.pi / 2);
    case 2:
      canvas
        ..translate(w, h)
        ..rotate(math.pi);
    case 3:
      canvas
        ..translate(0, w)
        ..rotate(3 * math.pi / 2);
  }
  canvas.drawImage(image, ui.Offset.zero,
      ui.Paint()..filterQuality = ui.FilterQuality.medium);
  final picture = recorder.endRecording();
  final drawn = await picture.toImage(width, height);
  picture.dispose();
  image.dispose();
  final rgba = await drawn.toByteData(format: ui.ImageByteFormat.rawRgba);
  drawn.dispose();
  return GreyImage.fromRgba(width, height, rgba!.buffer.asUint8List());
}

/// Reads a code in [area] of a picture (as shown), else in the whole of
/// it (a frame drawn too tight); null if none is found. The reading runs
/// off the app's main thread.
Future<ScannedCode?> scanPicture(
  Uint8List bytes, {
  int turns = 0,
  ui.Rect area = const ui.Rect.fromLTRB(0, 0, 1, 1),
  required Set<CodeFormat> formats,
}) async {
  const whole = ui.Rect.fromLTRB(0, 0, 1, 1);
  for (final part in {area, whole}) {
    final grey = await greyPicture(bytes, turns: turns, area: part);
    final found = await Isolate.run(() => readCode(grey, formats: formats));
    if (found != null) return found;
  }
  return null;
}
