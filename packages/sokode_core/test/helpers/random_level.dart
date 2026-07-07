import 'dart:math';

import 'package:sokode_core/sokode_core.dart';

bool _blockedForEntities(Tile t) =>
    t == Tile.wall || t == Tile.gateAClosed || t == Tile.gateBClosed;

/// Generates a structurally plausible 8x8 level from a seeded [random].
/// Same seed => same level, always (property tests must be reproducible).
Level randomLevel(Random random) {
  const width = 8;
  const height = 8;
  final tiles = List<Tile>.generate(width * height, (_) {
    final roll = random.nextInt(12);
    if (roll == 0) return Tile.wall;
    if (roll == 1) return Tile.target;
    if (roll == 2) return Tile.values[3 + random.nextInt(4)]; // one-ways
    if (roll == 3) return random.nextBool() ? Tile.switchA : Tile.switchB;
    if (roll == 4) return Tile.values[9 + random.nextInt(4)]; // gates
    return Tile.floor;
  });
  final free = <int>[
    for (var i = 0; i < tiles.length; i++)
      if (!_blockedForEntities(tiles[i])) i,
  ]..shuffle(random);
  final player = free.removeLast();
  final crates = <int>[
    for (var i = 0; i < 3 && free.isNotEmpty; i++) free.removeLast(),
  ];
  return Level(
    width: width,
    height: height,
    tiles: tiles,
    playerIndex: player,
    crateIndexes: crates,
  );
}
