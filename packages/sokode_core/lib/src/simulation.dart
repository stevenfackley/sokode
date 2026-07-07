import 'direction.dart';
import 'grid_state.dart';
import 'level.dart';
import 'ruleset.dart';
import 'step_result.dart';

/// The single entry point for advancing game state. Play, replay
/// verification (Plan 02), and the import gate all go through this class —
/// never fork a second transition path (spec §2.2).
class Simulation {
  const Simulation(this.ruleSet);

  final RuleSet ruleSet;

  GridState initialState(Level level) => GridState.initial(level);

  StepResult apply(GridState state, Direction action) =>
      ruleSet.step(state, action);
}
