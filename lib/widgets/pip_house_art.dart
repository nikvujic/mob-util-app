import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:the_app/core/pip_house.dart';
import 'package:the_app/core/pip_scene.dart' show Season;
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Draws one of his pixels: [x], [y] in the house area's own measures
/// (`PipHouse`: x from its left, y down from the top as the drafts were
/// drawn, the ground's top row at `PipHouse.ground`), [w] by [h] of them.
typedef HouseDot = void Function(double x, double y, Color c,
    [double w, double h]);

/// Pip's house and the places he gathers in (Round 126), drawn from the
/// approved drafts (`docs/pip_house_drafts.png`, Round 124).
class PipHouseArt {
  final HouseDot _dot;

  /// How opaque what's drawn now is (a piece half built shows faintly).
  double _alpha = 1;

  PipHouseArt(this._dot);

  static int _h(int x, int y, [int s = 0]) =>
      ((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) & 0xffff;

  void put(num x, num y, Color c) => _dot(x.toDouble(), y.toDouble(),
      _alpha >= 1 ? c : c.withValues(alpha: c.a * _alpha));

  void rect(num x0, num y0, num x1, num y1, Color c) {
    if (x1 < x0 || y1 < y0) return;
    _dot(
        x0.toDouble(),
        y0.toDouble(),
        _alpha >= 1 ? c : c.withValues(alpha: c.a * _alpha),
        (x1 - x0 + 1).toDouble(),
        (y1 - y0 + 1).toDouble());
  }

  /// [draw] with only [share] of it showing (0 to 1).
  void faint(double share, void Function() draw) {
    if (share <= 0) return;
    final was = _alpha;
    _alpha = share.clamp(0.0, 1.0) * was;
    draw();
    _alpha = was;
  }

  // ---- Stone: bricks, the bottom row first ----

  /// Stone bricks over [x0]..[x1], [y0]..[y1], bottom row first; [share]
  /// of them (0 to 1). The number of bricks there are.
  int stones(int x0, int y0, int x1, int y1,
      {double share = 1, int seed = 0, bool draw = true}) {
    var total = 0;
    for (var row = 0, y = y1 - 2; y >= y0; row++, y -= 3) {
      for (var bx = x0 - (row % 2) * 3; bx <= x1; bx += 6) {
        total++;
      }
    }
    if (!draw) return total;
    final limit = (total * share).round();
    var n = 0;
    for (var row = 0, y = y1 - 2; y >= y0; row++, y -= 3) {
      for (var bx = x0 - (row % 2) * 3; bx <= x1; bx += 6) {
        if (n >= limit) return total;
        final a = math.max(bx, x0), b = math.min(bx + 5, x1);
        final c = PipHouseColours.stone[_h(bx, y, seed) % 4];
        rect(a, y, b, y + 2, c);
        rect(a, y, b, y, _h(bx, y) % 3 == 0 ? PipHouseColours.stoneLight : c);
        rect(b, y, b, y + 2, PipHouseColours.mortar);
        rect(a, y + 2, b, y + 2, PipHouseColours.mortar);
        if (_h(bx, y, 5) % 4 == 0) put(a + 2, y + 1, PipHouseColours.stone[3]);
        n++;
      }
    }
    return total;
  }

  // ---- The house, from what's built ----

  static const _g = PipHouse.ground;
  static const _hx0 = PipHouse.left, _hx1 = PipHouse.right;
  static const _fy0 = PipHouse.foundationTop;
  static const _fl = PipHouse.floorTop;
  static const _wt = PipHouse.wallTop;
  static const _cb0 = PipHouse.beamTop, _cb1 = PipHouse.beamTop + 2;
  static const _px0 = PipHouse.porchLeft, _px1 = PipHouse.porchRight;
  static const _fp0 = PipHouse.fireplaceLeft, _fp1 = PipHouse.fireplaceRight;
  static const _fl0 = PipHouse.flueLeft, _fl1 = PipHouse.flueRight;
  static const _eave0 = PipHouse.eaveLeft, _eave1 = PipHouse.eaveRight;
  static const _apex = PipHouse.apex;

  static int roofTop(num x) =>
      52 + ((x - _apex).abs() * (_cb0 - 1 - 52) ~/ ((_eave1 - _eave0) ~/ 2));

  /// The house as [house] says: each piece as far as it's up, on what's
  /// under it. [fire]: the fireplace lit. [raining], [snowy]: the
  /// weather on it while it's open.
  void house(PipHouse house,
      {bool fire = true, bool raining = false, bool snowy = false}) {
    final s = house.share;
    // The foundation, the porch's posts and deck, the stairs.
    stones(_hx0 - 2, _fy0, _hx1 + 2, _g - 1, share: s('foundation'));
    _porchFootings(house.of('porchPosts'));
    _deck(s('deck'));
    _stairs(house.of('stairs'));
    _floor(s('floor'));
    // The fireplace, its flue and cap.
    final hearth = s('hearth');
    if (hearth > 0) _fireplace(hearth, fire: fire && house.has('hearth'));
    // Posts, walls, windows, door.
    _posts(house.of('posts'));
    final walls = s('walls');
    if (walls > 0) {
      final upTo = (_fl - 1 - walls * (_fl - 1 - _wt)).round();
      _backWall(upTo);
      _sideWall(true, upTo);
      _sideWall(false, upTo, door: true);
      if (hearth >= 1) _fireplace(1, fire: fire, front: true);
    }
    for (var i = 0; i < 2; i++) {
      final (wx, wy) = PipHouse.windows[i];
      if (walls >= 1) {
        _window(wx, wy, glass: house.of('windows') > i);
      }
    }
    if (house.of('door') > 0) faint(s('door'), _door);
    for (var i = 0; i < 2; i++) {
      final (wx, wy) = PipHouse.windows[i];
      faint(house.of('flowerBoxes') - i, () => _flowerBox(wx, wy));
    }
    _railing(s('railing'));
    _porchRoofPosts(house.of('porchRoofPosts'));
    faint(s('bench'), _bench);
    // The beam, the flue, the roof.
    faint(s('beam'), _beam);
    final flue = s('flue');
    if (flue > 0) {
      final top = (105 - flue * (105 - 62)).round();
      stones(_fl0, top, _fl1, 105, seed: 12);
    }
    if (house.scaffoldUp) {
      faint(house.has('scaffold') ? 1 - s('scaffoldDown') : s('scaffold'),
          _scaffold);
    }
    final gable = s('gable');
    if (gable > 0) _gable(gable, attic: house.has('atticWindow'));
    final rafters = house.of('rafters');
    if (rafters > 0) _rafters(rafters);
    final shingles = s('shingles');
    if (shingles > 0) _shingles(shingles);
    faint(s('trim'), _trim);
    if (house.has('flue')) faint(s('flueCap'), _flueCap);
    _porchRoof(s('porchRoof'));
    // The weather on it, while it's open.
    if (raining && house.roofOpen) _leak();
    if (snowy && house.started && !house.done) _snowOn(house);
  }

  void _porchFootings(double count) {
    final xs = [_px0 + 12, _px0 + 28, _px1 - 4];
    for (var i = 0; i < 3; i++) {
      faint(count - i, () {
        final x0 = xs[i];
        rect(x0 + 1, _fy0 + 1, x0 + 3, _g - 3, PipHouseColours.beam);
        rect(x0 + 1, _fy0 + 1, x0 + 1, _g - 3, PipHouseColours.beamDark);
        rect(x0, _g - 2, x0 + 4, _g - 1, PipHouseColours.stone[1]);
        rect(x0, _g - 2, x0 + 4, _g - 2, PipHouseColours.stoneLight);
      });
    }
  }

  void _deck(double share) {
    if (share <= 0) return;
    final end = _px0 + ((_px1 - _px0 + 1) * share).round() - 1;
    for (var x = _px0; x <= end; x += 5) {
      final c = PipHouseColours.plank[_h(x, 3) % 3];
      rect(x, _fy0 - 2, math.min(x + 4, end), _fy0 - 1, c);
      put(math.min(x + 4, end), _fy0 - 2, PipHouseColours.plankDark);
    }
    rect(_px0, _fy0, end, _fy0, PipHouseColours.beamDark);
  }

  void _stairs(double count) {
    const top = _fy0 - 2;
    for (var k = 0; k < 4; k++) {
      faint(count - k, () {
        final x0 = _px1 + 1 + k * 4, y = top + k * 2 + 2;
        rect(x0, y, x0 + 4, y, PipHouseColours.plank[1]);
        rect(x0, y + 1, x0 + 4, y + 1, PipHouseColours.plankDark);
        rect(x0, y + 2, x0, _g - 1, PipHouseColours.beamDark);
      });
    }
    if (count >= 4) {
      for (var k = 0; k < 18; k++) {
        put(_px1 + 1 + k, top + 3 + k * 9 ~/ 18, PipHouseColours.beam);
        put(_px1 + 1 + k, top - 8 + k * 9 ~/ 18, PipHouseColours.beamLight);
      }
      rect(_px1 + 18, top - 1, _px1 + 18, _g - 2, PipHouseColours.beam);
    }
  }

  void _floor(double share) {
    if (share <= 0) return;
    final end = _hx0 + ((_hx1 - _hx0 + 1) * share).round() - 1;
    for (var x = _hx0; x <= end; x += 5) {
      final c = PipHouseColours.plank[_h(x, _fl) % 3];
      rect(x, _fl, math.min(x + 4, end), _fl + 1, c);
      put(math.min(x + 4, end), _fl, PipHouseColours.plankDark);
      put(x + 2, _fl + 1, PipHouseColours.grain);
    }
  }

  void _fireplace(double share, {bool fire = true, bool front = false}) {
    // Front: drawn again over the back wall, as it stands before it.
    stones(_fp0, 108, _fp1, _fl - 1, share: share, seed: 11);
    if (share < 1) return;
    rect(_fp0 + 4, 124, _fp1 - 4, _fl - 1, PipHouseColours.firebox);
    rect(_fp0 + 4, 123, _fp1 - 4, 123, PipHouseColours.stone[3]);
    if (fire) {
      for (var x = _fp0 + 5; x < _fp1 - 4; x++) {
        final hh = 3 + _h(x, 1) % 5;
        for (var y = _fl - 1 - hh; y < _fl; y++) {
          put(x, y,
              y > _fl - 3 ? PipHouseColours.fireLight : PipHouseColours.fire);
        }
      }
      rect(_fp0 + 7, _fl - 2, _fp1 - 7, _fl - 1, PipHouseColours.ember);
    }
    rect(_fp0 - 2, 106, _fp1 + 2, 107, PipHouseColours.beam);
    rect(_fp0 - 2, 106, _fp1 + 2, 106, PipHouseColours.beamLight);
  }

  void _posts(double count) {
    final xs = [_hx0, PipHouse.middlePost, _hx1 - 3];
    for (var i = 0; i < 3; i++) {
      faint(count - i, () {
        final x0 = xs[i];
        rect(x0, _wt, x0 + 3, _fl - 1, PipHouseColours.beam);
        rect(x0, _wt, x0, _fl - 1, PipHouseColours.beamDark);
        rect(x0 + 3, _wt, x0 + 3, _fl - 1, PipHouseColours.beamLight);
        for (var y = _wt + 3; y < _fl; y += 9) {
          put(x0 + 1, y, PipHouseColours.beamDark);
        }
      });
    }
  }

  void _backWall(int upTo) {
    for (var y = _fl - 1; y >= upTo; y--) {
      for (var x = _hx0 + 4; x < _hx1 - 3; x++) {
        if (x >= PipHouse.middlePost && x <= PipHouse.middlePost + 3) continue;
        final band = (y - _wt) ~/ 3;
        var c = PipHouseColours.backWall[(band + _h(x ~/ 7, band)) % 3];
        if ((y - _wt) % 3 == 0) c = PipHouseColours.backWallDark;
        if ((x + band * 4) % 14 == 0) c = PipHouseColours.backWallDark;
        put(x, y, c);
      }
    }
  }

  void _sideWall(bool left, int upTo, {bool door = false}) {
    final (x0, x1) = left ? (_hx0, _hx0 + 3) : (_hx1 - 3, _hx1);
    for (var y = _fl - 1; y >= upTo; y--) {
      if (door && y >= 110) continue;
      for (var x = x0; x <= x1; x++) {
        put(
            x,
            y,
            (y - _wt) % 3 == 0
                ? PipHouseColours.plankDark
                : PipHouseColours.plank[((y - _wt) ~/ 3 + x) % 3]);
      }
    }
  }

  void _window(int x, int y, {required bool glass}) {
    rect(x - 1, y - 1, x + 18, y + 16, PipHouseColours.frameDark);
    rect(x, y, x + 17, y + 15, PipHouseColours.frame);
    if (glass) {
      for (final (gx, gy) in [
        (x + 1, y + 1),
        (x + 9, y + 1),
        (x + 1, y + 8),
        (x + 9, y + 8)
      ]) {
        rect(gx, gy, gx + 7, gy + 6, PipHouseColours.glass);
        rect(gx, gy + 5, gx + 7, gy + 6, PipHouseColours.glassDark);
        put(gx + 1, gy + 1, PipHouseColours.glassLight);
        put(gx + 2, gy + 1, PipHouseColours.glassLight);
        put(gx + 1, gy + 2, PipHouseColours.glassLight);
      }
    } else {
      rect(x + 1, y + 1, x + 16, y + 14, PipHouseColours.backWallDark);
    }
    rect(x - 2, y + 16, x + 19, y + 17, PipHouseColours.stone[2]);
    rect(x - 2, y + 16, x + 19, y + 16, PipHouseColours.stoneLight);
  }

  void _door() {
    const x0 = _hx1 - 3, x1 = _hx1;
    rect(x0 - 1, 107, x1 + 1, 109, PipHouseColours.stone[2]);
    rect(x0 - 1, 107, x1 + 1, 107, PipHouseColours.stoneLight);
    for (var y = 110; y < _fl; y++) {
      for (var x = x0; x <= x1; x++) {
        put(
            x,
            y,
            y == 114 || y == 129
                ? PipHouseColours.iron
                : PipHouseColours.plank[x % 3]);
      }
    }
    put(x0, 121, PipHouseColours.handle);
  }

  void _flowerBox(int wx, int wy) {
    rect(wx, wy + 18, wx + 17, wy + 20, PipHouseColours.beam);
    for (var x = wx + 1; x < wx + 17; x += 3) {
      put(x, wy + 17, PipHouseColours.flowers[_h(x, wy) % 3]);
      put(x + 1, wy + 17, PipColours.leafSummer);
    }
  }

  void _railing(double share) {
    if (share <= 0) return;
    final posts = [for (var x = _px0 + 16; x < _px1 - 3; x += 4) x];
    final n = (posts.length * share).ceil();
    for (final x in posts.take(n)) {
      rect(x, _fy0 - 10, x, _fy0 - 3, PipHouseColours.beam);
    }
    if (share >= 1) {
      rect(
          _px0 + 15, _fy0 - 11, _px1 - 3, _fy0 - 10, PipHouseColours.beamLight);
    }
  }

  void _porchRoofPosts(double count) {
    final xs = [_px0 + 12, _px1 - 3];
    for (var i = 0; i < 2; i++) {
      faint(count - i, () {
        rect(xs[i], 96, xs[i] + 2, _fy0 - 3, PipHouseColours.beam);
        rect(xs[i], 96, xs[i], _fy0 - 3, PipHouseColours.beamDark);
      });
    }
    if (count >= 2) rect(_px0, 94, _px1 + 2, 95, PipHouseColours.beam);
  }

  void _bench() {
    rect(_px0 + 20, _fy0 - 8, _px0 + 34, _fy0 - 7, PipHouseColours.plank[1]);
    rect(_px0 + 21, _fy0 - 6, _px0 + 21, _fy0 - 3, PipHouseColours.beam);
    rect(_px0 + 33, _fy0 - 6, _px0 + 33, _fy0 - 3, PipHouseColours.beam);
    rect(_px0 + 20, _fy0 - 14, _px0 + 34, _fy0 - 13, PipHouseColours.plank[0]);
    rect(_px0 + 20, _fy0 - 12, _px0 + 20, _fy0 - 9, PipHouseColours.beam);
    rect(_px0 + 34, _fy0 - 12, _px0 + 34, _fy0 - 9, PipHouseColours.beam);
  }

  void _porchRoof(double share) {
    if (share <= 0) return;
    final end = _px0 - 2 + ((_px1 + 4 - (_px0 - 2)) * share).round();
    for (var x = _px0 - 2; x < end; x++) {
      final y0 = 88 + (x - _px0) * 6 ~/ (_px1 - _px0);
      for (var y = y0; y < 94; y++) {
        put(
            x,
            y,
            y == 93 || ((x ~/ 5) % 2 == 0 && y == y0)
                ? PipHouseColours.roofDark
                : PipHouseColours.roof[(x ~/ 5) % 3]);
      }
      put(x, y0 - 1, PipHouseColours.trim);
    }
  }

  void _beam() {
    rect(_hx0 - 2, _cb0, _hx1 + 2, _cb1, PipHouseColours.beam);
    rect(_hx0 - 2, _cb0, _hx1 + 2, _cb0, PipHouseColours.beamLight);
    rect(_hx0 - 2, _cb1, _hx1 + 2, _cb1, PipHouseColours.beamDark);
  }

  void _flueCap() {
    rect(_fl0 - 2, 60, _fl1 + 2, 61, PipHouseColours.stone[2]);
    rect(_fl0 - 2, 60, _fl1 + 2, 60, PipHouseColours.stoneLight);
  }

  void _scaffold() {
    for (final x in [36, 82]) {
      rect(x, 99, x + 1, _fl - 1, PipHouseColours.plank[1]);
      for (var y = 101; y < _fl; y += 6) {
        put(x, y, PipHouseColours.plankDark);
      }
    }
    for (final y in [PipHouse.scaffoldHigh, PipHouse.scaffoldLow]) {
      rect(32, y, 86, y + 1, PipHouseColours.plank[0]);
      rect(32, y + 1, 86, y + 1, PipHouseColours.plankDark);
    }
    for (var k = 0; k < 18; k++) {
      put(38 + k, 100 + k, PipHouseColours.plankDark);
      put(80 - k, 100 + k, PipHouseColours.plankDark);
    }
  }

  void _gable(double share, {required bool attic}) {
    final bottom = _cb0 - 1;
    final top = (bottom - share * (bottom - 55)).round();
    for (var x = _hx0 + 2; x < _hx1 - 1; x++) {
      for (var y = math.max(roofTop(x) + 5, top); y < _cb0; y++) {
        put(
            x,
            y,
            y % 3 != 0
                ? PipHouseColours.plank[(y ~/ 3 + x ~/ 9) % 3]
                : PipHouseColours.plankDark);
      }
    }
    if (share < 1) return;
    const cx = _apex, cy = 78;
    for (var y = cy - 6; y <= cy + 6; y++) {
      for (var x = cx - 6; x <= cx + 6; x++) {
        final d = (x - cx) * (x - cx) + (y - cy) * (y - cy);
        if (d > 36) continue;
        put(
            x,
            y,
            d > 20
                ? PipHouseColours.frame
                : !attic
                    ? PipHouseColours.backWallDark
                    : (x - cx < -1 && y - cy < -1)
                        ? PipHouseColours.glassLight
                        : PipHouseColours.glass);
      }
    }
    rect(cx, cy - 5, cx, cy + 5, PipHouseColours.frame);
    rect(cx - 5, cy, cx + 5, cy, PipHouseColours.frame);
  }

  void _rafters(double count) {
    for (var x = _eave0; x <= _eave1; x++) {
      final y = roofTop(x);
      rect(x, y, x, y + 2, PipHouseColours.beam);
    }
    final xs = [for (var x = _hx0 + 8; x < _hx1 - 5; x += 12) x];
    for (var i = 0; i < xs.length && i < count.ceil(); i++) {
      for (var y = roofTop(xs[i]) + 3; y < _cb0; y++) {
        put(xs[i], y, PipHouseColours.beamDark);
        put(xs[i] + 1, y, PipHouseColours.beam);
      }
    }
  }

  /// Rows of shingles from the eaves up ([share] of them).
  void _shingles(double share) {
    const rows = (_cb0 - 1 - 50) ~/ 3 + 1;
    final n = (rows * share).ceil();
    var k = 0;
    for (var y = _cb0 - 1; y > 50 && k < n; y -= 3, k++) {
      for (var x = _eave0; x <= _eave1; x++) {
        if (roofTop(x) > y) continue;
        for (var yy = math.max(y - 2, roofTop(x)); yy <= y; yy++) {
          var c = PipHouseColours.roof[((x + (k % 2) * 3) ~/ 6) % 3];
          if (yy == y) c = PipHouseColours.roofDark;
          if (yy == y - 2 && _h(x, yy) % 3 == 0) c = PipHouseColours.roofLight;
          if ((x + (k % 2) * 3) % 6 == 0) c = PipHouseColours.roofDark;
          put(x, yy, c);
        }
      }
    }
  }

  void _trim() {
    for (var x = _eave0; x <= _eave1; x++) {
      final y = roofTop(x);
      put(x, y - 1, PipHouseColours.trim);
      put(x, y, PipHouseColours.trimDark);
    }
    rect(_eave0 - 1, _cb0 - 2, _eave0 + 1, _cb0, PipHouseColours.trim);
    rect(_eave1 - 1, _cb0 - 2, _eave1 + 1, _cb0, PipHouseColours.trim);
    rect(_apex - 1, 49, _apex + 1, 52, PipHouseColours.trim);
  }

  /// Rain getting in under a roof begun but not closed: drips falling,
  /// a puddle on the floor.
  void _leak() {
    for (final x in [34, 47, 63]) {
      for (var y = _cb1 + 4; y < _fl - 3; y += 8) {
        put(x, y, PipHouseColours.drip);
        put(x, y + 1, PipHouseColours.drip);
      }
    }
    rect(38, _fl - 1, 60, _fl - 1, PipHouseColours.drip);
    rect(42, _fl - 2, 56, _fl - 2, PipHouseColours.glass);
  }

  /// Snow on an unfinished house: on its open floor, the porch, the tops
  /// of what's up.
  void _snowOn(PipHouse house) {
    if (house.roofless) {
      for (var x = _hx0; x <= _hx1; x += 2) {
        put(x, _fl - 1, PipHouseColours.snow);
      }
    }
    if (house.has('deck') && !house.has('porchRoof')) {
      rect(_px0, _fy0 - 3, _px1, _fy0 - 3, PipHouseColours.snow);
    }
    if (house.of('shingles') > 0 && !house.has('shingles')) {
      const rows = (_cb0 - 1 - 50) ~/ 3 + 1;
      final n = (rows * house.share('shingles')).ceil();
      final top = _cb0 - 1 - 3 * n + 1;
      for (var x = _eave0; x <= _eave1; x++) {
        if (roofTop(x) <= top) put(x, top, PipHouseColours.snow);
      }
    }
  }

  /// The smoke from the chimney (a few puffs rising, drifting with [t]).
  void chimneySmoke(double t) {
    for (var i = 0; i < 4; i++) {
      final p = (t * 0.25 + i / 4) % 1;
      final cx = (_fl0 + _fl1) / 2 + p * 10;
      final cy = 56 - p * 26;
      final r = 1 + p * 3;
      for (var y = (cy - r).floor(); y <= cy + r; y++) {
        for (var x = (cx - r).floor(); x <= cx + r; x++) {
          if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r) {
            put(x, y,
                y > cy ? PipHouseColours.smokeDark : PipHouseColours.smoke);
          }
        }
      }
    }
  }

  // ---- The house area's tree: taller than the field's, by season ----

  static final List<String> tallTree = _tallTree();
  static final List<String> tallTreeBare = _tallTreeBare();

  static List<String> _tallTree() {
    const w = 40, h = 84;
    final g = [for (var y = 0; y < h; y++) List.filled(w, '.')];
    _trunk(g);
    for (var k = 0; k < 9; k++) {
      g[48 - k ~/ 2][17 - k] = 'T';
      g[47 - k ~/ 2][17 - k] = 'T';
      g[42 - k ~/ 2][22 + k] = 'U';
      g[43 - k ~/ 2][22 + k] = 'U';
    }
    const blobs = [
      (20, 14, 11),
      (10, 24, 9),
      (30, 22, 10),
      (20, 30, 12),
      (8, 38, 8),
      (32, 38, 8),
      (20, 42, 9),
      (14, 8, 7),
      (26, 8, 7),
    ];
    for (final (cx, cy, r) in blobs) {
      for (var y = math.max(0, cy - r); y < math.min(h, cy + r + 1); y++) {
        for (var x = math.max(0, cx - r - 1);
            x < math.min(w, cx + r + 2);
            x++) {
          final d = math.pow((x - cx) / 1.1, 2) + math.pow(y - cy, 2);
          if (d >= r * r) continue;
          if (d > r * r * 0.82 && _h(x, y, 3) % 3 == 0) continue;
          final v = _h(x, y, 7) % 11;
          final lit = (x - cx) + (cy - y) > r * 0.45;
          final shade = (x - cx) + (y - cy) > r * 0.55 || y > cy + r * 0.6;
          var ch = lit ? 'H' : (shade ? 'D' : 'L');
          if (v == 0) {
            ch = 'B';
          } else if (v == 1 && ch == 'L') {
            ch = 'H';
          } else if (v == 2 && ch == 'L') {
            ch = 'D';
          }
          g[y][x] = ch;
        }
      }
    }
    return [for (final r in g) r.join()];
  }

  static void _trunk(List<List<String>> g) {
    final h = g.length;
    for (var y = 40; y < h; y++) {
      final w = y < h - 5 ? 4 : 4 + (y - (h - 5));
      for (var x = 20 - w ~/ 2; x <= 20 + w ~/ 2; x++) {
        g[y][x] = x >= 20 ? 'U' : 'T';
      }
    }
  }

  static List<String> _tallTreeBare() {
    const w = 40, h = 84;
    final g = [for (var y = 0; y < h; y++) List.filled(w, '.')];
    _trunk(g);
    var seed = 11;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    void branch(double x, double y, double dx, double dy, int n, int depth) {
      for (var k = 0; k < n; k++) {
        x += dx;
        y += dy;
        final xi = x.round(), yi = y.round();
        if (xi >= 0 && xi < w && yi >= 0 && yi < h) {
          g[yi][xi] = dx < 0 ? 'T' : 'U';
        }
        if (depth < 3 && (k == n ~/ 2 || k == n - 1)) {
          branch(x, y, dx * 0.6 + (next() < 0.5 ? -0.5 : 0.5), -0.9, n ~/ 2 + 2,
              depth + 1);
        }
      }
    }

    for (final (dx, n) in [
      (-1.0, 14),
      (1.0, 14),
      (-0.5, 18),
      (0.5, 18),
      (0.0, 22)
    ]) {
      branch(20, 44, dx, dx == 0 ? -1 : -0.8, n, 0);
    }
    return [for (final r in g) r.join()];
  }

  /// The house area's tree in [season], its bottom left at [x], [bottom];
  /// in winter, snow on its branches.
  void tree(Season season, double x, double bottom, {double sway = 0}) {
    final winter = season == Season.winter;
    final rows = winter ? tallTreeBare : tallTree;
    final colours = PipSprites.treeColours[season.index];
    for (var y = 0; y < rows.length; y++) {
      final crown = y < 50;
      for (var i = 0; i < rows[y].length; i++) {
        final ch = rows[y][i];
        if (ch == '.') continue;
        final c = colours[ch] ?? PipColours.bark;
        put(x + i + (crown ? sway : 0).round(), bottom - rows.length + 1 + y,
            c);
        if (winter && y > 0 && y < rows.length - 30 && rows[y - 1][i] == '.') {
          put(x + i + sway.round(), bottom - rows.length + y,
              PipHouseColours.snow);
        }
      }
    }
  }

  // ---- The places he gathers in ----

  /// Field trees ([rows] in [colours]) at [scale], faded into the haze by
  /// [haze], their bottom left at [x], [bottom].
  void sprite(
      List<String> rows, Map<String, Color> colours, double x, double bottom,
      {double haze = 0, double scale = 1}) {
    final h = (rows.length * scale).floor(),
        w = (rows.first.length * scale).floor();
    for (var y = 0; y < h; y++) {
      final r = rows[math.min(rows.length - 1, (y / scale).floor())];
      for (var i = 0; i < w; i++) {
        final ch = r[math.min(r.length - 1, (i / scale).floor())];
        final c = colours[ch];
        if (ch == '.' || c == null) continue;
        put(x + i, bottom - h + 1 + y,
            haze > 0 ? Color.lerp(c, PipHouseColours.haze, haze)! : c);
      }
    }
  }

  /// The forest (Round 124: dense, in three layers, the far ones hazy):
  /// the ground's top at [ground]; [width] wide; [season]'s colours.
  void forest(double ground, int width, Season season) {
    final oak = PipSprites.treeOf(PipTreeKind.oak, season);
    final birch = PipSprites.treeOf(PipTreeKind.birch, season);
    final pine = PipSprites.treeOf(PipTreeKind.pine, season);
    final kinds = [
      pine,
      oak,
      pine,
      birch,
      oak,
      pine,
      oak,
      birch,
      pine,
      oak,
      pine
    ];
    for (var i = 0, x = -8; x < width + 10; i++, x += 18) {
      final k = kinds[i % kinds.length];
      sprite(k.$1, k.$2, x.toDouble(), ground - 8, haze: 0.62, scale: 0.95);
    }
    final mid = [oak, birch, pine, oak, birch, pine, oak, birch];
    for (var i = 0, x = -4; x < width + 10; i++, x += 22) {
      final k = mid[i % mid.length];
      sprite(k.$1, k.$2, x.toDouble(), ground - 4, haze: 0.38, scale: 1.15);
    }
    for (var x = 0; x < width; x += 9) {
      if (_h(x, 5) % 3 != 0) continue;
      for (var y = ground - 5; y < ground; y++) {
        for (var xx = x; xx < x + 8; xx++) {
          if (math.pow(xx - x - 4, 2) / 16 + math.pow(y - ground + 1, 2) / 16 <
              1) {
            put(
                xx,
                y,
                _h(xx, y.toInt()) % 4 == 0
                    ? PipColours.leafSummerDark
                    : PipColours.leafSummer);
          }
        }
      }
    }
    for (final mx in [width * 0.2, width * 0.24]) {
      put(mx, ground - 1, PipHouseColours.mushroomStalk);
      rect(mx - 1, ground - 3, mx + 1, ground - 2, PipHouseColours.mushroom);
    }
  }

  /// The tree he's felling (a field oak), its bottom left at [x], and how
  /// far it's fallen ([fall], 0 standing to 1 down): it leans, then lies.
  void fellingTree(Season season, double x, double ground, double fall) {
    final (rows, colours, _) = PipSprites.treeOf(PipTreeKind.oak, season);
    if (fall <= 0) {
      sprite(rows, colours, x, ground);
      return;
    }
    // Leaning: each row pushed over by its height; then gone, a stump.
    final lean = fall.clamp(0.0, 1.0);
    for (var y = 0; y < rows.length; y++) {
      final up = rows.length - 1 - y;
      final dx = (up * up / rows.length * lean * 1.6).round();
      final dy = (up * lean * lean * 0.9).round();
      for (var i = 0; i < rows[y].length; i++) {
        final c = colours[rows[y][i]];
        if (rows[y][i] == '.' || c == null) continue;
        if (up < 3 && lean > 0.2) continue;
        put(x + i + dx, ground - up + dy, c);
      }
    }
    rect(x + 13, ground - 2, x + 16, ground, PipColours.bark);
    rect(x + 13, ground - 2, x + 16, ground - 2, PipHouseColours.plank[1]);
  }

  /// The mine (Round 124): a mountain rising up the right and off the top,
  /// its mouth at its foot, rails and a cart; hazy peaks behind.
  void mine(double ground, int width) {
    final g = ground;
    for (var x = 0; x < width; x++) {
      final top = (g -
              48 -
              22 * math.exp(-math.pow((x - width * 0.25) / 30, 2)) -
              14 * math.exp(-math.pow((x - width * 0.6) / 24, 2)))
          .round();
      for (var y = top; y < g; y++) {
        put(
            x,
            y,
            y > top + 1
                ? PipHouseColours.farPeak
                : PipHouseColours.farPeakEdge);
      }
    }
    final foot = width * 0.36;
    double ridge(num x) =>
        x > foot ? g - 2 - (x - foot) * 1.35 - 6 * math.sin(x / 7.0) : g + 5;
    for (var x = 0; x < width; x++) {
      final top = math.max(-5.0, ridge(x)).round();
      for (var y = math.max(0, top); y <= g; y++) {
        final band = (y + (3 * math.sin(x / 9)).round()) ~/ 7;
        var c = PipHouseColours.stone[(band + _h(x ~/ 5, y ~/ 5)) % 4];
        if (_h(x ~/ 2, y ~/ 2, 4) % 31 == 0) c = PipHouseColours.ore;
        if (_h(x, y) % 41 == 0) c = PipHouseColours.mortar;
        if (y - top < 2) c = PipHouseColours.stoneLight;
        if (y < 26 && y - top < 4) c = PipHouseColours.snow;
        put(x, y, c);
      }
    }
    final pine = PipSprites.treeOf(PipTreeKind.pine, Season.summer);
    for (final tx in [foot + 12, foot + 24]) {
      sprite(pine.$1, pine.$2, tx, ridge(tx + 7) + 2, scale: 0.6);
    }
    // The mouth: a dark arch in timber.
    final m0 = width * 0.72;
    for (var y = g - 30; y <= g; y++) {
      for (var x = m0; x < m0 + 30; x++) {
        if (math.pow(x - m0 - 15, 2) / 225 + math.pow(y - g, 2) / 900 < 1) {
          put(x, y,
              y > g - 26 ? PipHouseColours.tunnel : PipHouseColours.tunnelEdge);
        }
      }
    }
    rect(m0 - 3, g - 34, m0, g, PipHouseColours.beam);
    rect(m0 + 30, g - 34, m0 + 33, g, PipHouseColours.beam);
    rect(m0 - 6, g - 37, m0 + 36, g - 33, PipHouseColours.beam);
    rect(m0 - 6, g - 37, m0 + 36, g - 37, PipHouseColours.beamLight);
    lantern(m0 + 14, g - 31);
    for (var x = foot; x < m0 + 30; x++) {
      put(x, g - 1, PipHouseColours.rail);
    }
    for (var x = foot; x < m0 + 30; x += 5) {
      rect(x, g, x + 2, g, PipHouseColours.beam);
    }
    final cx = m0 - 34;
    rect(cx, g - 12, cx + 20, g - 4, PipHouseColours.cart);
    rect(cx, g - 12, cx + 20, g - 12, PipHouseColours.cartLight);
    for (var x = cx + 2; x < cx + 19; x += 4) {
      rect(x, g - 15, x + 3, g - 13,
          PipHouseColours.stone[_h(x.round(), 1) % 4]);
    }
    rect(cx + 3, g - 4, cx + 5, g - 2, PipHouseColours.wheel);
    rect(cx + 16, g - 4, cx + 18, g - 2, PipHouseColours.wheel);
  }

  /// The boulder he breaks stone off, its middle at [cx]; smaller as
  /// [left] (1 whole to 0 broken) falls.
  void boulder(double cx, double ground, double left) {
    final r = 7 + 4 * left;
    for (var y = (ground - r * 1.3).floor(); y <= ground; y++) {
      for (var x = (cx - r).floor(); x <= cx + r; x++) {
        if (math.pow(x - cx, 2) / (r * r) +
                math.pow(y - ground, 2) / (r * r * 1.7) <
            1) {
          put(
              x,
              y,
              (x - cx) + (y - ground + r) < -r * 0.7
                  ? PipHouseColours.stoneLight
                  : PipHouseColours.stone[_h(x ~/ 2, y ~/ 2) % 4]);
        }
      }
    }
    for (var k = 0; k < 6; k++) {
      put(cx - 5 + k ~/ 2, ground - r + 3 + k, PipHouseColours.mortar);
    }
  }

  /// The mine's floor: gravel.
  void gravel(double ground, int width, int below) {
    for (var x = 0; x < width; x++) {
      for (var y = ground; y < ground + below; y++) {
        put(
            x,
            y,
            _h(x, y.toInt()) % 5 == 0
                ? PipHouseColours.gravelDark
                : PipHouseColours.gravel);
      }
    }
  }

  /// The beach (Round 123): the sea to the horizon, waves foaming onto
  /// wet sand, shells, a starfish, beach grass; [t] moves the waves.
  void beach(double ground, int width, int below, double t) {
    final horizon = ground - 34, shore = ground - 10;
    for (var y = horizon; y < shore; y++) {
      final p = (y - horizon) / (shore - horizon);
      final base =
          Color.lerp(PipHouseColours.seaDeep, PipHouseColours.seaShallow, p)!;
      for (var x = 0; x < width; x++) {
        var c = base;
        if ((x * 7 + y.toInt() * 13 + (t * 3).floor()) % 41 == 0) {
          c = PipHouseColours.seaGlint;
        }
        if ((y - horizon).toInt() % 6 == 0 &&
            (x + y.toInt() * 5 + (t * 4).floor()) % 17 < 6) {
          c = PipHouseColours.seaLine;
        }
        put(x, y, c);
      }
    }
    for (var x = 0; x < width; x++) {
      final wave = (2 * math.sin(x / 9.0 + t)).round();
      put(x, shore + wave, PipHouseColours.foam);
      put(x, shore + wave + 1, PipHouseColours.foamShade);
      for (var y = shore + wave + 2; y < ground + below; y++) {
        var c = PipHouseColours.sand[_h(x ~/ 2, y.toInt()) % 3];
        if (y < shore + wave + 5) c = PipHouseColours.wetSand;
        if ((x * 2 + y.toInt()) % 13 == 0) c = PipHouseColours.sandDark;
        put(x, y, c);
      }
    }
    for (final sx in [width * 0.12, width * 0.36, width * 0.64]) {
      rect(sx, ground + 2, sx + 2, ground + 3, PipHouseColours.shell);
      put(sx + 1, ground + 2, PipHouseColours.shellShade);
    }
    final st = width * 0.55;
    rect(st, ground, st + 2, ground + 2, PipHouseColours.starfish);
    put(st - 1, ground + 1, PipHouseColours.starfish);
    put(st + 3, ground + 1, PipHouseColours.starfish);
    put(st + 1, ground - 1, PipHouseColours.starfish);
    for (final gx in [width * 0.86, width * 0.9, width * 0.94]) {
      for (var k = 0; k < 7; k++) {
        put(gx + k ~/ 3, ground - k,
            k.isOdd ? PipColours.grassLight : PipColours.grass);
      }
    }
  }

  /// His bucket on the sand, and the hole he's dug, [dug] deep (0 to 1).
  void bucketAndHole(double x, double ground, double dug) {
    final d = (2 + 4 * dug).round();
    rect(x, ground - 1, x + 12, ground - 1 + d, PipHouseColours.sandDark);
    rect(x + 1, ground, x + 11, ground - 1 + d, PipHouseColours.wetSand);
    rect(x + 18, ground - 7, x + 26, ground, PipHouseColours.bucket);
    rect(x + 17, ground - 8, x + 27, ground - 8, PipHouseColours.bucketRim);
  }

  /// [kind]'s icon (12 x 12, top left at [x], [y]) for his inventory
  /// card: two planks, a stone, a heap of sand, a pane.
  void icon(String kind, double x, double y) {
    void r(int x0, int y0, int x1, int y1, Color c) =>
        rect(x + x0, y + y0, x + x1, y + y1, c);
    switch (kind) {
      case 'wood':
        r(1, 3, 10, 5, PipHouseColours.plank[1]);
        r(1, 6, 10, 8, PipHouseColours.plank[0]);
        r(1, 5, 10, 5, PipHouseColours.plankDark);
        r(10, 3, 10, 8, PipHouseColours.plankDark);
        r(9, 4, 9, 4, PipHouseColours.grain);
        r(9, 7, 9, 7, PipHouseColours.grain);
      case 'stone':
        r(2, 3, 9, 9, PipHouseColours.stone[1]);
        r(2, 3, 9, 3, PipHouseColours.stoneLight);
        r(9, 4, 9, 9, PipHouseColours.stone[3]);
        r(4, 6, 4, 6, PipHouseColours.mortar);
      case 'sand':
        for (var row = 0; row < 6; row++) {
          for (var col = 6 - row; col <= 6 + row; col++) {
            r(
                col,
                4 + row,
                col,
                4 + row,
                (col + row) % 4 == 0
                    ? PipHouseColours.sandDark
                    : PipHouseColours.sand[(col + row) % 3]);
          }
        }
      default:
        r(2, 2, 9, 9, PipHouseColours.frame);
        r(3, 3, 8, 8, PipHouseColours.glass);
        r(3, 7, 8, 8, PipHouseColours.glassDark);
        r(4, 4, 5, 4, PipHouseColours.glassLight);
        r(4, 5, 4, 5, PipHouseColours.glassLight);
    }
  }

  /// A lantern hanging, its top at [x], [y].
  void lantern(double x, double y) {
    put(x + 1, y - 2, PipHouseColours.iron);
    rect(x, y - 1, x + 2, y - 1, PipHouseColours.iron);
    rect(x, y, x + 2, y + 3, PipHouseColours.lantern);
    rect(x, y + 4, x + 2, y + 4, PipHouseColours.iron);
  }

  /// One of what he carries, flying (or in the inventory card), its top
  /// left at [x], [y]: 3 x 2 of its colour.
  void item(String kind, double x, double y) {
    final c = switch (kind) {
      'wood' => PipHouseColours.plank[1],
      'stone' => PipHouseColours.stone[2],
      'sand' => PipHouseColours.sand[0],
      _ => PipHouseColours.glass,
    };
    rect(x, y, x + 2, y + 1, c);
    put(x, y, Color.lerp(c, PipHouseColours.glassLight, 0.4)!);
  }

  /// A puff of dust or smoke round [x], [y], [t] (0 to 1) through it.
  void puff(double x, double y, double t) {
    final r = 1 + 2 * t;
    for (final (dx, dy) in [
      (0.0, 0.0),
      (3.0, -2.0),
      (-3.0, -1.0),
      (1.0, -4.0)
    ]) {
      rect(
          x + dx * (0.5 + t),
          y + dy * (0.5 + t) - t * 3,
          x + dx * (0.5 + t) + r - 1,
          y + dy * (0.5 + t) - t * 3 + r - 1,
          PipHouseColours.smoke.withValues(alpha: 1 - t));
    }
  }
}
