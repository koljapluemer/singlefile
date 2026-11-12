import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'repository.dart';
import 'screens/choose_file.dart';
import 'screens/shell.dart';

void main() {
  runApp(const SinglefileApp());
}

class SinglefileApp extends StatefulWidget {
  const SinglefileApp({super.key});

  @override
  State<SinglefileApp> createState() => _SinglefileAppState();
}

class _SinglefileAppState extends State<SinglefileApp> {
  final _repository = FileRepository();
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepositoryChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    _repository.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() => setState(() {});

  Future<void> _bootstrap() async {
    if (Platform.isAndroid) {
      // Full disk access, so the file can live anywhere on device.
      await Permission.manageExternalStorage.request();
    }
    await _repository.init();
    if (!mounted) return;
    setState(() => _bootstrapped = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'singlefile',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_bootstrapped) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_repository.path == null) {
      return Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => FilledButton(
              onPressed: () => chooseFile(context, _repository),
              child: const Text('Choose file'),
            ),
          ),
        ),
      );
    }
    return Shell(repository: _repository);
  }
}
