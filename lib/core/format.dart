// Formatting shared across the app, so dates and counts read the same
// everywhere.

/// `2026-10-08  09:30`, in local time.
String formatDateTime(DateTime dt) {
  final t = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}  '
      '${two(t.hour)}:${two(t.minute)}';
}

/// `1 note`, `3 notes`.
String countOf(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';
