/// The main sections of the app (the bottom-navigation tabs), in order.
enum AppSection {
  notes('Notes'),
  shop('Shop'),
  planner('Planner'),
  hub('Hub');

  const AppSection(this.label);

  /// Shown to the user.
  final String label;

  /// The section stored as [id] (its [name]), or null if unknown. `other`
  /// is the Hub's id from before it was renamed (O11).
  static AppSection? fromId(String id) =>
      id == 'other' ? hub : values.where((s) => s.name == id).firstOrNull;
}
