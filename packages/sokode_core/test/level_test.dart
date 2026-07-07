import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  test('crate indexes are canonically sorted regardless of input order', () {
    final level = Level(
      width: 4,
      height: 2,
      tiles: List.filled(8, Tile.floor),
      playerIndex: 0,
      crateIndexes: const [5, 2, 3],
    );
    expect(level.crateIndexes, [2, 3, 5]);
  });

  test('tiles and crateIndexes are unmodifiable', () {
    final level = Level(
      width: 4,
      height: 2,
      tiles: List.filled(8, Tile.floor),
      playerIndex: 0,
      crateIndexes: const [5],
    );
    expect(() => level.tiles[0] = Tile.wall, throwsUnsupportedError);
    expect(() => level.crateIndexes.add(1), throwsUnsupportedError);
  });

  test('ascii helper builds the expected level', () {
    final level = levelFromAscii([
      '#####',
      r'#@$.#',
      '#####',
    ]);
    expect(level.width, 5);
    expect(level.height, 3);
    expect(level.playerIndex, 6); // row 1, col 1
    expect(level.crateIndexes, [7]); // row 1, col 2
    expect(level.tileAt(8), Tile.target);
    expect(level.tileAt(0), Tile.wall);
    expect(level.tileAt(6), Tile.floor); // player marker leaves floor behind
  });

  test('ascii helper handles crate-on-target and player-on-target', () {
    final level = levelFromAscii([
      '####',
      '#+*#',
      '####',
    ]);
    expect(level.playerIndex, 5);
    expect(level.crateIndexes, [6]);
    expect(level.tileAt(5), Tile.target);
    expect(level.tileAt(6), Tile.target);
  });
}
