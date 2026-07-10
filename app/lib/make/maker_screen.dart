import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sokode_core/sokode_core.dart';

import '../play/player_screen.dart';
import '../render/tile_palette_colors.dart';
import '../store/level_repository.dart';
import '../store/stored_level.dart';
import 'editor_state.dart';

/// Authoring surface: paint a board, test-solve it (through the SAME player
/// screen used to play), and publish a proof-carrying share code.
///
/// Publishing is gated twice — the button is disabled until a solve is
/// captured, AND publish re-verifies the recorded solution before encoding.
/// Any edit after a test-solve clears the captured solution (a stale proof
/// must never ship with a changed board).
///
/// [editor] is injectable so tests can drive authoring directly; in the app
/// it defaults to a fresh 8x8 board.
class MakerScreen extends StatefulWidget {
  const MakerScreen({super.key, required this.repository, this.editor});

  final LevelRepository repository;
  final EditorState? editor;

  @override
  State<MakerScreen> createState() => _MakerScreenState();
}

class _MakerScreenState extends State<MakerScreen> {
  late final EditorState _editor;
  late final bool _ownsEditor;
  List<Direction>? _capturedSolution;

  @override
  void initState() {
    super.initState();
    _ownsEditor = widget.editor == null;
    _editor = widget.editor ?? EditorState();
    _editor.addListener(_onEditorChange);
  }

  @override
  void dispose() {
    _editor.removeListener(_onEditorChange);
    if (_ownsEditor) _editor.dispose();
    super.dispose();
  }

  void _onEditorChange() {
    // Normative: any edit invalidates a previously captured solution.
    _capturedSolution = null;
    setState(() {});
  }

  bool get _canTest => _editor.validationProblems().isEmpty;
  bool get _canPublish => _capturedSolution != null;

  Future<void> _testPlay() async {
    final level = _editor.toLevel();
    if (level == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          level: level,
          title: 'Test play',
          onSolvedWithMoves: (moves) => _capturedSolution = List.of(moves),
        ),
      ),
    );
    setState(() {}); // refresh publish button after returning
  }

  Future<void> _publish() async {
    final level = _editor.toLevel();
    final solution = _capturedSolution;
    if (level == null || solution == null) return;
    final code = encode(level, solution);
    // Re-run the full publish gate (validate + verify) through the same
    // importer that guards incoming codes — belt and suspenders before save.
    if (const LevelImporter(SokobanPlus()).import(code) is! ImportSuccess) {
      return;
    }
    await widget.repository.saveCode(
      StoredCode(code: code, title: titleForLevel(level), kind: 'mine'),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('publish-dialog'),
        title: const Text('Level published'),
        content: SelectableText(code),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraft() async {
    final level = _editor.toLevel();
    if (level == null) {
      _snack('Place the player before saving a draft.');
      return;
    }
    await widget.repository.saveDraft(
      DraftLevel(name: titleForLevel(level), level: level),
    );
    _snack('Draft saved.');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final problems = _editor.validationProblems();
    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: Column(
        children: [
          _palette(),
          Expanded(child: Center(child: _canvas())),
          if (problems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                problems.join('  •  '),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  key: const ValueKey('test-play'),
                  onPressed: _canTest ? _testPlay : null,
                  child: const Text('Test'),
                ),
                ElevatedButton(
                  key: const ValueKey('publish'),
                  onPressed: _canPublish ? _publish : null,
                  child: const Text('Publish'),
                ),
                ElevatedButton(
                  key: const ValueKey('save-draft'),
                  onPressed: _saveDraft,
                  child: const Text('Save draft'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _palette() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final brush in Brush.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: ChoiceChip(
                key: ValueKey('brush-${brush.name}'),
                label: Text(brush.name),
                selected: _editor.brush == brush,
                onSelected: (_) => setState(() => _editor.brush = brush),
              ),
            ),
        ],
      ),
    );
  }

  Widget _canvas() {
    const colors = TilePaletteColors();
    return AspectRatio(
      aspectRatio: _editor.width / _editor.height,
      child: GridView.count(
        crossAxisCount: _editor.width,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < _editor.width * _editor.height; i++)
            GestureDetector(
              onTap: () => _editor.paint(i),
              child: _cell(i, colors),
            ),
        ],
      ),
    );
  }

  Widget _cell(int index, TilePaletteColors colors) {
    final tile = _editor.tileAt(index);
    final isPlayer = _editor.playerIndex == index;
    final isCrate = _editor.crateIndexes.contains(index);
    return Container(
      margin: const EdgeInsets.all(0.5),
      color: colors.colorFor(tile, isOpen: tile.isGate && tile.gateStartsOpen),
      child: Center(
        child: isPlayer
            ? const Icon(Icons.person, size: 12, color: Color(0xFF63D2A2))
            : isCrate
            ? const Icon(Icons.inventory_2, size: 12, color: Color(0xFFC98A4B))
            : null,
      ),
    );
  }
}
