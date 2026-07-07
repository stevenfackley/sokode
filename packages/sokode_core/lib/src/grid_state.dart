import 'level.dart';

/// Immutable runtime state: entity positions plus per-gate open/closed.
///
/// Gate state is per-cell, not per-channel parity: the "a toggle never
/// closes an occupied gate" rule (spec §2.3) lets individual gates desync
/// from their channel, so parity alone cannot represent reachable states.
///
/// Canonical form: `crateIndexes` and `openGateIndexes` are always sorted
/// ascending — equality, hashing, and stateDigest rely on it.
class GridState {
  GridState({
    required this.level,
    required this.playerIndex,
    required List<int> crateIndexes,
    required List<int> openGateIndexes,
  })  : crateIndexes = List.unmodifiable([...crateIndexes]..sort()),
        openGateIndexes = List.unmodifiable([...openGateIndexes]..sort());

  /// Builds the pre-first-move state. Reads gate openness straight from the
  /// tile palette; deliberately fires NO switch toggles (spec §2.3:
  /// "initial placement fires nothing").
  factory GridState.initial(Level level) {
    final open = <int>[];
    for (var i = 0; i < level.cellCount; i++) {
      final tile = level.tiles[i];
      if (tile.isGate && tile.gateStartsOpen) open.add(i);
    }
    return GridState(
      level: level,
      playerIndex: level.playerIndex,
      crateIndexes: level.crateIndexes,
      openGateIndexes: open,
    );
  }

  final Level level;
  final int playerIndex;

  /// Sorted ascending, unmodifiable.
  final List<int> crateIndexes;

  /// Cell indexes of gates that are currently open. Sorted, unmodifiable.
  final List<int> openGateIndexes;

  /// Linear scan — crate lists are tiny (≤ ~50); an index structure would
  /// cost more in copying than it saves in lookups.
  bool hasCrateAt(int index) => crateIndexes.contains(index);

  bool isGateOpenAt(int index) => openGateIndexes.contains(index);

  bool isOccupied(int index) => index == playerIndex || hasCrateAt(index);

  @override
  bool operator ==(Object other) =>
      other is GridState &&
      other.playerIndex == playerIndex &&
      _listEquals(other.crateIndexes, crateIndexes) &&
      _listEquals(other.openGateIndexes, openGateIndexes);

  /// In-process hash only. Cross-platform/deterministic fingerprinting is
  /// stateDigest's job, not hashCode's.
  @override
  int get hashCode => Object.hash(
        playerIndex,
        Object.hashAll(crateIndexes),
        Object.hashAll(openGateIndexes),
      );
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
