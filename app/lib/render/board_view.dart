import 'package:flutter/material.dart';
import 'package:sokode_core/sokode_core.dart';

import 'board_painter.dart';
import 'tile_palette_colors.dart';

/// Renders a level: the static tile layer via [BoardPainter] plus an
/// animated entity layer (player + crates) that tweens to new positions
/// whenever [state] changes. Holds no game rules — it draws whatever state
/// it is handed.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.level,
    required this.state,
    this.moveDuration = const Duration(milliseconds: 120),
    this.colors = const TilePaletteColors(),
  });

  final Level level;
  final GridState state;
  final Duration moveDuration;
  final TilePaletteColors colors;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final cell = cellSizeFor(size, level.width, level.height);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: BoardPainter(
                  level: level,
                  state: state,
                  colors: colors,
                ),
              ),
            ),
            _entity(
              key: const ValueKey('player'),
              index: state.playerIndex,
              cell: cell,
              child: _PlayerMarker(size: cell),
            ),
            // Crates are anonymous — keyed by their position in the sorted
            // crateIndexes list. A multi-crate push can re-sort that list and
            // swap two keys mid-animation, producing a rare visual swap. That
            // is accepted for v1: tween-on-move is a nicety, not a contract.
            for (var i = 0; i < state.crateIndexes.length; i++)
              _entity(
                key: ValueKey('crate-$i'),
                index: state.crateIndexes[i],
                cell: cell,
                child: _CrateMarker(
                  size: cell,
                  onTarget: level.tiles[state.crateIndexes[i]] == Tile.target,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _entity({
    required Key key,
    required int index,
    required double cell,
    required Widget child,
  }) {
    final col = index % level.width;
    final row = index ~/ level.width;
    return AnimatedPositioned(
      key: key,
      duration: moveDuration,
      curve: Curves.easeOut,
      left: col * cell,
      top: row * cell,
      width: cell,
      height: cell,
      child: child,
    );
  }
}

class _PlayerMarker extends StatelessWidget {
  const _PlayerMarker({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(size * 0.18),
    child: const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFF63D2A2),
        shape: BoxShape.circle,
      ),
    ),
  );
}

class _CrateMarker extends StatelessWidget {
  const _CrateMarker({required this.size, required this.onTarget});

  final double size;
  final bool onTarget;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(size * 0.14),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: onTarget ? const Color(0xFF8AD98A) : const Color(0xFFC98A4B),
        borderRadius: BorderRadius.circular(size * 0.14),
      ),
    ),
  );
}
