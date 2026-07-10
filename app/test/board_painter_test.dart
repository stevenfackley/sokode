import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/render/board_painter.dart';
import 'package:sokode_app/render/tile_palette_colors.dart';
import 'package:sokode_core/sokode_core.dart';

Level _level() => Level(
  width: 4,
  height: 4,
  tiles: [
    ...List.filled(4, Tile.wall),
    Tile.wall,
    Tile.floor,
    Tile.gateAOpen,
    Tile.wall,
    Tile.wall,
    Tile.target,
    Tile.switchA,
    Tile.wall,
    ...List.filled(4, Tile.wall),
  ],
  playerIndex: 5,
  crateIndexes: const [9],
);

void main() {
  test('cellSizeFor fits the limiting axis', () {
    expect(cellSizeFor(const Size(400, 200), 4, 4), 50);
    expect(cellSizeFor(const Size(200, 400), 4, 4), 50);
  });

  test('shouldRepaint only when state changes', () {
    final level = _level();
    const colors = TilePaletteColors();
    final a = BoardPainter(
      level: level,
      state: GridState.initial(level),
      colors: colors,
    );
    final b = BoardPainter(
      level: level,
      state: GridState.initial(level),
      colors: colors,
    );
    expect(a.shouldRepaint(b), isFalse);
    final moved = GridState(
      level: level,
      playerIndex: 6,
      crateIndexes: level.crateIndexes,
      openGateIndexes: const [6],
    );
    final c = BoardPainter(level: level, state: moved, colors: colors);
    expect(a.shouldRepaint(c), isTrue);
  });

  testWidgets('paints without throwing for every tile kind', (tester) async {
    // A level containing all 13 tile kinds; smoke-renders the painter.
    final tiles = List<Tile>.filled(16, Tile.floor)
      ..setRange(0, 13, Tile.values);
    final level = Level(
      width: 4,
      height: 4,
      tiles: tiles,
      playerIndex: 14,
      crateIndexes: const [15],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CustomPaint(
          size: const Size(200, 200),
          painter: BoardPainter(
            level: level,
            state: GridState.initial(level),
            colors: const TilePaletteColors(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
