import 'package:flutter/widgets.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/people_sprites.dart';

/// A person's face (Round 108): their age group's pixel face on a disc in
/// their gender's colour; all grey for someone deceased.
class PeopleAvatar extends StatelessWidget {
  /// 0 (baby) to 6 (old).
  final int age;
  final bool female;
  final bool grey;
  final double size;

  const PeopleAvatar({
    super.key,
    required this.age,
    required this.female,
    this.grey = false,
    this.size = 84,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _AvatarPainter(age, female, grey),
        ),
      );
}

class _AvatarPainter extends CustomPainter {
  final int age;
  final bool female;
  final bool grey;

  _AvatarPainter(this.age, this.female, this.grey);

  static Color _grey(Color c) {
    final v = (0.3 * c.r + 0.59 * c.g + 0.11 * c.b) * 0.8 + 40 / 255;
    return Color.from(alpha: 1, red: v, green: v, blue: v);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final back = grey
        ? PeopleColours.greyBack
        : female
            ? PeopleColours.femaleBack
            : PeopleColours.maleBack;
    canvas.drawCircle(
        size.center(Offset.zero), size.width / 2, Paint()..color = back);
    // The face fills most of the disc, its shirt at the bottom.
    final pixel = size.width * 0.85 / PeopleSprites.size;
    final left = (size.width - pixel * PeopleSprites.size) / 2;
    final top = size.height - pixel * PeopleSprites.size - size.height * 0.04;
    final palette = PeopleSprites.palette(age, female: female);
    final rows = PeopleSprites.face(age, female: female);
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final colour = palette[rows[y][x]];
        if (colour == null) continue;
        paint.color = grey ? _grey(colour) : colour;
        canvas.drawRect(
          Rect.fromLTWH(
              left + x * pixel, top + y * pixel, pixel + 0.5, pixel + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.age != age || old.female != female || old.grey != grey;
}
