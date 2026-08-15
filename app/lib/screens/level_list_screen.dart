import 'package:flutter/material.dart';
import 'package:sokode_core/sokode_core.dart';

import '../content/seed_library.dart';
import '../import/import_strings.dart';
import '../make/maker_screen.dart';
import '../play/player_screen.dart';
import '../store/level_repository.dart';
import '../store/stored_level.dart';
import 'onboarding_screen.dart';

/// Home screen: four tabs (Samples / Mine / Imported / Drafts), a gated
/// paste-import, and a "new level" button into the maker. Pasting a code is
/// validated input, not free text — a code that fails the import gate is
/// never saved.
class LevelListScreen extends StatefulWidget {
  const LevelListScreen({
    super.key,
    required this.repository,
    this.importer = const LevelImporter(SokobanPlus()),
    this.initialImportCode,
    this.seeds,
  });

  final LevelRepository repository;
  final LevelImporter importer;

  /// A code to import once on first build (e.g. a `sokode.com/#<code>`
  /// web fragment). Runs through the same gate as a manual paste.
  final String? initialImportCode;

  /// Shipped sample levels. Defaults to the generated catalog; injectable so
  /// tests can drive the tab without depending on shipped content.
  final List<SeedEntry>? seeds;

  @override
  State<LevelListScreen> createState() => _LevelListScreenState();
}

class _LevelListScreenState extends State<LevelListScreen> {
  List<StoredCode> _codes = [];
  List<DraftLevel> _drafts = [];
  late final List<SeedEntry> _seeds = widget.seeds ?? loadSeedLibrary();

  @override
  void initState() {
    super.initState();
    _reload();
    final initial = widget.initialImportCode;
    if (initial != null && initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleImport(initial),
      );
    }
  }

  Future<void> _reload() async {
    final codes = await widget.repository.loadCodes();
    final drafts = await widget.repository.loadDrafts();
    if (!mounted) return;
    setState(() {
      _codes = codes;
      _drafts = drafts;
    });
  }

  Future<void> _handleImport(String raw) async {
    final outcome = widget.importer.import(raw.trim());
    if (outcome is ImportSuccess) {
      // Store the canonical re-encoding so duplicates dedupe by code.
      final canonical = encode(outcome.level, outcome.solution);
      await widget.repository.saveCode(
        StoredCode(
          code: canonical,
          title: titleForLevel(outcome.level),
          kind: 'imported',
        ),
      );
      await _reload();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeImportFailure(outcome),
            key: const ValueKey('import-error'),
          ),
        ),
      );
    }
  }

  Future<void> _openImportDialog() async {
    // Capture text via onChanged rather than a controller — a controller
    // disposed right after showDialog() returns would still be read by the
    // dialog's exit animation.
    var text = '';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste a level code'),
        content: TextField(
          key: const ValueKey('import-field'),
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Level code'),
          onChanged: (value) => text = value,
          onSubmitted: (value) {
            Navigator.of(context).pop();
            _handleImport(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleImport(text);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _play(StoredCode stored) async {
    final outcome = decode(stored.code);
    if (outcome is! DecodeSuccess) return;
    await _open(outcome.level, stored.title);
  }

  Future<void> _open(Level level, String title) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(level: level, title: title),
    ),
  );

  Future<void> _showHowToPlay() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()));

  Future<void> _newLevel() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MakerScreen(repository: widget.repository),
      ),
    );
    await _reload();
  }

  Future<void> _delete(Future<void> Function() action) async {
    await action();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sokode'),
          actions: [
            IconButton(
              key: const ValueKey('how-to-play-button'),
              tooltip: 'How to play',
              icon: const Icon(Icons.help_outline),
              onPressed: _showHowToPlay,
            ),
            IconButton(
              key: const ValueKey('import-button'),
              tooltip: 'Import a code',
              icon: const Icon(Icons.download),
              onPressed: _openImportDialog,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Samples'),
              Tab(text: 'Mine'),
              Tab(text: 'Imported'),
              Tab(text: 'Drafts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _sampleList(),
            _codeList('mine'),
            _codeList('imported'),
            _draftList(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          key: const ValueKey('new-level'),
          onPressed: _newLevel,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// Samples ship with the app and need no storage: they are ordinary codes
  /// that have already passed the import gate in [loadSeedLibrary].
  Widget _sampleList() {
    if (_seeds.isEmpty) {
      return const Center(child: Text('No sample levels in this build.'));
    }
    final rows = <Widget>[];
    var number = 0;
    String? currentPack;
    for (final seed in _seeds) {
      if (seed.pack != currentPack) {
        currentPack = seed.pack;
        number = 0;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              seed.pack,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        );
      }
      number++;
      rows.add(
        ListTile(
          key: ValueKey('seed-${seed.code}'),
          // The number disambiguates the rare pair of derived titles that
          // land on the same word pair; it is never user text.
          title: Text('$number. ${seed.title}'),
          subtitle: Text('Par ${seed.parMoves}'),
          onTap: () => _open(seed.level, seed.title),
        ),
      );
    }
    return ListView(children: rows);
  }

  Widget _codeList(String kind) {
    final items = _codes.where((c) => c.kind == kind).toList();
    if (items.isEmpty) return const Center(child: Text('Nothing here yet.'));
    return ListView(
      children: [
        for (final c in items)
          ListTile(
            title: Text(c.title),
            onTap: () => _play(c),
            onLongPress: () =>
                _delete(() => widget.repository.deleteCode(c.code)),
          ),
      ],
    );
  }

  Widget _draftList() {
    if (_drafts.isEmpty) return const Center(child: Text('No drafts yet.'));
    return ListView(
      children: [
        for (final d in _drafts)
          ListTile(
            title: Text(d.name),
            onLongPress: () =>
                _delete(() => widget.repository.deleteDraft(d.name)),
          ),
      ],
    );
  }
}
