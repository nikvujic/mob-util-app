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
  // A centred lock message, not a list.
  'app/section_gate.dart',
  // The day's timeline: opens at the current hour; 00:00 isn't the
  // place everyone needs to reach.
  'pages/planner/planner.dart',
  // The same timeline, for routines.
  'pages/planner/routines.dart',
  // A form, used with the keyboard open.
  'pages/security/password_form.dart',
  // The task sheet: a form with the keyboard open.
  'pages/planner/add_task_sheet.dart',
  // Tiles fill from the bottom right: already in thumb reach.
  'pages/other/other.dart',
};

final _rawColor = RegExp(r'(?<![A-Za-z])Colors\.(?!transparent\b)|Color\(0x');
final _print = RegExp(r'(?<![A-Za-z_.])print\(');

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

final _importLine = RegExp(r'''^import\s+'([^']+)'.*;''', multiLine: true);

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

  test('no raw colors outside the theme, no print(), lists have reach mode',
      () {
    final violations = [
      for (final f in files) ...contentViolations(f.path, f.source),
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
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
