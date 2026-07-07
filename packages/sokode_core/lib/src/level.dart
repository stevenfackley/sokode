import 'tile.dart';

/// An authored, static level: the tile grid plus initial entity placement.
/// Immutable. Dimension caps (4..=32) are enforced by the validator and
/// codec (spec §3), not here — tests may build smaller boards.
class Level {
  /// [tiles] must have exactly `width * height` entries (row-major).
  /// [crateIndexes] is defensively copied and sorted ascending — the
  /// canonical order the share-code format requires.
  Level({
    required this.width,
    required this.height,
    required List<Tile> tiles,
    required this.playerIndex,
    required List<int> crateIndexes,
  })  : tiles = List.unmodifiable(tiles),
        crateIndexes = List.unmodifiable([...crateIndexes]..sort()) {
    assert(tiles.length == width * height, 'tiles must be width*height');
  }

  final int width;
  final int height;

  /// Row-major static tiles. Unmodifiable.
  final List<Tile> tiles;

  /// Cell index (`y * width + x`) of the player's start.
  final int playerIndex;

  /// Sorted ascending, unmodifiable. Invariant: canonical order.
  final List<int> crateIndexes;

  int get cellCount => width * height;

  Tile tileAt(int index) => tiles[index];
}
