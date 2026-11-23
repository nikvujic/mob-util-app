import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

/// A code's kind, as read and as drawn again. Its [name] is stored.
enum CodeFormat {
  ean13('EAN-13'),
  ean8('EAN-8'),
  upcA('UPC-A'),
  code128('Code 128'),
  qr('QR code');

  const CodeFormat(this.label);

  final String label;

  /// The lines of a shop's barcode (not a QR code's squares).
  bool get linear => this != qr;

  static CodeFormat? fromId(String? id) =>
      values.where((f) => f.name == id).firstOrNull;
}

/// A code read from a picture: what it says, and its kind.
class ScannedCode {
  final String text;
  final CodeFormat format;

  const ScannedCode(this.text, this.format);

  @override
  bool operator ==(Object other) =>
      other is ScannedCode && other.text == text && other.format == format;

  @override
  int get hashCode => Object.hash(text, format);

  @override
  String toString() => '${format.name}: $text';
}

/// A picture's grey levels (0 black – 255 white), row by row.
class GreyImage {
  final int width;
  final int height;
  final Uint8List pixels;

  GreyImage(this.width, this.height, this.pixels)
      : assert(pixels.length == width * height);

  /// From RGBA bytes (as `dart:ui` gives them).
  factory GreyImage.fromRgba(int width, int height, Uint8List rgba) {
    final grey = Uint8List(width * height);
    for (var i = 0, p = 0; i < grey.length; i++, p += 4) {
      grey[i] = (rgba[p] * 299 + rgba[p + 1] * 587 + rgba[p + 2] * 114) ~/ 1000;
    }
    return GreyImage(width, height, grey);
  }

  int at(int x, int y) => pixels[y * width + x];
}

/// Reads a code in [image] (pure Dart, on the phone, nothing sent
/// anywhere): a shop's barcode (EAN-13, EAN-8, UPC-A, Code 128), read
/// along rows in both directions, or a QR code (zxing2). Only the
/// [formats] given are looked for. Null if none is found.
ScannedCode? readCode(
  GreyImage image, {
  Set<CodeFormat> formats = const {...CodeFormat.values},
}) {
  if (formats.any((f) => f.linear)) {
    final linear = _readLinear(image, formats);
    if (linear != null) return linear;
  }
  if (formats.contains(CodeFormat.qr)) return _readQr(image);
  return null;
}

// ---- QR (zxing2) ----

ScannedCode? _readQr(GreyImage image) {
  final pixels = Int32List(image.width * image.height);
  for (var i = 0; i < pixels.length; i++) {
    final g = image.pixels[i];
    pixels[i] = 0xff000000 | g << 16 | g << 8 | g;
  }
  final source = RGBLuminanceSource(image.width, image.height, pixels);
  for (final binarizer in [
    HybridBinarizer(source),
    GlobalHistogramBinarizer(source),
  ]) {
    try {
      final result = QRCodeReader().decode(BinaryBitmap(binarizer),
          hints: DecodeHints()..put(DecodeHintType.tryHarder));
      return ScannedCode(result.text, CodeFormat.qr);
    } on ReaderException {
      // Not found this way.
    } on Object {
      // A damaged read: tried another way.
    }
  }
  return null;
}

// ---- Shop barcodes ----

/// Rows across the picture, each read both ways; the first code read
/// twice the same (or once, if only one row reads at all) wins.
ScannedCode? _readLinear(GreyImage image, Set<CodeFormat> formats) {
  const rows = 25;
  final found = <ScannedCode, int>{};
  ScannedCode? first;
  for (var r = 0; r < rows; r++) {
    // From the middle outwards: a framed code sits mostly there.
    final step = (r + 1) ~/ 2 * (r.isOdd ? 1 : -1);
    final y = (image.height * (0.5 + step / (rows + 1))).round();
    if (y < 0 || y >= image.height) continue;
    final runs = _runs(_row(image, y));
    if (runs == null) continue;
    for (final reversed in [false, true]) {
      final code = _decodeRuns(reversed ? _reversed(runs) : runs, formats);
      if (code == null) continue;
      first ??= code;
      final seen = (found[code] ?? 0) + 1;
      if (seen >= 2) return code;
      found[code] = seen;
    }
  }
  return first;
}

/// Row [y], averaged with the rows beside it (less noise).
Uint8List _row(GreyImage image, int y) {
  final row = Uint8List(image.width);
  final above = y > 0 ? y - 1 : y, below = y < image.height - 1 ? y + 1 : y;
  for (var x = 0; x < image.width; x++) {
    row[x] =
        (image.at(x, above) + 2 * image.at(x, y) + image.at(x, below)) >> 2;
  }
  return row;
}

/// [row] as alternating run lengths, starting with white: each pixel
/// black if darker than the light around it (a sliding mean, so uneven
/// light is fine). Null for a row with no contrast.
List<int>? _runs(Uint8List row) {
  final n = row.length;
  if (n < 20) return null;
  var lo = 255, hi = 0;
  for (final v in row) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  if (hi - lo < 40) return null;
  final half = (n ~/ 16).clamp(8, 200);
  final sums = List<int>.filled(n + 1, 0);
  for (var i = 0; i < n; i++) {
    sums[i + 1] = sums[i] + row[i];
  }
  final mid = (lo + hi) ~/ 2;
  final runs = <int>[];
  var black = false, length = 0;
  for (var i = 0; i < n; i++) {
    final a = (i - half).clamp(0, n), b = (i + half + 1).clamp(0, n);
    final mean = (sums[b] - sums[a]) ~/ (b - a);
    // The local mean, but never far from the row's middle grey.
    final threshold = (mean + mid) ~/ 2;
    final isBlack = row[i] < threshold;
    if (isBlack == black) {
      length++;
    } else {
      runs.add(length);
      black = isBlack;
      length = 1;
    }
  }
  runs.add(length);
  if (black) runs.add(0); // ends white
  return runs.length < 20 ? null : runs;
}

List<int> _reversed(List<int> runs) {
  final r = runs.reversed.toList();
  // Starting with white again.
  if (r.length.isEven) r.add(0);
  return r;
}

/// How far [counts] are from [pattern] (scaled to them): 0 a perfect
/// match; [_maxVariance] and above, no match.
double _variance(List<int> counts, int from, List<int> pattern) {
  var total = 0, modules = 0;
  for (var i = 0; i < pattern.length; i++) {
    total += counts[from + i];
    modules += pattern[i];
  }
  if (total < modules) return double.infinity;
  final unit = total / modules;
  var off = 0.0;
  for (var i = 0; i < pattern.length; i++) {
    final d = (counts[from + i] - pattern[i] * unit).abs();
    if (d > unit * 0.75) return double.infinity;
    off += d;
  }
  return off / total;
}

const _maxVariance = 0.42;

ScannedCode? _decodeRuns(List<int> runs, Set<CodeFormat> formats) {
  // runs[0] is white; bars start at odd indexes.
  for (var i = 1; i + 6 < runs.length; i += 2) {
    // A quiet zone before it: white at least as wide as its first bars.
    final quiet = runs[i - 1];
    if (formats.contains(CodeFormat.code128)) {
      final code = _code128At(runs, i, quiet);
      if (code != null) return code;
    }
    if (formats.contains(CodeFormat.ean13) ||
        formats.contains(CodeFormat.ean8) ||
        formats.contains(CodeFormat.upcA)) {
      final code = _eanAt(runs, i, quiet, formats);
      if (code != null) return code;
    }
  }
  return null;
}

// ---- EAN / UPC ----

const _l = [
  [3, 2, 1, 1], [2, 2, 2, 1], [2, 1, 2, 2], [1, 4, 1, 1], [1, 1, 3, 2], //
  [1, 2, 3, 1], [1, 1, 1, 4], [1, 3, 1, 2], [1, 2, 1, 3], [3, 1, 1, 2],
];

/// The first digit of an EAN-13, from which of its left six digits are
/// "G" (mirrored) ones: bit 5 is the first.
const _firstDigit = [
  0x00,
  0x0B,
  0x0D,
  0x0E,
  0x13,
  0x19,
  0x1C,
  0x15,
  0x16,
  0x1A
];

/// A digit at [from] (four runs): its value, and whether it's a G one;
/// null if none fits.
(int, bool)? _digit(List<int> runs, int from, {required bool left}) {
  var best = _maxVariance, value = -1, g = false;
  for (var d = 0; d < 10; d++) {
    final v = _variance(runs, from, _l[d]);
    if (v < best) {
      best = v;
      value = d;
      g = false;
    }
    if (left) {
      final mirrored = _variance(runs, from, _l[d].reversed.toList());
      if (mirrored < best) {
        best = mirrored;
        value = d;
        g = true;
      }
    }
  }
  return value < 0 ? null : (value, g);
}

bool _eanCheck(List<int> digits) {
  var sum = 0;
  for (var i = 0; i < digits.length - 1; i++) {
    // From the right of the data: 3, 1, 3, …
    final weight = (digits.length - 1 - i).isOdd ? 3 : 1;
    sum += digits[i] * weight;
  }
  return (10 - sum % 10) % 10 == digits.last;
}

ScannedCode? _eanAt(List<int> runs, int i, int quiet, Set<CodeFormat> formats) {
  // The start guard: bar, space, bar, one module each.
  if (_variance(runs, i, const [1, 1, 1]) > _maxVariance) return null;
  final module = (runs[i] + runs[i + 1] + runs[i + 2]) / 3;
  if (quiet < module * 3) return null;
  for (final digitsPerSide in [6, 4]) {
    final ean13 = digitsPerSide == 6;
    if (ean13 &&
        !formats.contains(CodeFormat.ean13) &&
        !formats.contains(CodeFormat.upcA)) {
      continue;
    }
    if (!ean13 && !formats.contains(CodeFormat.ean8)) continue;
    final middle = i + 3 + digitsPerSide * 4;
    final right = middle + 5;
    final end = right + digitsPerSide * 4;
    if (end + 3 > runs.length) continue;
    final digits = <int>[];
    var parity = 0;
    var ok = true;
    for (var k = 0; k < digitsPerSide && ok; k++) {
      final d = _digit(runs, i + 3 + k * 4, left: true);
      if (d == null || (!ean13 && d.$2)) {
        ok = false;
      } else {
        digits.add(d.$1);
        if (d.$2) parity |= 1 << (digitsPerSide - 1 - k);
      }
    }
    // The middle guard: space, bar, space, bar, space.
    if (!ok || _variance(runs, middle, const [1, 1, 1, 1, 1]) > _maxVariance) {
      continue;
    }
    for (var k = 0; k < digitsPerSide && ok; k++) {
      final d = _digit(runs, right + k * 4, left: false);
      if (d == null) {
        ok = false;
      } else {
        digits.add(d.$1);
      }
    }
    if (!ok || _variance(runs, end, const [1, 1, 1]) > _maxVariance) {
      continue;
    }
    if (ean13) {
      final first = _firstDigit.indexOf(parity);
      if (first < 0) continue;
      digits.insert(0, first);
    }
    if (!_eanCheck(digits)) continue;
    final text = digits.join();
    if (ean13 && _first0(text) && formats.contains(CodeFormat.upcA)) {
      return ScannedCode(text.substring(1), CodeFormat.upcA);
    }
    if (ean13 && !formats.contains(CodeFormat.ean13)) continue;
    return ScannedCode(text, ean13 ? CodeFormat.ean13 : CodeFormat.ean8);
  }
  return null;
}

bool _first0(String text) => text.startsWith('0');

// ---- Code 128 ----

const _code128 = [
  [2, 1, 2, 2, 2, 2], // 0
  [2, 2, 2, 1, 2, 2], // 1
  [2, 2, 2, 2, 2, 1], // 2
  [1, 2, 1, 2, 2, 3], // 3
  [1, 2, 1, 3, 2, 2], // 4
  [1, 3, 1, 2, 2, 2], // 5
  [1, 2, 2, 2, 1, 3], // 6
  [1, 2, 2, 3, 1, 2], // 7
  [1, 3, 2, 2, 1, 2], // 8
  [2, 2, 1, 2, 1, 3], // 9
  [2, 2, 1, 3, 1, 2], // 10
  [2, 3, 1, 2, 1, 2], // 11
  [1, 1, 2, 2, 3, 2], // 12
  [1, 2, 2, 1, 3, 2], // 13
  [1, 2, 2, 2, 3, 1], // 14
  [1, 1, 3, 2, 2, 2], // 15
  [1, 2, 3, 1, 2, 2], // 16
  [1, 2, 3, 2, 2, 1], // 17
  [2, 2, 3, 2, 1, 1], // 18
  [2, 2, 1, 1, 3, 2], // 19
  [2, 2, 1, 2, 3, 1], // 20
  [2, 1, 3, 2, 1, 2], // 21
  [2, 2, 3, 1, 1, 2], // 22
  [3, 1, 2, 1, 3, 1], // 23
  [3, 1, 1, 2, 2, 2], // 24
  [3, 2, 1, 1, 2, 2], // 25
  [3, 2, 1, 2, 2, 1], // 26
  [3, 1, 2, 2, 1, 2], // 27
  [3, 2, 2, 1, 1, 2], // 28
  [3, 2, 2, 2, 1, 1], // 29
  [2, 1, 2, 1, 2, 3], // 30
  [2, 1, 2, 3, 2, 1], // 31
  [2, 3, 2, 1, 2, 1], // 32
  [1, 1, 1, 3, 2, 3], // 33
  [1, 3, 1, 1, 2, 3], // 34
  [1, 3, 1, 3, 2, 1], // 35
  [1, 1, 2, 3, 1, 3], // 36
  [1, 3, 2, 1, 1, 3], // 37
  [1, 3, 2, 3, 1, 1], // 38
  [2, 1, 1, 3, 1, 3], // 39
  [2, 3, 1, 1, 1, 3], // 40
  [2, 3, 1, 3, 1, 1], // 41
  [1, 1, 2, 1, 3, 3], // 42
  [1, 1, 2, 3, 3, 1], // 43
  [1, 3, 2, 1, 3, 1], // 44
  [1, 1, 3, 1, 2, 3], // 45
  [1, 1, 3, 3, 2, 1], // 46
  [1, 3, 3, 1, 2, 1], // 47
  [3, 1, 3, 1, 2, 1], // 48
  [2, 1, 1, 3, 3, 1], // 49
  [2, 3, 1, 1, 3, 1], // 50
  [2, 1, 3, 1, 1, 3], // 51
  [2, 1, 3, 3, 1, 1], // 52
  [2, 1, 3, 1, 3, 1], // 53
  [3, 1, 1, 1, 2, 3], // 54
  [3, 1, 1, 3, 2, 1], // 55
  [3, 3, 1, 1, 2, 1], // 56
  [3, 1, 2, 1, 1, 3], // 57
  [3, 1, 2, 3, 1, 1], // 58
  [3, 3, 2, 1, 1, 1], // 59
  [3, 1, 4, 1, 1, 1], // 60
  [2, 2, 1, 4, 1, 1], // 61
  [4, 3, 1, 1, 1, 1], // 62
  [1, 1, 1, 2, 2, 4], // 63
  [1, 1, 1, 4, 2, 2], // 64
  [1, 2, 1, 1, 2, 4], // 65
  [1, 2, 1, 4, 2, 1], // 66
  [1, 4, 1, 1, 2, 2], // 67
  [1, 4, 1, 2, 2, 1], // 68
  [1, 1, 2, 2, 1, 4], // 69
  [1, 1, 2, 4, 1, 2], // 70
  [1, 2, 2, 1, 1, 4], // 71
  [1, 2, 2, 4, 1, 1], // 72
  [1, 4, 2, 1, 1, 2], // 73
  [1, 4, 2, 2, 1, 1], // 74
  [2, 4, 1, 2, 1, 1], // 75
  [2, 2, 1, 1, 1, 4], // 76
  [4, 1, 3, 1, 1, 1], // 77
  [2, 4, 1, 1, 1, 2], // 78
  [1, 3, 4, 1, 1, 1], // 79
  [1, 1, 1, 2, 4, 2], // 80
  [1, 2, 1, 1, 4, 2], // 81
  [1, 2, 1, 2, 4, 1], // 82
  [1, 1, 4, 2, 1, 2], // 83
  [1, 2, 4, 1, 1, 2], // 84
  [1, 2, 4, 2, 1, 1], // 85
  [4, 1, 1, 2, 1, 2], // 86
  [4, 2, 1, 1, 1, 2], // 87
  [4, 2, 1, 2, 1, 1], // 88
  [2, 1, 2, 1, 4, 1], // 89
  [2, 1, 4, 1, 2, 1], // 90
  [4, 1, 2, 1, 2, 1], // 91
  [1, 1, 1, 1, 4, 3], // 92
  [1, 1, 1, 3, 4, 1], // 93
  [1, 3, 1, 1, 4, 1], // 94
  [1, 1, 4, 1, 1, 3], // 95
  [1, 1, 4, 3, 1, 1], // 96
  [4, 1, 1, 1, 1, 3], // 97
  [4, 1, 1, 3, 1, 1], // 98
  [1, 1, 3, 1, 4, 1], // 99
  [1, 1, 4, 1, 3, 1], // 100
  [3, 1, 1, 1, 4, 1], // 101
  [4, 1, 1, 1, 3, 1], // 102
  [2, 1, 1, 4, 1, 2], // 103
  [2, 1, 1, 2, 1, 4], // 104
  [2, 1, 1, 2, 3, 2], // 105
];
const _code128Stop = [2, 3, 3, 1, 1, 1, 2];

ScannedCode? _code128At(List<int> runs, int i, int quiet) {
  if (i + 6 > runs.length) return null;
  final start = _symbol(runs, i, const [103, 104, 105]);
  if (start == null) return null;
  final module =
      [for (var k = 0; k < 6; k++) runs[i + k]].fold<int>(0, (a, b) => a + b) /
          11;
  if (quiet < module * 5) return null;
  final codes = <int>[start];
  var at = i + 6;
  while (true) {
    if (at + 7 <= runs.length &&
        _variance(runs, at, _code128Stop) < _maxVariance) {
      break;
    }
    if (at + 6 > runs.length) return null;
    final code = _symbol(runs, at, null);
    if (code == null || code > 102) return null;
    codes.add(code);
    at += 6;
    if (codes.length > 80) return null;
  }
  if (codes.length < 3) return null;
  // The check symbol: the start, then each symbol by its place.
  var sum = codes.first;
  for (var k = 1; k < codes.length - 1; k++) {
    sum += codes[k] * k;
  }
  if (sum % 103 != codes.last) return null;
  final text = _code128Text(codes.sublist(0, codes.length - 1));
  return text == null || text.isEmpty
      ? null
      : ScannedCode(text, CodeFormat.code128);
}

/// The symbol at [from] (six runs) among [only] (or any); null if none
/// fits well.
int? _symbol(List<int> runs, int from, List<int>? only) {
  var best = _maxVariance;
  int? code;
  for (final k in only ?? List.generate(106, (i) => i)) {
    final v = _variance(runs, from, _code128[k]);
    if (v < best) {
      best = v;
      code = k;
    }
  }
  return code;
}

/// What [codes] (the start code first, no check symbol) say, through
/// code sets A, B and C, their shifts and switches. FNC codes are left
/// out (an FNC1 marks a GS1 code; its data reads the same).
String? _code128Text(List<int> codes) {
  var set = switch (codes.first) { 103 => 'A', 104 => 'B', _ => 'C' };
  final out = StringBuffer();
  var shift = false;
  for (final code in codes.skip(1)) {
    final current = shift ? (set == 'A' ? 'B' : 'A') : set;
    shift = false;
    if (current == 'C') {
      if (code < 100) {
        out.write(code.toString().padLeft(2, '0'));
      } else if (code == 100) {
        set = 'B';
      } else if (code == 101) {
        set = 'A';
      }
      continue;
    }
    if (code < 96) {
      out.writeCharCode(
          current == 'A' ? (code < 64 ? code + 32 : code - 64) : code + 32);
      continue;
    }
    switch (code) {
      case 98:
        shift = true;
      case 99:
        set = 'C';
      case 100:
        if (current == 'A') set = 'B';
      case 101:
        if (current == 'B') set = 'A';
    }
  }
  return out.toString();
}
