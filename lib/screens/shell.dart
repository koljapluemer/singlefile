import 'package:flutter/material.dart';

import '../repository.dart';
import 'choose_file.dart';
import 'editor.dart';
import 'front.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, required this.repository});

  final FileRepository repository;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final _editorKey = GlobalKey<EditorScreenState>();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final editor = _editorKey.currentState;
    switch (state) {
      case AppLifecycleState.inactive || AppLifecycleState.paused:
        editor?.save();
      case AppLifecycleState.resumed:
        if (editor == null || !editor.dirty) widget.repository.load();
      default:
    }
  }

  Future<void> _select(int i) async {
    if (i == _index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _editorKey.currentState?.save();
    if (i == 0) {
      // Front page always reflects disk, picking up external edits.
      await widget.repository.load();
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    height: 56,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysHide,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        label: 'Front',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.edit_note),
                        label: 'Editor',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: () => chooseFile(context, widget.repository),
                ),
              ],
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  FrontScreen(repository: widget.repository),
                  EditorScreen(key: _editorKey, repository: widget.repository),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
