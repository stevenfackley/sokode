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
      var next = _withPush(state, playerTo: target, crateTo: beyond);
      // Deterministic order (ARCHITECTURE.md): crate toggle before player
      // toggle, both against post-move occupancy.
      next = _fireSwitch(next, beyond);
      next = _fireSwitch(next, target);
      return Moved(next);
    }
    var next = _movePlayer(state, target);
    next = _fireSwitch(next, target);
    return Moved(next);
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

  /// If [arrivedAt] is a switch, toggles every gate of its channel in
  /// ascending cell order: closed -> open always; open -> closed only if
  /// unoccupied (spec §2.3 "never close an occupied gate"). Occupancy is
  /// evaluated against [state]'s (post-move) positions.
  GridState _fireSwitch(GridState state, int arrivedAt) {
    final channel = state.level.tiles[arrivedAt].switchChannel;
    if (channel == null) return state;
    final open = state.openGateIndexes.toList();
    for (var i = 0; i < state.level.cellCount; i++) {
      if (state.level.tiles[i].gateChannel != channel) continue;
      if (open.contains(i)) {
        if (!state.isOccupied(i)) open.remove(i);
      } else {
        open.add(i);
      }
    }
    return GridState(
      level: state.level,
      playerIndex: state.playerIndex,
      crateIndexes: state.crateIndexes,
      openGateIndexes: open,
    );
  }

  @override
  bool isSolved(GridState state) {
    for (var i = 0; i < state.level.cellCount; i++) {
      if (state.level.tiles[i] == Tile.target && !state.hasCrateAt(i)) {
        return false;
      }
    }
    return true;
  }

  @override
  List<Direction> legalActions(GridState state) => [
        for (final d in Direction.values)
          if (step(state, d) is Moved) d,
      ];

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
