import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/units.dart';

/// The unit converter's rules (Round 118).
void main() {
  UnitPair pair(String left, String right) => [
        for (final g in unitGroups) ...g.pairs,
      ].firstWhere((p) => p.left == left && p.right == right);

  test('known values, each way', () {
    expect(pair('°C', '°F').toRight(100), closeTo(212, 1e-9));
    expect(pair('°C', '°F').toLeft(-40), closeTo(-40, 1e-9));
    expect(pair('kg', 'lb').toRight(1), closeTo(2.20462, 1e-5));
    expect(pair('cm', 'in').toLeft(1), closeTo(2.54, 1e-9));
    expect(pair('km', 'mi').toRight(1.609344), closeTo(1, 1e-9));
    expect(pair('ml', 'cup').toLeft(1), closeTo(236.588, 1e-3));
    expect(pair('ml', 'tsp').toLeft(3), closeTo(14.787, 1e-3),
        reason: 'three teaspoons, a tablespoon');
    expect(pair('g', 'oz').toRight(28.349523125), closeTo(1, 1e-9));
  });

  test('every pair back and forth gives what it started with', () {
    for (final g in unitGroups) {
      for (final p in g.pairs) {
        expect(p.toLeft(p.toRight(37.5)), closeTo(37.5, 1e-9),
            reason: '${p.left} ↔ ${p.right}');
      }
    }
  });

  test('typed: a comma or a point; nothing or not a number is null', () {
    expect(parseAmount('1,5'), 1.5);
    expect(parseAmount(' 2.25 '), 2.25);
    expect(parseAmount('-3'), -3);
    for (final t in ['', '-', '.', 'a', '1.2.3']) {
      expect(parseAmount(t), isNull, reason: t);
    }
  });

  test('shown short: three decimals at most, no trailing zeros', () {
    expect(formatAmount(2.5), '2.5');
    expect(formatAmount(1000), '1000');
    expect(formatAmount(0.12549), '0.125');
    expect(formatAmount(1 / 3), '0.333');
    expect(formatAmount(-0.0001), '0');
    expect(formatAmount(double.nan), '');
  });
}
