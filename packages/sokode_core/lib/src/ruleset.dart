import 'direction.dart';
import 'grid_state.dart';
import 'level.dart';
import 'step_result.dart';
import 'validation.dart';

/// The extension point for game rules (spec §2.1). v1 ships SokobanPlus;
/// Baba-style / nonogram rulesets implement this later without touching
/// the simulation, codec, or verifier.
abstract interface class RuleSet {
  /// Pure transition. Never mutates [state]; returns Blocked for any
  /// illegal action rather than throwing.
  StepResult step(GridState state, Direction action);

  /// Win condition for [state].
  bool isSolved(GridState state);

  /// The subset of Direction.values whose step() is Moved.
  List<Direction> legalActions(GridState state);

  /// Ruleset-specific static checks on an authored level (spec §4).
  ValidationResult validateStructure(Level level);
}
