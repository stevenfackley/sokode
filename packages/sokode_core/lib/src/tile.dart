import 'direction.dart';

/// The 13-entry static tile palette (spec §3). `nibble` is the 4-bit wire
/// value in the share-code format — never renumber. Values 13–15 reserved.
enum Tile {
  floor(0),
  wall(1),
  target(2),
  onewayUp(3),
  onewayRight(4),
  onewayDown(5),
  onewayLeft(6),
  switchA(7),
  switchB(8),
  gateAOpen(9),
  gateAClosed(10),
  gateBOpen(11),
  gateBClosed(12);

  const Tile(this.nibble);

  /// 4-bit wire value. Invariant: equals this enum's declaration index.
  final int nibble;

  /// Decodes a nibble. Returns null for reserved/out-of-range values —
  /// the codec maps that to DecodeError.invalidTile. Never throws.
  static Tile? fromNibble(int value) =>
      value >= 0 && value < values.length ? values[value] : null;

  /// The entry direction this one-way tile permits, or null if not one-way.
  Direction? get onewayDirection => switch (this) {
        Tile.onewayUp => Direction.up,
        Tile.onewayRight => Direction.right,
        Tile.onewayDown => Direction.down,
        Tile.onewayLeft => Direction.left,
        _ => null,
      };

  /// Switch channel (0 = A, 1 = B), or null if not a switch.
  int? get switchChannel => switch (this) {
        Tile.switchA => 0,
        Tile.switchB => 1,
        _ => null,
      };

  /// Gate channel (0 = A, 1 = B), or null if not a gate.
  int? get gateChannel => switch (this) {
        Tile.gateAOpen || Tile.gateAClosed => 0,
        Tile.gateBOpen || Tile.gateBClosed => 1,
        _ => null,
      };

  bool get isGate => gateChannel != null;

  /// Whether a gate tile begins the level open. Meaningless for non-gates.
  bool get gateStartsOpen => this == Tile.gateAOpen || this == Tile.gateBOpen;
}
