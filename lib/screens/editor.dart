import 'package:flutter/material.dart';

import '../repository.dart';

/// The raw file. Saves when the field loses focus and when the app is
/// backgrounded or the tab is left (see [EditorScreenState.save]).
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.repository});

  final FileRepository repository;

  @override
  State<EditorScreen> createState() => EditorScreenState();
}

class EditorScreenState extends State<EditorScreen> {
  late final _controller = TextEditingController(text: widget.repository.text);
  final _focus = FocusNode();

  /// Whether the field holds edits not yet written to disk.
  bool get dirty => _controller.text != widget.repository.text;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.repository.addListener(_onRepository);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepository);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) save();
  }

  /// Takes on text loaded from disk, unless the user is mid-edit.
  void _onRepository() {
    if (_focus.hasFocus) return;
    if (_controller.text != widget.repository.text) {
      _controller.text = widget.repository.text;
    }
  }

  Future<void> save() => widget.repository.save(_controller.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        expands: true,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }
}
