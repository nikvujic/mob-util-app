/// The pages in the Hub (O9, O11), each once, here. Their [name] is the
/// stable id stored in the layout (and later in page locks and the
/// quick-access menu), so a page is never renamed here, only its [label].
///
/// Everything that lists the Hub's pages reads them from here, and every
/// page must say how it looks, opens, counts and clears its data (see
/// `pages/hub/tools.dart` and `providers/section_data_provider.dart`):
/// those switches don't compile until a new page is in all of them.
enum HubTool {
  // Their order is the Hub's default (Round 48: the user's), for a Hub not
  // arranged by hand.
  counters('Counters'),
  medicine('Medicine'),
  placard('Placard'),

  /// Pip's home (Round 35): shown once he's hatched. No lock (he's no
  /// secret) and nothing for Clear data (his life isn't a page's data).
  pip('Pip'),

  /// Recipes (Round 42), with the ingredients list they pick from.
  recipes('Recipes'),

  /// The food tracker (O14, Round 46).
  food('Food'),

  /// Birthdays & dates (Round 57).
  dates('Dates'),

  /// Subscriptions (Round 79): what's paid, when, and what to do about it.
  subscriptions('Subscriptions'),

  /// Spotify in the morning (Round 93): a time, days and a volume; no
  /// data to lock or clear.
  spotify('Spotify'),

  /// Packing lists (Round 94): lists of things to pack, by section.
  packing('Packing'),

  /// People (Round 108): the people you know on a board, with family
  /// trees.
  people('People');

  const HubTool(this.label);

  /// Whether it can have a lock of its own (O7).
  bool get lockable => this != pip && this != spotify;

  /// Whether Clear data lists it.
  bool get clearable => this != pip && this != spotify;

  /// Shown to the user (and said by screen readers).
  final String label;

  /// The page stored as [id], or null if unknown (e.g. from a newer app).
  static HubTool? fromId(String id) =>
      values.where((t) => t.name == id).firstOrNull;
}

/// Where the pages go (O9, O8): the Hub's tiles in the user's order, kept
/// as page ids. Unknown ids are dropped, and pages not in it yet (new
/// ones) come at the end, so adding a page needs no change to stored
/// data. Later: the quick-access menu, sections.
class PageLayout {
  /// Every page in the Hub, once, in order.
  final List<HubTool> hub;

  PageLayout(Iterable<HubTool> order)
      : hub = List.unmodifiable([
          ...{...order}, // without repeats
          ...HubTool.values.where((t) => !order.contains(t)),
        ]);

  static final initial = PageLayout(const []);

  /// [tool] moved to [index] in the Hub.
  PageLayout moved(HubTool tool, int index) {
    final order = [...hub]..remove(tool);
    order.insert(index.clamp(0, order.length), tool);
    return PageLayout(order);
  }

  Map<String, dynamic> toJson() => {
        'hub': [for (final t in hub) t.name],
      };

  /// Also reads layout.json version 1, which called the Hub `other`.
  factory PageLayout.fromJson(Map<String, dynamic> json) => PageLayout([
        for (final id
            in (json['hub'] ?? json['other']) as List<dynamic>? ?? const [])
          if (HubTool.fromId(id as String) case final tool?) tool,
      ]);
}
