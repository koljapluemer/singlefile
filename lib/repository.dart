import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model/document.dart';

const _prefsPathKey = 'file_path';

/// The data file's text and its parsed [Document].
class FileRepository extends ChangeNotifier {
  String? path;
  String text = '';
  String? loadError;
  Document document = parseDocument('');

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    path = prefs.getString(_prefsPathKey);
    await load();
  }

  Future<void> setPath(String newPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPathKey, newPath);
    path = newPath;
    await load();
  }

  Future<void> load() async {
    if (path == null) return;
    try {
      text = await File(path!).readAsString();
      loadError = null;
      document = parseDocument(text);
    } catch (e) {
      loadError = '$e';
    }
    notifyListeners();
  }

  Future<void> save(String newText) async {
    if (path == null || newText == text) return;
    try {
      await File(path!).writeAsString(newText, flush: true);
      loadError = null;
      text = newText;
      document = parseDocument(text);
    } catch (e) {
      loadError = 'save failed: $e';
    }
    notifyListeners();
  }
}
