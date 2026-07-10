import 'package:flutter/material.dart';
import 'package:sokode_core/sokode_core.dart';

import '../import/import_strings.dart';
import '../make/maker_screen.dart';
import '../play/player_screen.dart';
import '../store/level_repository.dart';
import '../store/stored_level.dart';

/// Home screen: three tabs (Mine / Imported / Drafts), a gated paste-import,
/// and a "new level" button into the maker. Pasting a code is validated
/// input, not free text — a code that fails the import gate is never saved.
class LevelListScreen extends StatefulWidget {
  const LevelListScreen({
    super.key,
    required this.repository,
    this.importer = const LevelImporter(SokobanPlus()),
    this.initialImportCode,
  });

  final LevelRepository repository;
  final LevelImporter importer;

  /// A code to import once on first build (e.g. a `sokode.com/#<code>`
  /// web fragment). Runs through the same gate as a manual paste.
  final String? initialImportCode;

  @override
  State<LevelListScreen> createState() => _LevelListScreenState();
}

class _LevelListScreenState extends State<LevelListScreen> {
  List<StoredCode> _codes = [];
  List<DraftLevel> _drafts = [];

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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(level: outcome.level, title: stored.title),
      ),
    );
  }

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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sokode'),
          actions: [
            IconButton(
              key: const ValueKey('import-button'),
              tooltip: 'Import a code',
              icon: const Icon(Icons.download),
              onPressed: _openImportDialog,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mine'),
              Tab(text: 'Imported'),
              Tab(text: 'Drafts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_codeList('mine'), _codeList('imported'), _draftList()],
        ),
        floatingActionButton: FloatingActionButton(
          key: const ValueKey('new-level'),
          onPressed: _newLevel,
          child: const Icon(Icons.add),
        ),
      ),
    );
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
