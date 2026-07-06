/// A cardinal movement action. The `encoding` values are the 2-bit replay
/// alphabet used by the share-code format (ENCODING.md) — never renumber.
enum Direction {
  up(0, 0, -1),
  right(1, 1, 0),
  down(2, 0, 1),
  left(3, -1, 0);

  const Direction(this.encoding, this.dx, this.dy);

  /// 2-bit wire value. Invariant: equals this enum's declaration index.
  final int encoding;

  /// Column delta (+1 = right).
  final int dx;

  /// Row delta (+1 = down; grids are row-major, y grows downward).
  final int dy;

  /// Decodes a 2-bit value. Total: masks to 2 bits, cannot throw.
  static Direction fromEncoding(int bits) => Direction.values[bits & 3];
}
