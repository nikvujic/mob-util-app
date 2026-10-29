/// The unit converter (Round 118): pairs of units, each way, in groups.
/// Nothing is stored; the page only shows them.
class UnitPair {
  final String left;
  final String right;

  /// Their names, for those who don't know "lb" (Round 119).
  final String leftName;
  final String rightName;

  /// A value in [left] as [right], and back.
  final double Function(double) toRight;
  final double Function(double) toLeft;

  /// Whether a value can be below zero (temperatures).
  final bool signed;

  const UnitPair(this.left, this.leftName, this.right, this.rightName,
      this.toRight, this.toLeft,
      {this.signed = false});

  /// A pair that's one number times the other: 1 [left] is [factor]
  /// [right].
  UnitPair.scaled(
      this.left, this.leftName, this.right, this.rightName, double factor)
      : toRight = ((v) => v * factor),
        toLeft = ((v) => v / factor),
        signed = false;
}

class UnitGroup {
  final String title;
  final List<UnitPair> pairs;

  const UnitGroup(this.title, this.pairs);
}

/// The converter's units (Round 119's order: temperature, length,
/// weight, volume, speed, then cooking). US cups, spoons and gallons.
final unitGroups = [
  UnitGroup('Temperature', [
    UnitPair('°C', 'Celsius', '°F', 'Fahrenheit', (c) => c * 9 / 5 + 32,
        (f) => (f - 32) * 5 / 9,
        signed: true),
  ]),
  UnitGroup('Length', [
    UnitPair.scaled('cm', 'Centimetres', 'in', 'Inches', 1 / 2.54),
    UnitPair.scaled('m', 'Metres', 'ft', 'Feet', 1 / 0.3048),
    UnitPair.scaled('km', 'Kilometres', 'mi', 'Miles', 1 / 1.609344),
  ]),
  UnitGroup('Weight', [
    UnitPair.scaled('kg', 'Kilograms', 'lb', 'Pounds', 1 / 0.45359237),
  ]),
  UnitGroup('Volume', [
    UnitPair.scaled('l', 'Litres', 'gal', 'Gallons', 1 / 3.785411784),
  ]),
  UnitGroup('Speed', [
    UnitPair.scaled(
        'km/h', 'Kilometres an hour', 'mph', 'Miles an hour', 1 / 1.609344),
  ]),
  UnitGroup('Cooking', [
    UnitPair.scaled('g', 'Grams', 'oz', 'Ounces', 1 / 28.349523125),
    UnitPair.scaled('ml', 'Millilitres', 'cup', 'Cups', 1 / 236.5882365),
    UnitPair.scaled(
        'ml', 'Millilitres', 'fl oz', 'Fluid ounces', 1 / 29.5735295625),
    UnitPair.scaled(
        'ml', 'Millilitres', 'tbsp', 'Tablespoons', 1 / 14.78676478125),
    UnitPair.scaled('ml', 'Millilitres', 'tsp', 'Teaspoons', 1 / 4.92892159375),
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
