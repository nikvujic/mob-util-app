import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/markdown.dart';

/// More formats and the format buttons (N17, Round 27).
void main() {
  /// [text] with the selection marked: `[` and `]` around it, or `|` for
  /// a cursor; the edit's result in the same notation.
  (String, int, int) parse(String marked) {
    if (marked.contains('|')) {
      final at = marked.indexOf('|');
      return (marked.replaceFirst('|', ''), at, at);
    }
    final start = marked.indexOf('[');
    final end = marked.indexOf(']') - 1;
    return (marked.replaceFirst('[', '').replaceFirst(']', ''), start, end);
  }

  String show(MdEdit e) => e.start == e.end
      ? e.text.replaceRange(e.start, e.start, '|')
      : e.text
          .replaceRange(e.end, e.end, ']')
          .replaceRange(e.start, e.start, '[');

  String wrap(String marked, String mark) {
    final (t, s, e) = parse(marked);
    return show(toggleWrap(t, s, e, mark));
  }

  String lines(String marked, MdLine kind) {
    final (t, s, e) = parse(marked);
    return show(toggleLines(t, s, e, kind));
  }

  group('reading them', () {
    List<String> where(String text, bool Function(MdRun) test) => [
          for (final r in markdownRuns(text))
            if (test(r)) text.substring(r.start, r.end),
        ];

    test('inline code: nothing inside is styled', () {
      const text = 'run `**not bold**` now';
      expect(where(text, (r) => r.code && r.role == MdRole.text),
          ['**not bold**']);
      expect(where(text, (r) => r.bold), isEmpty);
      expect(where(text, (r) => r.role == MdRole.marker), ['`', '`']);
    });

    test('highlight between ==', () {
      expect(where('a ==big== b', (r) => r.highlight), ['big']);
    });

    test('a code block: its lines are code, the fences markers', () {
      const text = 'x\n```\n# not a heading\n- not a list\n```\ny';
      expect(where(text, (r) => r.block && r.role == MdRole.text).join(),
          contains('# not a heading\n- not a list'));
      expect(where(text, (r) => r.role == MdRole.marker), ['```', '```']);
      expect(where(text, (r) => r.heading > 0), isEmpty);
      // After the closing fence: plain again.
      final last = markdownRuns(text).last;
      expect((text.substring(last.start, last.end).trim(), last.code),
          ('y', false));
    });

    test('quotes: the > is the marker, the rest quoted (a list inside too)',
        () {
      const text = '> wise words\n> - and a list\nplain';
      expect(where(text, (r) => r.role == MdRole.quoteMarker), ['> ', '> ']);
      expect(where(text, (r) => r.quote && r.role == MdRole.text),
          ['wise words', 'and a list']);
      expect(where(text, (r) => r.role == MdRole.listMarker), ['- ']);
    });

    test('dividers: three or more -, * or _ alone on a line', () {
      const text = '---\n***\n___\n-----\n--\n- --- x';
      expect(where(text, (r) => r.role == MdRole.divider),
          ['---', '***', '___', '-----']);
    });
  });

  group('wrapping (bold, italic, strike, highlight, code)', () {
    test('a selection is wrapped, then unwrapped', () {
      expect(wrap('buy [milk] now', '**'), 'buy **[milk]** now');
      expect(wrap('buy **[milk]** now', '**'), 'buy [milk] now');
      expect(wrap('buy [**milk**] now', '**'), 'buy [milk] now');
      expect(wrap('a [b] c', '=='), 'a ==[b]== c');
      expect(wrap('a [b] c', '`'), 'a `[b]` c');
    });

    test('a cursor gets a pair, typing between them', () {
      expect(wrap('buy |', '*'), 'buy *|*');
      expect(wrap('|', '~~'), '~~|~~');
    });
  });

  group('lines (lists, checkboxes, quotes)', () {
    test('a line becomes an item; again, plain', () {
      expect(lines('mi|lk', MdLine.bullet), '- mi|lk');
      expect(lines('- mi|lk', MdLine.bullet), 'mi|lk');
      expect(lines('mi|lk', MdLine.checkbox), '- [ ] mi|lk');
      expect(lines('mi|lk', MdLine.quote), '> mi|lk');
      expect(lines('> mi|lk', MdLine.quote), 'mi|lk');
    });

    test('one kind of item becomes another', () {
      expect(lines('- mi|lk', MdLine.checkbox), '- [ ] mi|lk');
      expect(lines('- [x] mi|lk', MdLine.numbered), '1. mi|lk');
      expect(lines('3. mi|lk', MdLine.bullet), '- mi|lk');
    });

    test('several lines: numbered in order, empty lines left alone', () {
      // The selection keeps to the words.
      expect(lines('[milk\n\neggs\ntea]', MdLine.numbered),
          '1. [milk\n\n2. eggs\n3. tea]');
      expect(lines('[- milk\n- eggs]', MdLine.bullet), '[milk\neggs]');
      // Mixed: all become bullets (not taken away).
      expect(lines('[- milk\neggs]', MdLine.bullet), '- [milk\n- eggs]');
    });

    test('indented items keep their indent', () {
      expect(lines('  mi|lk', MdLine.bullet), '  - mi|lk');
    });

    test('Enter goes on with a quote; on an empty one it ends', () {
      expect(continueList('> a\n', 4), (text: '> a\n> ', cursor: 6));
      expect(continueList('> a\n> \n', 7), (text: '> a\n', cursor: 4));
    });
  });

  test('headings cycle # → ## → ### → #### → none', () {
    String next(String marked) {
      final (t, s, e) = parse(marked);
      return show(cycleHeading(t, s, e));
    }

    expect(next('Ti|tle'), '# Ti|tle');
    expect(next('# Ti|tle'), '## Ti|tle');
    expect(next('### Ti|tle'), '#### Ti|tle');
    expect(next('#### Ti|tle'), 'Ti|tle');
  });

  test('a code block around the lines; inside one, taken away', () {
    String block(String marked) {
      final (t, s, e) = parse(marked);
      return show(toggleCodeBlock(t, s, e));
    }

    expect(block('a\n[x = 1\ny = 2]\nb'), 'a\n```\n[x = 1\ny = 2]\n```\nb');
    expect(block('a\n```\nx |= 1\n```\nb'), 'a\nx |= 1\nb');
    expect(block('|'), '```\n|\n```');
  });

  test('a divider below the line, the cursor under it', () {
    String divider(String marked) {
      final (t, s, _) = parse(marked);
      return show(insertDivider(t, s));
    }

    expect(divider('intro| text\nmore'), 'intro text\n---\n|\nmore');
    expect(divider('a\n|\nb'), 'a\n---\n|\nb');
  });
}
