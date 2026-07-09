import 'package:flutter/material.dart';

void main() => runApp(const SokodeApp());

class SokodeApp extends StatelessWidget {
  const SokodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sokode',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const Placeholder(), // LevelListScreen arrives in Task 9
    );
  }
}
