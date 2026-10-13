/// The few Markdown pieces notes understand (N9), for styling the text as
/// it's typed. The text itself never changes here: these only say how each
/// part of it looks.
library;

/// What a stretch of text is.
enum MdRole {
  /// The note's own words.
  text,

  /// Symbols that only format (`##`, `**`): shown faint.
  marker,

  /// A list item's `-` or `1.`: part of the content, shown a bit muted.
  listMarker,

  /// A checkbox's `- [ ] ` / `- [x] ` (N15): drawn as a box.
  checkbox,
}

/// A stretch of a note's text, [start] to [end], and how it looks.
class MdRun {
  final int start;
  final int end;
  final MdRole role;

  /// 1–4 inside a `#`–`####` heading line, else 0.
  final int heading;
  final bool bold;
  final bool italic;
  final bool strike;

  /// In a ticked checkbox item (N15): shown done.
  final bool done;

  const MdRun(
    this.start,
    this.end, {
    this.role = MdRole.text,
    this.heading = 0,
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.done = false,
  });

  bool _sameLook(MdRun other) =>
      role == other.role &&
      heading == other.heading &&
      bold == other.bold &&
      italic == other.italic &&
      strike == other.strike &&
      done == other.done;

  @override
  String toString() => 'MdRun($start–$end, ${role.name}'
      '${heading > 0 ? ', h$heading' : ''}${bold ? ', bold' : ''}'
      '${italic ? ', italic' : ''}${strike ? ', strike' : ''}'
      '${done ? ', done' : ''})';
}

final _heading = RegExp(r'^(#{1,4}) ');
final _task = RegExp(r'^(\s*)([-*+]) \[([ xX])\] ');
final _bullet = RegExp(r'^(\s*)([-*+]) ');
final _numbered = RegExp(r'^(\s*)(\d{1,3})([.)]) ');
final _bold = RegExp(r'\*\*(?=\S)(.+?)(?<=\S)\*\*');
final _strike = RegExp(r'~~(?=\S)(.+?)(?<=\S)~~');
final _italic = RegExp(r'(?<!\*)\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?!\*)');

/// How [text] looks, as runs covering all of it in order (none for empty
/// text). Inline styles don't cross lines.
List<MdRun> markdownRuns(String text) {
  final runs = <MdRun>[];
  var lineStart = 0;
  while (lineStart <= text.length) {
    final newline = text.indexOf('\n', lineStart);
    final lineEnd = newline == -1 ? text.length : newline;
    _line(text.substring(lineStart, lineEnd), lineStart, runs);
    if (newline == -1) break;
    _add(runs, MdRun(newline, newline + 1));
    lineStart = newline + 1;
  }
  return runs;
}

void _line(String line, int offset, List<MdRun> runs) {
  if (line.isEmpty) return;
  final n = line.length;
  final role = List.filled(n, MdRole.text);
  final bold = List.filled(n, false);
  final italic = List.filled(n, false);
  final strike = List.filled(n, false);
  var heading = 0;
  var done = false;

  // What the line starts with: a heading, a checkbox or a list item.
  var body = 0;
  final h = _heading.firstMatch(line);
  final task = _task.firstMatch(line);
  final listItem = _bullet.firstMatch(line) ?? _numbered.firstMatch(line);
  if (h != null) {
    heading = h.group(1)!.length;
    body = h.end;
    role.fillRange(0, body, MdRole.marker);
  } else if (task != null) {
    body = task.end;
    done = task.group(3) != ' ';
    role.fillRange(task.group(1)!.length, body, MdRole.checkbox);
  } else if (listItem != null) {
    body = listItem.end;
    role.fillRange(listItem.group(1)!.length, body, MdRole.listMarker);
  }

  // Inline styles, in the rest of the line; the symbols are markers.
  void style(RegExp pattern, List<bool> flag, int markerLength) {
    for (final m in pattern.allMatches(line, body)) {
      final inner = m.start + markerLength, innerEnd = m.end - markerLength;
      // Already symbols of another style (e.g. the stars of **bold**).
      if (role[m.start] == MdRole.marker || role[m.end - 1] == MdRole.marker) {
        continue;
      }
      flag.fillRange(inner, innerEnd, true);
      role.fillRange(m.start, inner, MdRole.marker);
      role.fillRange(innerEnd, m.end, MdRole.marker);
    }
  }

  style(_bold, bold, 2);
  style(_strike, strike, 2);
  style(_italic, italic, 1);

  for (var i = 0; i < n; i++) {
    _add(
      runs,
      MdRun(
        offset + i,
        offset + i + 1,
        role: role[i],
        heading: heading,
        bold: bold[i],
        italic: italic[i],
        strike: strike[i],
        done: done && i >= body,
      ),
    );
  }
}

/// Adds [run], merging it into the last one if they look the same.
void _add(List<MdRun> runs, MdRun run) {
  if (runs.isNotEmpty &&
      runs.last.end == run.start &&
      runs.last._sameLook(run)) {
    final last = runs.removeLast();
    runs.add(
      MdRun(
        last.start,
        run.end,
        role: last.role,
        heading: last.heading,
        bold: last.bold,
        italic: last.italic,
        strike: last.strike,
        done: last.done,
      ),
    );
  } else {
    runs.add(run);
  }
}

/// The result of Enter in a list: the new text and where the cursor goes.
typedef ListEdit = ({String text, int cursor});

/// When a line break was just typed at [cursor] (so `text[cursor - 1]` is
/// the new `\n`) right after a list item, continues the list: the next line
/// starts with the same kind of marker (the next number for numbered
/// lists). On an item with nothing in it, ends the list instead: the empty
/// item's marker goes, and so does the new line break. Null if the line
/// before isn't a list item.
ListEdit? continueList(String text, int cursor) {
  if (cursor < 1 || cursor > text.length || text[cursor - 1] != '\n') {
    return null;
  }
  // At the very start there's no line before (and lastIndexOf can't
  // start at -1).
  final lineStart = cursor < 2 ? 0 : text.lastIndexOf('\n', cursor - 2) + 1;
  final line = text.substring(lineStart, cursor - 1);

  final String next;
  final RegExpMatch item;
  final task = _task.firstMatch(line);
  final bullet = _bullet.firstMatch(line);
  final numbered = _numbered.firstMatch(line);
  if (task != null) {
    // The next one starts unticked.
    item = task;
    next = '${task.group(1)}${task.group(2)} [ ] ';
  } else if (bullet != null) {
    item = bullet;
    next = '${bullet.group(1)}${bullet.group(2)} ';
  } else if (numbered != null) {
    item = numbered;
    final number = int.parse(numbered.group(2)!) + 1;
    next = '${numbered.group(1)}$number${numbered.group(3)} ';
  } else {
    return null;
  }

  if (line.substring(item.end).trim().isEmpty) {
    // An empty item: Enter ends the list.
    final before = text.substring(0, lineStart);
    return (text: before + text.substring(cursor), cursor: lineStart);
  }
  return (
    text: text.substring(0, cursor) + next + text.substring(cursor),
    cursor: cursor + next.length,
  );
}

/// A checkbox item's box (N15): [start] is where its `-` is, [box] where
/// its `[` is.
typedef MdCheckbox = ({int start, int box, bool checked});

/// The checkbox on the line holding [offset], if that line is one.
MdCheckbox? checkboxOnLine(String text, int offset) {
  if (offset < 0 || offset > text.length) return null;
  final lineStart = offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
  final lineEnd = text.indexOf('\n', lineStart);
  final line = text.substring(lineStart, lineEnd == -1 ? text.length : lineEnd);
  final task = _task.firstMatch(line);
  if (task == null) return null;
  final start = lineStart + task.group(1)!.length;
  return (start: start, box: start + 2, checked: task.group(3) != ' ');
}

/// [text] with the checkbox whose `[` is at [box] ticked or unticked.
String toggleCheckbox(String text, int box) {
  final checked = text[box + 1] != ' ';
  return text.replaceRange(box + 1, box + 2, checked ? ' ' : 'x');
}

/// The checklist button (N15): makes the line holding [cursor] a checkbox
/// item (a bullet becomes one), or a plain line again if it already is
/// one. The cursor stays with the text it was in.
ListEdit toggleChecklistLine(String text, int cursor) {
  cursor = cursor.clamp(0, text.length);
  final lineStart = cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
  final lineEnd = text.indexOf('\n', lineStart);
  final line = text.substring(lineStart, lineEnd == -1 ? text.length : lineEnd);

  ListEdit replace(int from, int to, String put) {
    final at = lineStart + from, end = lineStart + to;
    final shift = put.length - (to - from);
    return (
      text: text.replaceRange(at, end, put),
      cursor: cursor < at
          ? cursor
          : cursor >= end
              ? cursor + shift
              : at + put.length,
    );
  }

  final task = _task.firstMatch(line);
  if (task != null) return replace(task.group(1)!.length, task.end, '');
  final bullet = _bullet.firstMatch(line);
  if (bullet != null) {
    final indent = bullet.group(1)!.length;
    return replace(indent, bullet.end, '${bullet.group(2)} [ ] ');
  }
  final indent = RegExp(r'^\s*').firstMatch(line)!.end;
  return replace(indent, indent, '- [ ] ');
}
