// Architecture rules for lib/, checked on every test run.
//
// The layers and what each may depend on are described in
// docs/ARCHITECTURE.md; this test is the enforcement. Each rule is also
// tested against a deliberately broken example, so a rule can't silently
// stop detecting anything.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Which app layers each layer may import (besides itself).
const allowedLayerImports = <String, Set<String>>{
  'main': {'app', 'core', 'data'},
  'app': {'core', 'models', 'providers', 'pages', 'widgets'},
  'pages': {'core', 'models', 'providers', 'widgets'},
  'widgets': {'core'},
  'providers': {'core', 'data', 'models'},
  'data': {'core', 'models'},
  'models': {},
  'core': {},
};

/// External imports only allowed in some layers.
const restrictedImports = <String, Set<String>>{
  'dart:io': {'data'},
  'package:path_provider/': {'data'},
  'package:file_picker/': {'data'},
  'package:cryptography/': {'core'},
  'package:package_info_plus/': {'main'},
  'package:biometric_storage/': {'data'},
  'package:flutter_local_notifications/': {'data'},
  'package:timezone/': {'data'},
  'package:flutter_svg/': {'pages'},
  'package:flutter/material.dart': {'main', 'app', 'pages', 'widgets', 'core'},
  'package:flutter/widgets.dart': {'main', 'app', 'pages', 'widgets', 'core'},
  'package:flutter/': {'main', 'app', 'pages', 'widgets', 'core', 'data'},
  'package:flutter_riverpod/': {
    'main',
    'app',
    'pages',
    'providers',
    'data',
    'core',
  },
};

/// The one file allowed to define colors.
const themeFile = 'core/theme.dart';

const packagePrefix = 'package:the_app/';

/// Layer of a file, from its path relative to lib/.
String layerOf(String path) =>
    path == 'main.dart' ? 'main' : path.split('/').first;

/// Feature of a file under pages/ (e.g. "notes"), else null.
String? featureOf(String path) =>
    path.startsWith('pages/') ? path.split('/')[1] : null;

/// Import rule violations for one file.
List<String> importViolations(String path, Iterable<String> imports) {
  final layer = layerOf(path);
  final allowed = allowedLayerImports[layer];
  if (allowed == null) return ['$path: unknown layer "$layer"'];

  final violations = <String>[];
  for (final import in imports) {
    if (!import.startsWith('dart:') && !import.startsWith('package:')) {
      violations.add('$path: relative import "$import" '
          '(use package:the_app/...)');
      continue;
    }
    if (import.startsWith(packagePrefix)) {
      final target = import.substring(packagePrefix.length);
      final targetLayer = layerOf(target);
      if (targetLayer == layer) {
        final from = featureOf(path), to = featureOf(target);
        if (from != to) {
          violations.add('$path: pages of "$from" must not import pages of '
              '"$to" (move shared UI to widgets/)');
        }
      } else if (!allowed.contains(targetLayer)) {
        violations.add('$path: $layer/ must not import $targetLayer/ '
            '($target)');
      }
      continue;
    }
    // Most specific restriction wins (e.g. material.dart over flutter/).
    final matching = restrictedImports.keys.where(import.startsWith).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (matching.isNotEmpty &&
        !restrictedImports[matching.first]!.contains(layer)) {
      violations.add('$path: $layer/ must not import "$import"');
    }
  }
  return violations;
}

/// Scrolling views in app/ and pages/ must be `PullDownList` (reach mode,
/// U4/G14), except where pulling down doesn't bring anything into reach.
final _plainScroll = RegExp(
  r'(?<![A-Za-z_.])(ListView|CustomScrollView|SingleChildScrollView|GridView)'
  r'(\.\w+)?\(',
);
const plainScrollAllowed = {
  // Recipes to pick one to export (Round 104), in a bottom sheet capped
  // in height: already at the bottom.
  'pages/hub/recipe_transfer_sheet.dart',
  // A centred lock message, not a list.
  'app/section_gate.dart',
  // A form, used with the keyboard open.
  'pages/security/password_form.dart',
  // Tiles fill from the bottom right: already in thumb reach.
  'pages/hub/hub.dart',
  // A short form in a bottom sheet: already at the bottom, scrolling only
  // to stay clear of the keyboard.
  'pages/hub/counter_sheet.dart',
  // The same, for a medicine.
  'pages/hub/medicine_sheet.dart',
  // A recipe's ingredients to tick, in a bottom sheet (Round 48): already
  // at the bottom.
  'pages/hub/food_recipe_sheet.dart',
  // The food index under its field (Round 53): a short list capped in
  // height, right under the thumb already.
  'pages/hub/food_index.dart',
  // A date's reminder sheet (Round 57): a few chips and a time, scrolled
  // on a short screen; no list to reach.
  'pages/hub/date_reminder_sheet.dart',
  // A reminder mark's menu: a short list in a bottom sheet.
  'pages/planner/pin_menu.dart',
  // All the planner's reminders (Round 70): a list in a bottom sheet,
  // capped in height, already at the bottom.
  'pages/planner/reminders_sheet.dart',
  // A few places found for the weather (Round 70), above the search
  // field at the bottom of a sheet: already in reach.
  'pages/internet/place_search_sheet.dart',
  // The sounds to pick from (Round 39): a short list in a bottom sheet.
  'pages/notifications/notifications.dart',
  // A note's text while editing: a pull would move the text being typed.
  'pages/notes/note_detail.dart',
  // Pip Home's card (Round 35): short lists inside a card at the bottom,
  // already in reach; a pull would fight the card's swipe.
  'pages/hub/pip_home.dart',
  // A recipe in view mode (Round 42): the user wants no reach mode there,
  // only in edit mode (which has it).
  'pages/hub/recipe_page.dart',
  // Copy list's sheet (Round 94): a name and a few sections to tick, in
  // a bottom sheet, scrolling only to stay clear of the keyboard.
  'pages/hub/packing_copy_sheet.dart',
};

final _rawColor = RegExp(r'(?<![A-Za-z])Colors\.(?!transparent\b)|Color\(0x');
final _print = RegExp(r'(?<![A-Za-z_.])print\(');

/// Toasts shown without first hiding the one showing (UI conventions,
/// Round 39): within the three lines before.
List<String> toastViolations(String path, String source) {
  final lines = source.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].contains('showSnackBar(') &&
          !lines
              .sublist((i - 3).clamp(0, i), i + 1)
              .any((l) => l.contains('hideCurrentSnackBar')))
        '$path:${i + 1}: a toast that queues: hideCurrentSnackBar first',
  ];
}

/// Top bars with action buttons (G11: actions are at the bottom, on the
/// hand's side; only the menu ☰ and back go at the top). 1.29.1: Shop's
/// search went into the top bar unasked. A file listed in
/// [appBarActionsAllowed] may, only where the user asked for it.
const appBarActionsAllowed = <String>{};
final _appBar = RegExp(r'(?<![A-Za-z_])AppBar\(');

List<String> appBarActionViolations(String path, String source) {
  final violations = <String>[];
  if (appBarActionsAllowed.contains(path)) return violations;
  for (final m in _appBar.allMatches(source)) {
    // The call's own arguments, to its closing bracket.
    var depth = 1;
    var i = m.end;
    final args = StringBuffer();
    for (; i < source.length && depth > 0; i++) {
      final c = source[i];
      if (c == '(' || c == '[' || c == '{') depth++;
      if (c == ')' || c == ']' || c == '}') depth--;
      if (depth == 1 && RegExp(r'[a-zA-Z:]').hasMatch(c)) args.write(c);
      if (depth == 1 && c == ',') args.write(',');
    }
    if (args.toString().split(',').any((a) => a.startsWith('actions:'))) {
      final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
      violations.add('$path:$line: actions in a top bar — put them at the '
          'bottom (G11), unless the user asked for it');
    }
  }
  return violations;
}

/// Content rule violations for one file.
List<String> contentViolations(String path, String source) {
  final violations = <String>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    if (path != themeFile && _rawColor.hasMatch(line)) {
      violations.add('$path:${i + 1}: raw color — use context.colors '
          '(lib/$themeFile)');
    }
    if (_print.hasMatch(line)) {
      violations.add('$path:${i + 1}: print() — use debugPrint');
    }
    final layer = layerOf(path);
    if ((layer == 'app' || layer == 'pages') &&
        !plainScrollAllowed.contains(path) &&
        _plainScroll.hasMatch(line)) {
      violations.add('$path:${i + 1}: plain scrolling list — use '
          'PullDownList (reach mode), or add an exception with a reason');
    }
  }
  return violations;
}

/// An import or export, with either quotes.
final _importLine =
    RegExp(r'''^(?:import|export)\s+['"]([^'"]+)['"].*;''', multiLine: true);

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => (
            path: f.path.replaceAll('\\', '/').substring('lib/'.length),
            source: f.readAsStringSync(),
          ))
      .toList();

  test('lib/ contains source files', () {
    expect(files, isNotEmpty);
  });

  test('every file is in a known layer', () {
    final unknown = files
        .map((f) => f.path)
        .where((p) => !allowedLayerImports.containsKey(layerOf(p)));
    expect(unknown, isEmpty);
  });

  test('layers only depend on what they are allowed to', () {
    final violations = [
      for (final f in files)
        ...importViolations(
          f.path,
          _importLine.allMatches(f.source).map((m) => m.group(1)!),
        ),
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('a toast replaces the one showing, never queues (Round 39)', () {
    final violations = [
      for (final f in files) ...toastViolations(f.path, f.source),
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
    expect(toastViolations('pages/a.dart', 'm.showSnackBar(x);'), hasLength(1));
    expect(
        toastViolations('pages/a.dart',
            'm\n  ..hideCurrentSnackBar()\n  ..showSnackBar(x);'),
        isEmpty);
  });

  test(
      'every text field has the lowered selection handles (Round 92: '
      'selectionControls set)', () {
    List<String> missing(String path, String source) => [
          for (final m
              in RegExp(r'\b(TextField|TextFormField)\(').allMatches(source))
            if (!_argsOf(source, m.end).contains('selectionControls'))
              '$path: a ${m.group(1)} without selectionControls',
        ];
    final violations = [
      for (final f in files) ...missing(f.path, f.source),
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
    expect(missing('a.dart', 'TextField(controller: c)'), hasLength(1));
    expect(
        missing('a.dart', 'TextField(a: f(1), selectionControls: lowHandles)'),
        isEmpty);
  });

  test('no raw colors outside the theme, no print(), lists have reach mode',
      () {
    final violations = [
      for (final f in files) ...contentViolations(f.path, f.source),
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('no actions in top bars (G11)', () {
    final violations = [
      for (final f in files) ...appBarActionViolations(f.path, f.source),
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
    expect(
        appBarActionViolations('pages/a.dart',
            "appBar: AppBar(title: Text('x'), actions: [IconButton()]),"),
        hasLength(1));
    expect(
        appBarActionViolations(
            'pages/a.dart',
            "appBar: AppBar(title: f(actions: 1)),\n"
                'b: BottomActions(actions: [])'),
        isEmpty,
        reason: 'only the bar\'s own actions');
  });

  group('the rules catch violations', () {
    test('lower layers importing higher ones', () {
      expect(
        importViolations('widgets/x.dart', ['package:the_app/pages/a/a.dart']),
        hasLength(1),
      );
      expect(
        importViolations('data/x.dart', ['package:the_app/providers/p.dart']),
        hasLength(1),
      );
      expect(
        importViolations('models/x.dart', ['package:the_app/core/id.dart']),
        hasLength(1),
      );
    });

    test('one feature importing another feature', () {
      expect(
        importViolations(
          'pages/shop/shop.dart',
          ['package:the_app/pages/notes/notes.dart'],
        ),
        hasLength(1),
      );
      expect(
        importViolations(
          'pages/notes/notes.dart',
          ['package:the_app/pages/notes/note_detail.dart'],
        ),
        isEmpty,
      );
    });

    test('restricted packages and relative imports', () {
      expect(importViolations('pages/a/a.dart', ['dart:io']), hasLength(1));
      expect(importViolations('data/x.dart', ['dart:io']), isEmpty);
      expect(
        importViolations(
          'pages/a/a.dart',
          ['package:file_picker/file_picker.dart'],
        ),
        hasLength(1),
      );
      expect(
        importViolations(
          'providers/p.dart',
          ['package:flutter/material.dart'],
        ),
        hasLength(1),
      );
      expect(
        importViolations('models/m.dart', ['package:flutter/foundation.dart']),
        hasLength(1),
      );
      expect(importViolations('pages/a/a.dart', ['../b.dart']), hasLength(1));
    });

    test('platform plugins stay in their layer', () {
      expect(
        importViolations(
          'pages/a/a.dart',
          ['package:flutter_local_notifications/x.dart'],
        ),
        hasLength(1),
      );
      expect(
        importViolations('providers/p.dart', ['package:timezone/x.dart']),
        hasLength(1),
      );
      expect(
        importViolations('data/d.dart', ['package:biometric_storage/x.dart']),
        isEmpty,
      );
    });

    test('exports and double quotes are checked like imports', () {
      final found = _importLine
          .allMatches('export "package:the_app/data/x.dart";\n'
              "import 'package:the_app/core/y.dart';")
          .map((m) => m.group(1))
          .toList();
      expect(found, [
        'package:the_app/data/x.dart',
        'package:the_app/core/y.dart',
      ]);
    });

    test('raw colors and print()', () {
      expect(
        contentViolations('pages/a/a.dart', 'color: Colors.red,'),
        hasLength(1),
      );
      expect(
        contentViolations('widgets/w.dart', 'c = Color(0xFF000000);'),
        hasLength(1),
      );
      expect(
        contentViolations('widgets/w.dart', 'color: context.colors.accent,'),
        isEmpty,
      );
      expect(
        contentViolations('widgets/w.dart', 'color: Colors.transparent,'),
        isEmpty,
      );
      expect(contentViolations(themeFile, 'x = Colors.green;'), isEmpty);
      expect(contentViolations('core/c.dart', "print('x');"), hasLength(1));
      expect(contentViolations('core/c.dart', "debugPrint('x');"), isEmpty);
    });

    test('plain scrolling lists in pages and the app shell', () {
      expect(
        contentViolations('pages/a/a.dart', 'body: ListView('),
        hasLength(1),
      );
      expect(
        contentViolations('app/x.dart', 'child: ListView.builder('),
        hasLength(1),
      );
      expect(
        contentViolations('pages/a/a.dart', 'body: PullDownList.children('),
        isEmpty,
      );
      expect(
        contentViolations('widgets/w.dart', 'child: ListView('),
        isEmpty,
        reason: 'reusable widgets may build on them',
      );
      expect(
        contentViolations('pages/security/password_form.dart', 'ListView('),
        isEmpty,
        reason: 'listed exception',
      );
    });
  });
}

/// What's between the parenthesis opening at [start] (just after it) and
/// its match.
String _argsOf(String source, int start) {
  var depth = 1;
  var i = start;
  while (depth > 0 && i < source.length) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    i++;
  }
  return source.substring(start, i - 1);
}
