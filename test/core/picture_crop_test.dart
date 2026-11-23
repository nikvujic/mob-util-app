import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/picture_crop.dart';

import '../helpers.dart';

/// The barcode crop (spec: barcode): a part of a picture as shown
/// (turned first), at its own resolution.
void main() {
  const red = 0xFF0000, green = 0x00FF00, blue = 0x0000FF, white = 0xFFFFFF;

  /// A 2×2 picture: red, green / blue, white.
  final picture = testPng(pixels: [
    [red, green],
    [blue, white],
  ]);

  /// [png]'s width, height, then its pixels' colours, row by row.
  Future<List<int>> pixels(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    final data = (await image.toByteData())!;
    return [
      image.width,
      image.height,
      for (var i = 0; i < data.lengthInBytes; i += 4)
        data.getUint8(i) << 16 |
            data.getUint8(i + 1) << 8 |
            data.getUint8(i + 2),
    ];
  }

  test('the whole picture, unturned, is itself', () async {
    final crop = await cropPicture(picture,
        turns: 0, area: const ui.Rect.fromLTRB(0, 0, 1, 1));
    expect(await pixels(crop), [2, 2, red, green, blue, white]);
  });

  test('its right half', () async {
    final crop = await cropPicture(picture,
        turns: 0, area: const ui.Rect.fromLTRB(0.5, 0, 1, 1));
    expect(await pixels(crop), [1, 2, green, white]);
  });

  test('turned once (clockwise): cropped as shown', () async {
    // Turned clockwise: blue, red / white, green.
    final whole = await cropPicture(picture,
        turns: 1, area: const ui.Rect.fromLTRB(0, 0, 1, 1));
    expect(await pixels(whole), [2, 2, blue, red, white, green]);
    final top = await cropPicture(picture,
        turns: 1, area: const ui.Rect.fromLTRB(0, 0, 1, 0.5));
    expect(await pixels(top), [2, 1, blue, red]);
  });

  test('turned twice and three times', () async {
    final twice = await cropPicture(picture,
        turns: 2, area: const ui.Rect.fromLTRB(0, 0, 1, 1));
    expect(await pixels(twice), [2, 2, white, blue, green, red]);
    final thrice = await cropPicture(picture,
        turns: 3, area: const ui.Rect.fromLTRB(0, 0, 1, 1));
    expect(await pixels(thrice), [2, 2, green, white, red, blue]);
  });

  test("a frame past the picture's edge is kept to it", () async {
    final crop = await cropPicture(picture,
        turns: 0, area: const ui.Rect.fromLTRB(-0.5, 0.5, 2, 3));
    expect(await pixels(crop), [2, 1, blue, white]);
  });

  test("a picture's size, and turned", () async {
    final wide = testPng(pixels: [
      [red, red, red],
    ]);
    expect(await pictureSize(wide), const ui.Size(3, 1));
    expect(turnedSize(const ui.Size(3, 1), 1), const ui.Size(1, 3));
    expect(turnedSize(const ui.Size(3, 1), 2), const ui.Size(3, 1));
  });
}
