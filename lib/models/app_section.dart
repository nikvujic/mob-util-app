/// The main sections of the app (the bottom-navigation tabs), in order.
enum AppSection {
  notes('Notes'),
  shop('Shop'),
  planner('Planner'),
  other('Other');

  const AppSection(this.label);

  /// Shown to the user.
  final String label;

  /// The section stored as [id] (its [name]), or null if unknown.
  static AppSection? fromId(String id) =>
      values.where((s) => s.name == id).firstOrNull;
}
