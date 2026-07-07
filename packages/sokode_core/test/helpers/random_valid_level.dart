import 'dart:math';

import 'package:sokode_core/sokode_core.dart';

/// Generates a level that passes SokobanPlus.validateStructure, from a
/// seeded [random] (same seed => same level). Construction places targets,
/// crates, and the player on plain floor AFTER sprinkling obstacles, so
/// validity holds by construction; a final check guards generator bugs.
Level randomValidLevel(Random random) {
  final width = codecMinDimension + random.nextInt(9); // 4..12
  final height = codecMinDimension + random.nextInt(9);
  final tiles = List<Tile>.generate(width * height, (_) {
    final roll = random.nextInt(10);
    if (roll == 0) return Tile.wall;
    if (roll == 1) return Tile.values[3 + random.nextInt(4)]; // one-ways
    if (roll == 2) return random.nextBool() ? Tile.switchA : Tile.switchB;
    if (roll == 3) return Tile.values[9 + random.nextInt(4)]; // gates
    return Tile.floor;
  });
  final floorCells = <int>[
    for (var i = 0; i < tiles.length; i++)
      if (tiles[i] == Tile.floor) i,
  ]..shuffle(random);
  final targetCount = 1 + random.nextInt(3);
  // Need: targets + crates (>= targets) + player, all on distinct cells.
  final crateCount = targetCount + random.nextInt(2);
  if (floorCells.length < targetCount + crateCount + 1) {
    return randomValidLevel(random); // sparse board — reroll
  }
  for (var t = 0; t < targetCount; t++) {
    tiles[floorCells.removeLast()] = Tile.target;
  }
  final crates = <int>[
    for (var c = 0; c < crateCount; c++) floorCells.removeLast(),
  ];
  final level = Level(
    width: width,
    height: height,
    tiles: tiles,
    playerIndex: floorCells.removeLast(),
    crateIndexes: crates,
  );
  final validation = const SokobanPlus().validateStructure(level);
  if (!validation.isValid) {
    throw StateError('generator bug: ${validation.errors}');
  }
  return level;
}

/// Random 1..50-move sequence (need not solve anything — the codec
/// roundtrip does not require solvability, only the import gate does).
List<Direction> randomMoves(Random random) => [
      for (var i = 0, n = 1 + random.nextInt(50); i < n; i++)
        Direction.values[random.nextInt(4)],
    ];
