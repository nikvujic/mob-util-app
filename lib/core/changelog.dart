/// The changes listed for [version] in a CHANGELOG in the Keep a Changelog
/// shape (`## [X.Y.Z] - date`, then `### Added` and so on), without its
/// own heading; the newest section if [version] has none. Null if there's
/// no section at all.
String? changesFor(String changelog, String version) {
  final heading = RegExp(r'^## \[([^\]]+)\].*$', multiLine: true);
  final sections = heading.allMatches(changelog).toList();
  if (sections.isEmpty) return null;
  final index = sections.indexWhere((m) => m.group(1) == version);
  final at = index == -1 ? 0 : index;
  final start = sections[at].end;
  final end =
      at + 1 < sections.length ? sections[at + 1].start : changelog.length;
  return changelog.substring(start, end).trim();
}

/// The version number of an app version as shown ("0.24.0 (25)" →
/// "0.24.0").
String versionNumber(String shown) => shown.split(' ').first;
