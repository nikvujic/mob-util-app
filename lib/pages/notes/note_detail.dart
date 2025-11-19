import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/providers/notes_provider.dart';

class NoteDetailPage extends ConsumerStatefulWidget {
  final String? noteId;
  final bool isNew;

  const NoteDetailPage({
    super.key,
    required this.noteId,
    required this.isNew,
  });

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _titleFocusNode;
  late FocusNode _contentFocusNode;

  String? _noteId;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    _titleFocusNode = FocusNode();
    _contentFocusNode = FocusNode();

    if (widget.isNew) {
      _titleController = TextEditingController(text: 'New Note');
      _contentController = TextEditingController();
      _isEditing = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 120));

        final notifier = ref.read(notesProvider.notifier);
        final newId = notifier.createNewNote();

        setState(() {
          _noteId = newId;
        });

        _contentFocusNode.requestFocus();
      });
    } else {
      final notes = ref.read(notesProvider);
      final note =
          notes.firstWhere((n) => n.id == widget.noteId);

      _noteId = note.id;

      _titleController = TextEditingController(text: note.title);
      _contentController = TextEditingController(text: note.content);
      _isEditing = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _enableEditing({bool focusTitle = false}) {
    if (!_isEditing) {
      setState(() {
        _isEditing = true;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusTitle) {
        _titleFocusNode.requestFocus();
      } else {
        _contentFocusNode.requestFocus();
      }
    });
  }

  Future<void> _saveAndPop() async {
    final rawTitle = _titleController.text.trim();
    final titleText = rawTitle.isEmpty ? 'Untitled' : rawTitle;

    final id = _noteId ?? widget.noteId;

    if (id != null) {
      ref.read(notesProvider.notifier).updateNote(
            id,
            title: titleText,
            content: _contentController.text,
          );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _saveAndPop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.grey[900],
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _saveAndPop,
          ),
          title: const Text(
            'Note',
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            GestureDetector(
              onTap: _isEditing
                  ? null
                  : () {
                      _enableEditing(focusTitle: true);
                    },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  readOnly: !_isEditing,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Title',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                  magnifierConfiguration: TextMagnifierConfiguration.disabled,
                ),
              ),
            ),

            const Divider(height: 1, color: Colors.white12),

            Expanded(
              child: GestureDetector(
                onDoubleTap: _isEditing
                    ? null
                    : () {
                        _enableEditing(focusTitle: false);
                      },
                behavior: HitTestBehavior.translucent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    readOnly: !_isEditing,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '',
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                    magnifierConfiguration:
                        TextMagnifierConfiguration.disabled,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}