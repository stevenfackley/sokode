import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/level_list_screen.dart';
import 'store/level_repository.dart';

void main() => runApp(const SokodeApp());

class SokodeApp extends StatelessWidget {
  const SokodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Web: sokode.com/#<code> — the URL fragment stays client-side (never in
    // server logs); hand it to the list screen's gated import flow.
    final fragment = kIsWeb && Uri.base.fragment.isNotEmpty
        ? Uri.base.fragment
        : null;
    return MaterialApp(
      title: 'Sokode',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: LevelListScreen(
        repository: defaultRepository(),
        initialImportCode: fragment,
      ),
    );
  }
}
