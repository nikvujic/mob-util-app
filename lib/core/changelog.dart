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

/// The changes from every version after [from] up to [version] (Round
/// 61: updates not read yet pile up), each under its own `## X.Y.Z`,
/// newest first; [changesFor] when [from] is null or there's only the
/// one (or none) after it. Round 70: always the whole of [version]'s
/// minor version too (1.28.0 with 1.28.2, even if it was read).
String? changesSince(String changelog, String version, String? from) {
  final heading = RegExp(r'^## \[([^\]]+)\].*$', multiLine: true);
  final sections = heading.allMatches(changelog).toList();
  final after = from == null ? null : _numbers(from);
  final upTo = _numbers(version);
  if (after == null || upTo == null) return changesFor(changelog, version);
  final picked = [
    for (final (i, m) in sections.indexed)
      if (_numbers(m.group(1)!) case final v?
          when _compare(v, upTo) <= 0 &&
              (_compare(v, after) > 0 || (v[0] == upTo[0] && v[1] == upTo[1])))
        i,
  ];
  if (picked.length <= 1) return changesFor(changelog, version);
  String body(int at) {
    final start = sections[at].end;
    final end =
        at + 1 < sections.length ? sections[at + 1].start : changelog.length;
    return changelog.substring(start, end).trim();
  }

  return [
    for (final i in picked) '## ${sections[i].group(1)}\n\n${body(i)}',
  ].join('\n\n');
}

List<int>? _numbers(String version) {
  final parts = version.split('.').map(int.tryParse).toList();
  if (parts.length != 3 || parts.contains(null)) return null;
  return parts.cast<int>();
}

int _compare(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

/// The What's new heading for [changes] (from [changesSince]): "in"
/// [version] when they're only its minor version's, else "since" [from].
String whatsNewTitle(String changes, String version, String? from) {
  final minor = _minorOf(version);
  final shown = RegExp(r'^## (\S+)', multiLine: true)
      .allMatches(changes)
      .map((m) => _minorOf(m[1]!));
  return from != null && shown.any((m) => m != minor)
      ? "# What's new since $from"
      : "# What's new in $version";
}

/// "1.14" of "1.14.1"; null if it isn't three numbers.
String? _minorOf(String version) {
  final parts = version.split('.');
  return parts.length == 3 ? '${parts[0]}.${parts[1]}' : null;
}

/// The version number of an app version as shown ("0.24.0 (25)" →
/// "0.24.0").
String versionNumber(String shown) => shown.split(' ').first;
