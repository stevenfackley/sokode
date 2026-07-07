import 'direction.dart';
import 'grid_state.dart';
import 'level.dart';
import 'ruleset.dart';
import 'step_result.dart';
import 'tile.dart';
import 'validation.dart';

/// The v1 ruleset. Semantics pinned in spec §2.3 — every bullet there has
/// a test in this package.
class SokobanPlus implements RuleSet {
  const SokobanPlus();

  @override
  StepResult step(GridState state, Direction action) {
    final target = _neighbor(state.level, state.playerIndex, action);
    if (target == null) return const Blocked();
    if (!_canEnter(state, target, action)) return const Blocked();
    if (state.hasCrateAt(target)) {
      final beyond = _neighbor(state.level, target, action);
      if (beyond == null) return const Blocked();
      if (state.hasCrateAt(beyond)) return const Blocked();
      if (!_canEnter(state, beyond, action)) return const Blocked();
      return Moved(_withPush(state, playerTo: target, crateTo: beyond));
    }
    return Moved(_movePlayer(state, target));
  }

  /// Crate leaves [playerTo] (the player takes its cell) and lands on
  /// [crateTo]. The GridState constructor re-sorts, keeping canonical order.
  GridState _withPush(GridState state,
      {required int playerTo, required int crateTo}) {
    final crates = state.crateIndexes.toList()
      ..remove(playerTo)
      ..add(crateTo);
    return GridState(
      level: state.level,
      playerIndex: playerTo,
      crateIndexes: crates,
      openGateIndexes: state.openGateIndexes,
    );
  }

  @override
  bool isSolved(GridState state) => false; // Task 10

  @override
  List<Direction> legalActions(GridState state) => const []; // Task 10

  @override
  ValidationResult validateStructure(Level level) =>
      const ValidationResult([]); // Task 11

  /// Neighbor cell index in [dir], or null when off-board (edges block —
  /// no wrap-around; index±1 alone would wrap rows, hence x/y math).
  int? _neighbor(Level level, int index, Direction dir) {
    final x = index % level.width + dir.dx;
    final y = index ~/ level.width + dir.dy;
    if (x < 0 || x >= level.width || y < 0 || y >= level.height) return null;
    return y * level.width + x;
  }

  /// Entry rules shared by player and crates (spec §2.3: one-ways
  /// constrain entry only, and apply to both).
  bool _canEnter(GridState state, int index, Direction dir) {
    final tile = state.level.tiles[index];
    if (tile == Tile.wall) return false;
    if (tile.isGate && !state.isGateOpenAt(index)) return false;
    final oneway = tile.onewayDirection;
    if (oneway != null && oneway != dir) return false;
    return true;
  }

  GridState _movePlayer(GridState state, int to) => GridState(
        level: state.level,
        playerIndex: to,
        crateIndexes: state.crateIndexes,
        openGateIndexes: state.openGateIndexes,
      );
}
