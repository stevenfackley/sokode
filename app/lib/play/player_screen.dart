import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sokode_core/sokode_core.dart';

import '../render/board_view.dart';
import 'player_session.dart';

/// Maps a pan-end velocity to a move direction, or null if the fling was
/// too weak. The dominant axis wins; ties resolve horizontal.
Direction? directionFromPanVelocity(Offset velocity) {
  const minVelocity = 100.0;
  if (velocity.distance < minVelocity) return null;
  if (velocity.dx.abs() >= velocity.dy.abs()) {
    return velocity.dx > 0 ? Direction.right : Direction.left;
  }
  return velocity.dy > 0 ? Direction.down : Direction.up;
}

/// Plays a single level to completion. Owns a [PlayerSession]; every rule
/// comes from the core. Fires [onSolvedWithMoves] with the winning replay
/// the instant the level is solved, and [onSolved] when the win dialog is
/// dismissed with "Done".
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.level,
    this.title,
    this.onSolved,
    this.onSolvedWithMoves,
  });

  final Level level;
  final String? title;
  final VoidCallback? onSolved;
  final void Function(List<Direction> moves)? onSolvedWithMoves;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerSession _session = PlayerSession(widget.level);
  bool _winHandled = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onChange);
  }

  @override
  void dispose() {
    _session.removeListener(_onChange);
    _session.dispose();
    super.dispose();
  }

  void _onChange() {
    if (_session.isSolved && !_winHandled) {
      _winHandled = true;
      widget.onSolvedWithMoves?.call(_session.moves);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWin());
    }
    setState(() {});
  }

  void _move(Direction direction) {
    if (_session.tryMove(direction) && !kIsWeb) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _showWin() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        key: const ValueKey('win-dialog'),
        title: const Text('Solved!'),
        content: Text('Solved in ${_session.moveCount} moves.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _winHandled = false;
                _session.reset();
              });
            },
            child: const Text('Replay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onSolved?.call();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => Direction.up,
      LogicalKeyboardKey.arrowRight => Direction.right,
      LogicalKeyboardKey.arrowDown => Direction.down,
      LogicalKeyboardKey.arrowLeft => Direction.left,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    _move(direction);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? titleForLevel(widget.level)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text('${_session.moveCount}')),
          ),
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: _session.canUndo ? _session.undo : null,
          ),
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.refresh),
            onPressed: _session.reset,
          ),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          onPanEnd: (details) {
            final direction = directionFromPanVelocity(
              details.velocity.pixelsPerSecond,
            );
            if (direction != null) _move(direction);
          },
          child: Center(
            child: AspectRatio(
              aspectRatio: widget.level.width / widget.level.height,
              child: BoardView(level: widget.level, state: _session.state),
            ),
          ),
        ),
      ),
    );
  }
}
