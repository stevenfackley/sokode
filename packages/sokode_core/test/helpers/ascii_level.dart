import 'package:sokode_core/sokode_core.dart';

/// Builds a Level from an ASCII map. Legend:
///   `#` wall   ` ` floor   `.` target
///   `@` player-on-floor    `+` player-on-target
///   `$` crate-on-floor     `*` crate-on-target
///   `^ > v <` one-way (permitted entry direction)
///   `a` switch A   `b` switch B
///   `[` gate A open   `]` gate A closed
///   `{` gate B open   `}` gate B closed
Level levelFromAscii(List<String> rows) {
  final height = rows.length;
  final width = rows.first.length;
  final tiles = <Tile>[];
  int? player;
  final crates = <int>[];
  for (var y = 0; y < height; y++) {
    if (rows[y].length != width) {
      throw ArgumentError('row $y has length ${rows[y].length}, want $width');
    }
    for (var x = 0; x < width; x++) {
      final index = y * width + x;
      final ch = rows[y][x];
      tiles.add(switch (ch) {
        '#' => Tile.wall,
        ' ' || '@' || r'$' => Tile.floor,
        '.' || '+' || '*' => Tile.target,
        '^' => Tile.onewayUp,
        '>' => Tile.onewayRight,
        'v' => Tile.onewayDown,
        '<' => Tile.onewayLeft,
        'a' => Tile.switchA,
        'b' => Tile.switchB,
        '[' => Tile.gateAOpen,
        ']' => Tile.gateAClosed,
        '{' => Tile.gateBOpen,
        '}' => Tile.gateBClosed,
        _ => throw ArgumentError('unknown map char "$ch" at ($x,$y)'),
      });
      if (ch == '@' || ch == '+') player = index;
      if (ch == r'$' || ch == '*') crates.add(index);
    }
  }
  return Level(
    width: width,
    height: height,
    tiles: tiles,
    playerIndex: player!,
    crateIndexes: crates,
  );
}
