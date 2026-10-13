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

  /// A quote's `>` (and the space after it) (N17): drawn as a bar.
  quoteMarker,

  /// A divider line, `---` (N17): drawn as a line across.
  divider,
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

  /// Code (N17): between backticks, or a line of a ``` block ([block]).
  final bool code;
  final bool block;

  /// Between `==`: highlighted (N17).
  final bool highlight;

  /// On a `>` line: a quote (N17).
  final bool quote;

  const MdRun(
    this.start,
    this.end, {
    this.role = MdRole.text,
    this.heading = 0,
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.done = false,
    this.code = false,
    this.block = false,
    this.highlight = false,
    this.quote = false,
  });

  bool _sameLook(MdRun other) =>
      role == other.role &&
      heading == other.heading &&
      bold == other.bold &&
      italic == other.italic &&
      strike == other.strike &&
      done == other.done &&
      code == other.code &&
      block == other.block &&
      highlight == other.highlight &&
      quote == other.quote;

  @override
  String toString() => 'MdRun($start–$end, ${role.name}'
      '${heading > 0 ? ', h$heading' : ''}${bold ? ', bold' : ''}'
      '${italic ? ', italic' : ''}${strike ? ', strike' : ''}'
      '${done ? ', done' : ''}${code ? ', code' : ''}'
      '${block ? ', block' : ''}${highlight ? ', highlight' : ''}'
      '${quote ? ', quote' : ''})';
}

final _heading = RegExp(r'^(#{1,4}) ');
final _task = RegExp(r'^(\s*)([-*+]) \[([ xX])\] ');
final _bullet = RegExp(r'^(\s*)([-*+]) ');
final _numbered = RegExp(r'^(\s*)(\d{1,3})([.)]) ');
final _bold = RegExp(r'\*\*(?=\S)(.+?)(?<=\S)\*\*');
final _strike = RegExp(r'~~(?=\S)(.+?)(?<=\S)~~');
final _italic = RegExp(r'(?<!\*)\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?!\*)');
final _code = RegExp(r'`([^`]+)`');
final _highlight = RegExp(r'==(?=\S)(.+?)(?<=\S)==');
final _quote = RegExp(r'^(\s*)> ?');
final _divider = RegExp(r'^\s*(-{3,}|\*{3,}|_{3,})\s*$');
final _fence = RegExp(r'^\s*```');

/// Whether [line] opens or closes a code block (N17).
bool isFence(String line) => _fence.hasMatch(line);

/// How [text] looks, as runs covering all of it in order (none for empty
/// text). Inline styles don't cross lines.
List<MdRun> markdownRuns(String text) {
  final runs = <MdRun>[];
  var lineStart = 0;
  // Inside a ``` code block (N17): its lines are code, nothing else. A
  // block needs its closing fence (Round 29): a lone ``` is just text,
  // so typing one, or quoting one, doesn't turn the rest into code.
  var inBlock = false;
  var fencesLeft = text.split('\n').where(isFence).length;
  while (lineStart <= text.length) {
    final newline = text.indexOf('\n', lineStart);
    final lineEnd = newline == -1 ? text.length : newline;
    final line = text.substring(lineStart, lineEnd);
    final fence = isFence(line);
    if (fence) fencesLeft--;
    final blockFence = fence && (inBlock || fencesLeft > 0);
    if (blockFence) {
      inBlock = !inBlock;
      if (line.isNotEmpty) {
        _add(
            runs,
            MdRun(lineStart, lineEnd,
                role: MdRole.marker, code: true, block: true));
      }
    } else if (inBlock) {
      if (line.isNotEmpty) {
        _add(runs, MdRun(lineStart, lineEnd, code: true, block: true));
      }
    } else {
      _line(line, lineStart, runs);
    }
    if (newline == -1) break;
    // A fence's own line break goes with its symbols (Round 29).
    _add(
        runs,
        MdRun(newline, newline + 1,
            block: inBlock || blockFence,
            code: blockFence,
            role: blockFence ? MdRole.marker : MdRole.text));
    lineStart = newline + 1;
  }
  return runs;
}

void _line(String line, int offset, List<MdRun> runs) {
  if (line.isEmpty) return;
  // A divider: the whole line, drawn as a line across (N17).
  if (_divider.hasMatch(line)) {
    _add(runs, MdRun(offset, offset + line.length, role: MdRole.divider));
    return;
  }
  final n = line.length;
  final role = List.filled(n, MdRole.text);
  final bold = List.filled(n, false);
  final italic = List.filled(n, false);
  final strike = List.filled(n, false);
  final code = List.filled(n, false);
  final highlight = List.filled(n, false);
  var heading = 0;
  var done = false;

  // A quote (N17): its `>` drawn as a bar; the rest as usual, quoted.
  var quoted = 0;
  final q = _quote.firstMatch(line);
  if (q != null) {
    quoted = q.end;
    role.fillRange(q.group(1)!.length, quoted, MdRole.quoteMarker);
  }

  // What the line starts with: a heading, a checkbox or a list item.
  var body = quoted;
  final rest = line.substring(quoted);
  final h = _heading.firstMatch(rest);
  final task = _task.firstMatch(rest);
  final listItem = _bullet.firstMatch(rest) ?? _numbered.firstMatch(rest);
  if (h != null) {
    heading = h.group(1)!.length;
    body = quoted + h.end;
    role.fillRange(quoted, body, MdRole.marker);
  } else if (task != null) {
    body = quoted + task.end;
    done = task.group(3) != ' ';
    role.fillRange(quoted + task.group(1)!.length, body, MdRole.checkbox);
  } else if (listItem != null) {
    body = quoted + listItem.end;
    role.fillRange(quoted + listItem.group(1)!.length, body, MdRole.listMarker);
  }

  // Inline styles, in the rest of the line; the symbols are markers.
  // Code first: nothing inside it is styled (N17).
  void style(RegExp pattern, List<bool> flag, int markerLength) {
    for (final m in pattern.allMatches(line, body)) {
      final inner = m.start + markerLength, innerEnd = m.end - markerLength;
      // Already symbols of another style (e.g. the stars of **bold**), or
      // inside code.
      if (role[m.start] == MdRole.marker ||
          role[m.end - 1] == MdRole.marker ||
          code[m.start] ||
          code[m.end - 1]) {
        continue;
      }
      flag.fillRange(inner, innerEnd, true);
      role.fillRange(m.start, inner, MdRole.marker);
      role.fillRange(innerEnd, m.end, MdRole.marker);
    }
  }

  style(_code, code, 1);
  style(_bold, bold, 2);
  style(_strike, strike, 2);
  style(_highlight, highlight, 2);
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
        code: code[i],
        highlight: highlight[i],
        quote: quoted > 0 && i >= quoted,
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
        code: last.code,
        block: last.block,
        highlight: last.highlight,
        quote: last.quote,
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
  final quote = _quote.firstMatch(line);
  if (quote != null) {
    // A quote goes on too (N17).
    item = quote;
    next = '${quote.group(1)}> ';
  } else if (task != null) {
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

/// An edit by a format button (N17): the new text and the selection after
/// it ([start] to [end]; the same for a cursor).
typedef MdEdit = ({String text, int start, int end});

/// Bold, italic, strike, highlight or code (N17): wraps the selection in
/// [mark] (`**`, `*`, `~~`, `==`, `` ` ``), or unwraps it if it already
/// is (the marks inside the selection or just around it). With nothing
/// selected, puts a pair at the cursor and the cursor between them.
MdEdit toggleWrap(String text, int start, int end, String mark) {
  final n = mark.length;
  final selected = text.substring(start, end);
  if (start == end) {
    return (
      text: text.replaceRange(start, end, '$mark$mark'),
      start: start + n,
      end: start + n,
    );
  }
  if (selected.length >= 2 * n &&
      selected.startsWith(mark) &&
      selected.endsWith(mark)) {
    final inner = selected.substring(n, selected.length - n);
    return (
      text: text.replaceRange(start, end, inner),
      start: start,
      end: start + inner.length,
    );
  }
  if (start >= n &&
      end + n <= text.length &&
      text.substring(start - n, start) == mark &&
      text.substring(end, end + n) == mark) {
    return (
      text: text.replaceRange(start - n, end + n, selected),
      start: start - n,
      end: end - n,
    );
  }
  return (
    text: text.replaceRange(start, end, '$mark$selected$mark'),
    start: start + n,
    end: end + n,
  );
}

/// What a format button puts at the start of lines (N17).
enum MdLine { bullet, numbered, checkbox, quote }

/// The lines from the one holding [start] to the one holding [end]:
/// where the first starts and the last ends.
({int start, int end}) _lines(String text, int start, int end) {
  final first = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final next = text.indexOf('\n', end);
  return (start: first, end: next == -1 ? text.length : next);
}

/// A change to one line: its characters [from] to [to] replaced by [put].
typedef _LineChange = ({int from, int to, String put});

/// Applies [change] to each line between [start] and [end] (null leaves a
/// line as it is). The selection keeps to the same words: a position in
/// replaced characters goes to just after what replaced them.
MdEdit _eachLine(
  String text,
  int start,
  int end,
  _LineChange? Function(String line, int index) change,
) {
  final span = _lines(text, start, end);
  final lines = text.substring(span.start, span.end).split('\n');
  final out = StringBuffer();
  // Where each line starts, and its change.
  final starts = <int>[];
  final changes = <_LineChange?>[];
  var at = span.start;
  for (final (i, line) in lines.indexed) {
    if (i > 0) out.write('\n');
    final c = change(line, i);
    starts.add(at);
    changes.add(c);
    out.write(c == null ? line : line.replaceRange(c.from, c.to, c.put));
    at += line.length + 1;
  }

  int map(int offset) {
    var moved = 0;
    for (var i = 0; i < lines.length; i++) {
      final c = changes[i];
      final lineEnd = starts[i] + lines[i].length;
      if (c != null && offset <= lineEnd) {
        final o = offset - starts[i];
        if (o < c.from) return offset + moved;
        if (o < c.to || (o == c.from && c.from == c.to)) {
          return starts[i] + moved + c.from + c.put.length;
        }
        return offset + moved + c.put.length - (c.to - c.from);
      }
      if (offset <= lineEnd) return offset + moved;
      if (c != null) moved += c.put.length - (c.to - c.from);
    }
    return offset + moved;
  }

  return (
    text: text.replaceRange(span.start, span.end, out.toString()),
    start: map(start),
    end: map(end),
  );
}

/// Lists, checkboxes and quotes (N17): gives the selected lines that kind
/// of start, or takes it away if they all have it already. A list item
/// becomes the other kind (a bullet a checkbox, …); numbers count from 1.
/// Empty lines in a selection of several are left alone.
MdEdit toggleLines(String text, int start, int end, MdLine kind) {
  final span = _lines(text, start, end);
  final lines = text.substring(span.start, span.end).split('\n');
  final quote = RegExp(r'^(\s*)> ?');

  // A list line's start: where it begins (after the indent) and ends.
  ({int from, int to, String kind})? listStart(String line) {
    final indent = RegExp(r'^\s*').firstMatch(line)!.end;
    final rest = line.substring(indent);
    final task = _task.firstMatch(rest);
    if (task != null) {
      return (from: indent, to: indent + task.end, kind: 'checkbox');
    }
    final bullet = _bullet.firstMatch(rest);
    if (bullet != null) {
      return (from: indent, to: indent + bullet.end, kind: 'bullet');
    }
    final numbered = _numbered.firstMatch(rest);
    if (numbered != null) {
      return (from: indent, to: indent + numbered.end, kind: 'numbered');
    }
    return null;
  }

  bool has(String line) => kind == MdLine.quote
      ? quote.hasMatch(line)
      : listStart(line)?.kind == kind.name;

  final skipEmpty = lines.length > 1;
  final content = [
    for (final l in lines)
      if (l.trim().isNotEmpty || !skipEmpty) l
  ];
  final remove = content.isNotEmpty && content.every(has);
  var number = 0;
  return _eachLine(text, start, end, (line, i) {
    if (skipEmpty && line.trim().isEmpty) return null;
    if (kind == MdLine.quote) {
      final q = quote.firstMatch(line);
      if (remove) {
        return q == null
            ? null
            : (from: q.group(1)!.length, to: q.end, put: '');
      }
      final indent = RegExp(r'^\s*').firstMatch(line)!.end;
      return (from: indent, to: indent, put: '> ');
    }
    final old = listStart(line);
    final indent = RegExp(r'^\s*').firstMatch(line)!.end;
    final from = old?.from ?? indent, to = old?.to ?? indent;
    if (remove) return (from: from, to: to, put: '');
    number++;
    return (
      from: from,
      to: to,
      put: switch (kind) {
        MdLine.bullet => '- ',
        MdLine.numbered => '$number. ',
        MdLine.checkbox => '- [ ] ',
        MdLine.quote => '',
      },
    );
  });
}

/// The heading button (N17): no heading → `#` → `##` → `###` → `####` →
/// none again (the first line decides), on the line(s) of the selection.
MdEdit cycleHeading(String text, int start, int end) {
  final first = _lines(text, start, start);
  final current = _heading.firstMatch(text.substring(first.start, first.end));
  final level = current == null ? 0 : current.group(1)!.length;
  final next = (level + 1) % 5;
  return _eachLine(text, start, end, (line, i) {
    final h = _heading.firstMatch(line);
    return (
      from: 0,
      to: h?.end ?? 0,
      put: next == 0 ? '' : '${'#' * next} ',
    );
  });
}

/// The code block button (N17): wraps the selected lines in ``` fences,
/// or, inside a block, takes its fences away.
MdEdit toggleCodeBlock(String text, int start, int end) {
  final span = _lines(text, start, end);
  // The fence lines above the selection: inside a block if odd.
  int? open;
  var fences = 0;
  var at = 0;
  while (at < span.start) {
    final line = _lines(text, at, at);
    if (isFence(text.substring(line.start, line.end))) {
      fences++;
      open = line.start;
    }
    at = line.end + 1;
  }
  if (fences.isOdd && open != null) {
    final openLine = _lines(text, open, open);
    // The closing fence, the first one below the selection.
    ({int start, int end})? close;
    at = span.end + 1;
    while (at <= text.length) {
      final line = _lines(text, at, at);
      if (isFence(text.substring(line.start, line.end))) {
        close = line;
        break;
      }
      if (line.end >= text.length) break;
      at = line.end + 1;
    }
    var out = text;
    if (close != null) {
      // With the line break before it.
      out = out.replaceRange(close.start - 1, close.end, '');
    }
    // With the line break after it.
    final cut = openLine.end - openLine.start + 1;
    out = out.replaceRange(openLine.start, openLine.end + 1, '');
    return (text: out, start: start - cut, end: end - cut);
  }
  final body = text.substring(span.start, span.end);
  return (
    text: text.replaceRange(span.start, span.end, '```\n$body\n```'),
    start: start + 4,
    end: end + 4,
  );
}

/// The divider button (N17): a `---` line after the cursor's line (or in
/// place of an empty one), the cursor on a new line below it.
MdEdit insertDivider(String text, int cursor) {
  final line = _lines(text, cursor, cursor);
  final empty = text.substring(line.start, line.end).trim().isEmpty;
  if (empty) {
    final put = '---\n';
    return (
      text: text.replaceRange(line.start, line.end, put),
      start: line.start + put.length,
      end: line.start + put.length,
    );
  }
  const put = '\n---\n';
  return (
    text: text.replaceRange(line.end, line.end, put),
    start: line.end + put.length,
    end: line.end + put.length,
  );
}
