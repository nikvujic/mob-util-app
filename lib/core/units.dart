/// The unit converter (Round 118): pairs of units, each way, in groups.
/// Nothing is stored; the page only shows them.
class UnitPair {
  final String left;
  final String right;

  /// A value in [left] as [right], and back.
  final double Function(double) toRight;
  final double Function(double) toLeft;

  /// Whether a value can be below zero (temperatures).
  final bool signed;

  const UnitPair(this.left, this.right, this.toRight, this.toLeft,
      {this.signed = false});

  /// A pair that's one number times the other: 1 [left] is [factor]
  /// [right].
  UnitPair.scaled(this.left, this.right, double factor)
      : toRight = ((v) => v * factor),
        toLeft = ((v) => v / factor),
        signed = false;
}

class UnitGroup {
  final String title;
  final List<UnitPair> pairs;

  const UnitGroup(this.title, this.pairs);
}

/// The converter's units, kitchen first. US cups, spoons and gallons.
final unitGroups = [
  UnitGroup('Cooking', [
    UnitPair.scaled('g', 'oz', 1 / 28.349523125),
    UnitPair.scaled('ml', 'cup', 1 / 236.5882365),
    UnitPair.scaled('ml', 'fl oz', 1 / 29.5735295625),
    UnitPair.scaled('ml', 'tbsp', 1 / 14.78676478125),
    UnitPair.scaled('ml', 'tsp', 1 / 4.92892159375),
  ]),
  UnitGroup('Temperature', [
    UnitPair('°C', '°F', (c) => c * 9 / 5 + 32, (f) => (f - 32) * 5 / 9,
        signed: true),
  ]),
  UnitGroup('Weight', [
    UnitPair.scaled('kg', 'lb', 1 / 0.45359237),
  ]),
  UnitGroup('Volume', [
    UnitPair.scaled('l', 'gal', 1 / 3.785411784),
  ]),
  UnitGroup('Length', [
    UnitPair.scaled('cm', 'in', 1 / 2.54),
    UnitPair.scaled('m', 'ft', 1 / 0.3048),
    UnitPair.scaled('km', 'mi', 1 / 1.609344),
  ]),
  UnitGroup('Speed', [
    UnitPair.scaled('km/h', 'mph', 1 / 1.609344),
  ]),
];

/// A typed number ("1,5" as well as "1.5"), or null.
double? parseAmount(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty || t == '-' || t == '.') return null;
  return double.tryParse(t);
}

/// A converted number, shown short: up to three decimals, no trailing
/// zeros ("2.5", "0.125", "1000").
String formatAmount(double value) {
  if (!value.isFinite) return '';
  var s = value.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}
