import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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
