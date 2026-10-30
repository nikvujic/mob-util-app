import 'package:flutter/material.dart';
import 'package:the_app/core/pip_house.dart';
import 'package:the_app/core/pip_scene.dart' show Season;
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/pip_house_art.dart';

/// A finished quest's picture (Round 126, spec 1: drawn, in a little
/// frame): the house as he built it, by day, its tree in summer.
class PipHousePicture extends StatelessWidget {
  /// How big one of his pixels is.
  final double pixel;

  const PipHousePicture({super.key, this.pixel = 1});

  /// What of the house area it shows (his pixels): the house and porch,
  /// the roof, the tree's lower crown.
  static const _left = 0, _top = 44, _width = 170, _height = 110;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: PipHouseColours.beam,
        border: Border.all(color: PipHouseColours.beamLight, width: 2),
      ),
      child: CustomPaint(
        size: Size(_width * pixel, _height * pixel),
        painter: _PicturePainter(pixel),
      ),
    );
  }
}

class _PicturePainter extends CustomPainter {
  final double pixel;

  _PicturePainter(this.pixel);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    canvas.clipRect(Offset.zero & size);
    // The sky by day, from deep to pale.
    const sky = [PipColours.dayTop, PipColours.dayBottom];
    final rows = PipHousePicture._height;
    for (var y = 0; y < rows; y++) {
      canvas.drawRect(Rect.fromLTWH(0, y * pixel, size.width, pixel),
          paint..color = Color.lerp(sky[0], sky[1], y / rows)!);
    }
    final art = PipHouseArt((x, y, c, [w = 1, h = 1]) {
      canvas.drawRect(
          Rect.fromLTWH((x - PipHousePicture._left) * pixel,
              (y - PipHousePicture._top) * pixel, w * pixel, h * pixel),
          paint..color = c);
    });
    const g = PipHouse.ground;
    for (var x = 0; x < PipHouse.areaWidth; x++) {
      art.put(x, g, x % 3 == 0 ? PipColours.grass : PipColours.grassLight);
      art.rect(x, g + 1, x, g + 20, PipColours.dirt);
    }
    art.tree(Season.summer, PipHouse.treeLeft.toDouble(), g - 1.0);
    art.house(PipHouse.finished);
    art.chimneySmoke(0.4);
  }

  @override
  bool shouldRepaint(_PicturePainter old) => old.pixel != pixel;
}

/// One of what he carries (Round 126), as his inventory card shows it:
/// its icon, [pixel] big.
class PipItemIcon extends StatelessWidget {
  final String kind;
  final double pixel;

  const PipItemIcon(this.kind, {super.key, this.pixel = 3});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(12 * pixel, 12 * pixel),
        painter: _IconPainter(kind, pixel),
      );
}

class _IconPainter extends CustomPainter {
  final String kind;
  final double pixel;

  _IconPainter(this.kind, this.pixel);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    PipHouseArt((x, y, c, [w = 1, h = 1]) {
      canvas.drawRect(Rect.fromLTWH(x * pixel, y * pixel, w * pixel, h * pixel),
          paint..color = c);
    }).icon(kind, 0, 0);
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.kind != kind || old.pixel != pixel;
}
