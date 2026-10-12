/// The pages in Other (O9), each once, here. Their [name] is the stable
/// id stored in the layout (and later in page locks and the quick-access
/// menu), so a page is never renamed here, only its [label].
///
/// Everything that lists Other's pages reads them from here, and every
/// page must say how it looks, opens, counts and clears its data (see
/// `pages/other/tools.dart` and `providers/section_data_provider.dart`):
/// those switches don't compile until a new page is in all of them.
enum OtherTool {
  counters('Counters'),
  placard('Placard');

  const OtherTool(this.label);

  /// Shown to the user (and said by screen readers).
  final String label;

  /// The page stored as [id], or null if unknown (e.g. from a newer app).
  static OtherTool? fromId(String id) =>
      values.where((t) => t.name == id).firstOrNull;
}

/// Where the pages go (O9, O8): Other's tiles in the user's order, kept as
/// page ids. Unknown ids are dropped, and pages not in it yet (new ones)
/// come at the end, so adding a page needs no change to stored data.
/// Later: the quick-access menu, sections.
class PageLayout {
  /// Every page in Other, once, in order.
  final List<OtherTool> other;

  PageLayout(Iterable<OtherTool> order)
      : other = List.unmodifiable([
          ...{...order}, // without repeats
          ...OtherTool.values.where((t) => !order.contains(t)),
        ]);

  static final initial = PageLayout(const []);

  /// [tool] moved to [index] in Other.
  PageLayout moved(OtherTool tool, int index) {
    final order = [...other]..remove(tool);
    order.insert(index.clamp(0, order.length), tool);
    return PageLayout(order);
  }

  Map<String, dynamic> toJson() => {
        'other': [for (final t in other) t.name],
      };

  factory PageLayout.fromJson(Map<String, dynamic> json) => PageLayout([
        for (final id in (json['other'] as List<dynamic>? ?? const []))
          if (OtherTool.fromId(id as String) case final tool?) tool,
      ]);
}
