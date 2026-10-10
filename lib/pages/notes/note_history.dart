import 'package:flutter/widgets.dart';

/// A note's title and text (with their cursors) at one point in time.
typedef NoteText = ({TextEditingValue title, TextEditingValue content});

/// Undo / redo for the note editor (N8), in steps: a burst of typing up to
/// a [pause], or one [bigChange] (e.g. a paste) on its own. The title and
/// the text share one history.
class NoteHistory extends ChangeNotifier {
  /// A gap in typing this long starts a new step.
  static const pause = Duration(seconds: 1);

  /// A change of at least this many characters at once (a paste, a cut) is
  /// a step on its own.
  static const bigChange = 10;

  /// Steps kept; older ones are dropped.
  static const limit = 100;

  final DateTime Function() _clock;
  final _undo = <NoteText>[];
  final _redo = <NoteText>[];
  NoteText _current;

  /// When the current step was last added to, while it's still open.
  DateTime? _lastChange;

  /// What the current step changes: the title or the text.
  bool? _lastWasTitle;

  NoteHistory(this._current, {required DateTime Function() clock})
      : _clock = clock;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Records [next] as the latest state. Cursor moves alone aren't steps.
  /// [separate] makes it a step of its own (e.g. Discard changes).
  void changed(NoteText next, {bool separate = false}) {
    final title = next.title.text != _current.title.text;
    final content = next.content.text != _current.content.text;
    if (!title && !content) {
      _current = next; // the cursor moved: kept, but not a step
      return;
    }
    final size = (title ? _size(_current.title.text, next.title.text) : 0) +
        (content ? _size(_current.content.text, next.content.text) : 0);
    final big = separate || size >= bigChange;
    final now = _clock();
    final last = _lastChange;
    final newStep = big ||
        last == null ||
        now.difference(last) >= pause ||
        _lastWasTitle != title;
    if (newStep) {
      _undo.add(_current);
      if (_undo.length > limit) _undo.removeAt(0);
    }
    _current = next;
    _redo.clear();
    // A big change ends its step: typing after it is a new one.
    _lastChange = big ? null : now;
    _lastWasTitle = title;
    notifyListeners();
  }

  /// Goes back one step; returns the state to show, or null if none.
  NoteText? undo() => _move(_undo, _redo);

  /// Goes forward one undone step; returns the state to show, or null.
  NoteText? redo() => _move(_redo, _undo);

  NoteText? _move(List<NoteText> from, List<NoteText> to) {
    if (from.isEmpty) return null;
    to.add(_current);
    _current = from.removeLast();
    _lastChange = null; // typing after this starts a new step
    notifyListeners();
    return _current;
  }

  /// Roughly how many characters changed from [a] to [b]: what's left
  /// after the common start and end.
  static int _size(String a, String b) {
    var start = 0;
    final shorter = a.length < b.length ? a.length : b.length;
    while (start < shorter && a.codeUnitAt(start) == b.codeUnitAt(start)) {
      start++;
    }
    var end = 0;
    while (end < shorter - start &&
        a.codeUnitAt(a.length - 1 - end) == b.codeUnitAt(b.length - 1 - end)) {
      end++;
    }
    final removed = a.length - start - end, added = b.length - start - end;
    return removed > added ? removed : added;
  }
}
