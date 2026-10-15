/// The changes listed for [version] in a CHANGELOG in the Keep a Changelog
/// shape (`## [X.Y.Z] - date`, then `### Added` and so on), without its
/// own heading; the newest section if [version] has none. Null if there's
/// no section at all.
///
/// A patch shows its whole minor version (Round 48): for 1.14.1, the
/// sections of 1.14.1 and 1.14.0, newest first, each under `## 1.14.1`
/// and so on, so what came with the minor version isn't missed.
String? changesFor(String changelog, String version) {
  final heading = RegExp(r'^## \[([^\]]+)\].*$', multiLine: true);
  final sections = heading.allMatches(changelog).toList();
  if (sections.isEmpty) return null;
  String body(int at) {
    final start = sections[at].end;
    final end =
        at + 1 < sections.length ? sections[at + 1].start : changelog.length;
    return changelog.substring(start, end).trim();
  }

  final index = sections.indexWhere((m) => m.group(1) == version);
  if (index == -1) return body(0);
  // This one and the older ones of its minor version (they follow it).
  final minor = _minorOf(version);
  final same = [
    for (var i = index; i < sections.length; i++)
      if (minor != null && _minorOf(sections[i].group(1)!) == minor) i,
  ];
  if (same.length <= 1) return body(index);
  return [
    for (final i in same) '## ${sections[i].group(1)}\n\n${body(i)}',
  ].join('\n\n');
}

/// "1.14" of "1.14.1"; null if it isn't three numbers.
String? _minorOf(String version) {
  final parts = version.split('.');
  return parts.length == 3 ? '${parts[0]}.${parts[1]}' : null;
}

/// The version number of an app version as shown ("0.24.0 (25)" →
/// "0.24.0").
String versionNumber(String shown) => shown.split(' ').first;
