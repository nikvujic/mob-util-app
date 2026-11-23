import 'dart:math';
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/barcode_reader.dart';

/// The barcode reader (pure Dart): shop barcodes and QR codes, drawn by
/// the same library the app draws them with, then read back, also
/// mirrored (held upside down), noisy, unevenly lit and small.
void main() {
  /// [code] saying [data], drawn [module] pixels a bar unit (a QR code
  /// [module] pixels a square), with a white margin; noise, uneven light,
  /// upside down if asked.
  GreyImage draw(
    Barcode code,
    String data, {
    double module = 3,
    int noise = 0,
    bool gradient = false,
    bool upsideDown = false,
    int seed = 1,
  }) {
    final qr = code.name == Barcode.qrCode().name;
    // Its size in units: a drawing at one pixel a unit.
    final probe = code.make(data, width: 1000, height: 1000).toList();
    final bars = [
      for (final e in probe)
        if (e is BarcodeBar && e.black) e
    ];
    final unit = bars.map((b) => b.width).reduce(min);
    final right = bars.map((b) => b.right).reduce(max);
    final w = (right / unit).round() * module;
    final h = qr ? w : 60 * module;
    final margin = 20 * module;
    final width = (w + 2 * margin).round();
    final height = (h + 2 * margin).round();
    final pixels = Uint8List(width * height)..fillRange(0, width * height, 235);
    for (final e in code.make(data, width: w, height: h)) {
      if (e is! BarcodeBar || !e.black) continue;
      final x0 = (margin + e.left).round(), x1 = (margin + e.right).round();
      final y0 = (margin + e.top).round(), y1 = (margin + e.bottom).round();
      for (var y = y0; y < y1 && y < height; y++) {
        for (var x = x0; x < x1 && x < width; x++) {
          pixels[y * width + x] = 25;
        }
      }
    }
    final random = Random(seed);
    for (var i = 0; i < pixels.length; i++) {
      var v = pixels[i].toDouble();
      if (gradient) v = v * (0.55 + 0.45 * (i % width) / width);
      if (noise > 0) v += random.nextInt(noise * 2 + 1) - noise;
      pixels[i] = v.round().clamp(0, 255);
    }
    if (upsideDown) {
      final flipped = Uint8List(pixels.length);
      for (var i = 0; i < pixels.length; i++) {
        flipped[pixels.length - 1 - i] = pixels[i];
      }
      return GreyImage(width, height, flipped);
    }
    return GreyImage(width, height, pixels);
  }

  final cases = [
    (Barcode.ean13(), '4006381333931', CodeFormat.ean13, '4006381333931'),
    (Barcode.ean13(), '8600043001235', CodeFormat.ean13, '8600043001235'),
    (Barcode.ean8(), '96385074', CodeFormat.ean8, '96385074'),
    (Barcode.upcA(), '036000291452', CodeFormat.upcA, '036000291452'),
    (Barcode.code128(), 'LOYALTY-0042', CodeFormat.code128, 'LOYALTY-0042'),
    (Barcode.code128(), '12345678901234', CodeFormat.code128, '12345678901234'),
    (Barcode.code128(), 'ab12CD 34ef', CodeFormat.code128, 'ab12CD 34ef'),
  ];

  for (final (code, data, format, read) in cases) {
    test('${format.label} "$data": read, upside down too', () {
      // An EAN-13's last digit is its check: the library completes it.
      expect(readCode(draw(code, data)), ScannedCode(read, format));
      expect(readCode(draw(code, data, upsideDown: true)),
          ScannedCode(read, format));
    });
  }

  test('noisy, unevenly lit, small: still read', () {
    for (final (code, data, format, read) in cases) {
      expect(readCode(draw(code, data, module: 2, noise: 30, gradient: true)),
          ScannedCode(read, format),
          reason: '$format $data');
    }
  });

  test('blurred and tilted a little, as a photo: still read', () {
    GreyImage blurTilt(GreyImage g, {int radius = 1, double tilt = 0.05}) {
      final w = g.width, h = g.height;
      final out = Uint8List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          // Sheared: a few degrees' tilt.
          final sx = (x + (y - h / 2) * tilt).round();
          var sum = 0, n = 0;
          for (var dy = -radius; dy <= radius; dy++) {
            for (var dx = -radius; dx <= radius; dx++) {
              final xx = sx + dx, yy = y + dy;
              if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
              sum += g.at(xx, yy);
              n++;
            }
          }
          out[y * w + x] = n == 0 ? 235 : sum ~/ n;
        }
      }
      return GreyImage(w, h, out);
    }

    for (final (code, data, format, read) in cases) {
      expect(readCode(blurTilt(draw(code, data, module: 3, noise: 15))),
          ScannedCode(read, format),
          reason: '$format $data');
    }
  });

  test('only the formats asked for', () {
    final ean = draw(Barcode.ean13(), '4006381333931');
    expect(readCode(ean, formats: {CodeFormat.qr}), isNull);
    expect(readCode(ean, formats: {CodeFormat.code128}), isNull);
  });

  test('a QR code', () {
    final qr =
        draw(Barcode.qrCode(), 'https://example.com/ticket/7', module: 4);
    expect(readCode(qr),
        const ScannedCode('https://example.com/ticket/7', CodeFormat.qr));
    expect(readCode(qr, formats: {CodeFormat.qr}),
        const ScannedCode('https://example.com/ticket/7', CodeFormat.qr));
  });

  test('nothing to read: null', () {
    final blank =
        GreyImage(300, 200, Uint8List(300 * 200)..fillRange(0, 300 * 200, 200));
    expect(readCode(blank), isNull);
    final random = Random(3);
    final noise = GreyImage(
        300,
        200,
        Uint8List.fromList(
            List.generate(300 * 200, (_) => random.nextInt(256))));
    expect(readCode(noise), isNull);
  });
}
