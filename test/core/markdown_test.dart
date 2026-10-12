import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/markdown.dart';

/// Markdown basics in notes (N9).
void main() {
  /// The parts of [text] with [role] (and the style [where] asks for).
  List<String> parts(
    String text, {
    MdRole role = MdRole.text,
    bool Function(MdRun)? where,
  }) =>
      [
        for (final run in markdownRuns(text))
          if (run.role == role && (where?.call(run) ?? true))
            text.substring(run.start, run.end),
      ];

  test('runs cover the whole text, in order, without gaps', () {
    for (final text in [
      '',
      'plain',
      '## Title\n- milk\n- **eggs**\n\n1. one *two* ~~three~~',
      '**not closed\n*',
    ]) {
      final runs = markdownRuns(text);
      var at = 0;
      for (final run in runs) {
        expect(run.start, at, reason: text);
        expect(run.end, greaterThan(run.start));
        at = run.end;
      }
      expect(at, text.length, reason: text);
    }
  });

  test('headings: # to ### then a space, at the start of a line', () {
    const text = '# One\n## Two\n### Three\n#### Four\n#No\nx ## no';
    expect(parts(text, role: MdRole.marker), ['# ', '## ', '### ']);
    final h = {
      for (final run in markdownRuns(text))
        if (run.role == MdRole.text && run.heading > 0)
          text.substring(run.start, run.end): run.heading,
    };
    expect(h, {'One': 1, 'Two': 2, 'Three': 3});
  });

  test('list items: bullets and numbers, also indented', () {
    const text = '- milk\n* eggs\n+ tea\n  - nested\n1. one\n12) twelve\n-no';
    expect(parts(text, role: MdRole.listMarker),
        ['- ', '* ', '+ ', '- ', '1. ', '12) ']);
  });

  test('bold, italic and strike; the symbols are faint markers', () {
    const text = 'a **bold** b *it* c ~~gone~~';
    expect(parts(text, where: (r) => r.bold), ['bold']);
    expect(parts(text, where: (r) => r.italic), ['it']);
    expect(parts(text, where: (r) => r.strike), ['gone']);
    expect(
        parts(text, role: MdRole.marker), ['**', '**', '*', '*', '~~', '~~']);
  });

  test('styles combine', () {
    const text = '**a *b* c**';
    expect(parts(text, where: (r) => r.bold && r.italic), ['b']);
    expect(parts(text, where: (r) => r.bold && !r.italic), ['a ', ' c']);
  });

  test('not formatting: unclosed, spaced, across lines', () {
    for (final text in [
      '**open',
      '** spaced **',
      '* not italic *',
      '**across\nlines**',
      '2 * 3 * 4',
    ]) {
      expect(parts(text, role: MdRole.marker), isEmpty, reason: text);
    }
  });

  test('a list item can have styled words', () {
    const text = '- **milk**, eggs';
    expect(parts(text, role: MdRole.listMarker), ['- ']);
    expect(parts(text, where: (r) => r.bold), ['milk']);
  });

  group('Enter in a list', () {
    /// Types Enter at [at] (where `|` is) and returns the result, with `|`
    /// at the cursor.
    String? enter(String withCursor) {
      final at = withCursor.indexOf('|');
      final text =
          '${withCursor.substring(0, at)}\n${withCursor.substring(at + 1)}';
      final edit = continueList(text, at + 1);
      if (edit == null) return null;
      return '${edit.text.substring(0, edit.cursor)}|'
          '${edit.text.substring(edit.cursor)}';
    }

    test('Enter at the very start does nothing special (and no error)', () {
      expect(enter('|- milk'), isNull);
      expect(enter('|hello'), isNull);
    });

    test('continues bullets, with the same symbol and indent', () {
      expect(enter('- milk|'), '- milk\n- |');
      expect(enter('* milk|'), '* milk\n* |');
      expect(enter('  - nested|'), '  - nested\n  - |');
    });

    test('numbered lists count on', () {
      expect(enter('1. one|'), '1. one\n2. |');
      expect(enter('9) nine|'), '9) nine\n10) |');
    });

    test('in the middle of an item, the rest goes to the new item', () {
      expect(enter('- milk| eggs'), '- milk\n- | eggs');
    });

    test('on an empty item, ends the list', () {
      expect(enter('- milk\n- |'), '- milk\n|');
      expect(enter('1. one\n2. |\nafter'), '1. one\n|\nafter');
    });

    test('anywhere else, nothing special', () {
      expect(enter('plain|'), isNull);
      expect(enter('## Title|'), isNull);
      expect(enter('-no|'), isNull);
    });
  });

  group('checkboxes (N15)', () {
    test('"- [ ] " and "- [x] " are checkboxes; a ticked one is done', () {
      expect(parts('- [ ] milk', role: MdRole.checkbox), ['- [ ] ']);
      expect(parts('  * [X] eggs', role: MdRole.checkbox), ['* [X] ']);
      expect(parts('- [x] eggs', where: (r) => r.done), ['eggs']);
      expect(parts('- [ ] milk', where: (r) => r.done), isEmpty);
      // Not checkboxes: no space after, or something else in the box.
      expect(parts('- [ ]milk', role: MdRole.checkbox), isEmpty);
      expect(parts('- [y] milk', role: MdRole.checkbox), isEmpty);
      expect(parts('- [y] milk', role: MdRole.listMarker), ['- ']);
    });

    String? enter(String withCursor) {
      final at = withCursor.indexOf('|');
      final text =
          '${withCursor.substring(0, at)}\n${withCursor.substring(at + 1)}';
      final edit = continueList(text, at + 1);
      if (edit == null) return null;
      return '${edit.text.substring(0, edit.cursor)}|'
          '${edit.text.substring(edit.cursor)}';
    }

    test('Enter continues with an empty box; on an empty one it ends', () {
      expect(enter('- [x] milk|'), '- [x] milk\n- [ ] |');
      expect(enter('  - [ ] milk|'), '  - [ ] milk\n  - [ ] |');
      expect(enter('- [ ] milk\n- [ ] |'), '- [ ] milk\n|');
    });

    test('found from anywhere on its line; toggled', () {
      const text = 'Buy\n  - [ ] milk\nend';
      expect(checkboxOnLine(text, 0), isNull);
      expect(checkboxOnLine(text, 10), (start: 6, box: 8, checked: false));
      expect(checkboxOnLine(text, text.length), isNull);
      final ticked = toggleCheckbox(text, 8);
      expect(ticked, 'Buy\n  - [x] milk\nend');
      expect(checkboxOnLine(ticked, 6)!.checked, isTrue);
      expect(toggleCheckbox(ticked, 8), text);
    });

    test('the checkbox button: plain ↔ checkbox, a bullet becomes one', () {
      String toggle(String withCursor) {
        final at = withCursor.indexOf('|');
        final edit = toggleChecklistLine(
          withCursor.replaceFirst('|', ''),
          at,
        );
        return '${edit.text.substring(0, edit.cursor)}|'
            '${edit.text.substring(edit.cursor)}';
      }

      expect(toggle('milk|'), '- [ ] milk|');
      expect(toggle('|'), '- [ ] |');
      expect(toggle('a\n  mi|lk\nb'), 'a\n  - [ ] mi|lk\nb');
      expect(toggle('- milk|'), '- [ ] milk|');
      expect(toggle('- [x] mi|lk'), 'mi|lk');
      expect(toggle('- [ |] milk'), '|milk', reason: 'cursor in the box');
    });
  });
}
