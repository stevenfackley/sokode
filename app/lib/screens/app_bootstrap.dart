import 'package:flutter/material.dart';

import '../store/level_repository.dart';
import 'level_list_screen.dart';
import 'onboarding_screen.dart';

/// Decides what the app opens on: the first-run walkthrough, or the library.
///
/// This lives above [LevelListScreen] rather than inside it so the list
/// screen stays a plain widget with no first-run branch — screens that own a
/// "have I been here before" question are awkward to test and awkward to
/// reuse. Any pending web-fragment import is handed on unchanged and runs
/// once the library is actually on screen.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    required this.repository,
    this.initialImportCode,
  });

  final LevelRepository repository;
  final String? initialImportCode;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  /// null while the flag read is in flight — the first frame must not guess.
  bool? _needsOnboarding;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final flags = await widget.repository.loadFlags();
    if (!mounted) return;
    setState(() => _needsOnboarding = !flags.contains(onboardingSeenFlag));
  }

  Future<void> _finishOnboarding() async {
    await widget.repository.setFlag(onboardingSeenFlag);
    if (!mounted) return;
    setState(() => _needsOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_needsOnboarding) {
      null => const Scaffold(body: Center(child: CircularProgressIndicator())),
      true => OnboardingScreen(onDone: _finishOnboarding),
      false => LevelListScreen(
        repository: widget.repository,
        initialImportCode: widget.initialImportCode,
      ),
    };
  }
}
