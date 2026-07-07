import 'grid_state.dart';

/// Outcome of applying one action. Sealed: exhaustive switches everywhere.
sealed class StepResult {
  const StepResult();
}

/// The action was legal; [state] is the post-move state.
class Moved extends StepResult {
  const Moved(this.state);
  final GridState state;
}

/// The action was illegal; the pre-move state stands.
class Blocked extends StepResult {
  const Blocked();
}
