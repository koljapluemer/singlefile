import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../repository.dart';

/// Points [repository] at a file chosen by the user.
///
/// On Android the file dialog only hands back a cache copy, so a folder is
/// picked instead (a real path, given full disk access) and the file is
/// chosen from its `.txt` files.
Future<void> chooseFile(BuildContext context, FileRepository repository) async {
  if (!Platform.isAndroid) {
    final file = await FilePicker.pickFile();
    if (file?.path != null) await repository.setPath(file!.path!);
    return;
  }

  final dir = await FilePicker.getDirectoryPath();
  if (dir == null || !context.mounted) return;
  final files =
      Directory(dir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.txt'))
          .map((f) => f.path)
          .toList()
        ..sort();
  final picked = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(p.basename(dir)),
      children: [
        for (final f in files)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, f),
            child: Text(p.basename(f)),
          ),
      ],
    ),
  );
  if (picked != null) await repository.setPath(picked);
}
