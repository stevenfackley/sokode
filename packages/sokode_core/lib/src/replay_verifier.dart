import 'direction.dart';
import 'grid_state.dart';
import 'level.dart';
import 'level_codec.dart';
import 'simulation.dart';
import 'step_result.dart';

/// Result of verifying a solution replay. Sealed for exhaustive handling.
sealed class VerifyResult {
  const VerifyResult();
}

/// The replay solves the level. [solvedAtMove] is how many moves were
/// consumed (0 for a pre-solved level); trailing moves are ignored.
class VerifySuccess extends VerifyResult {
  const VerifySuccess(this.finalState, this.solvedAtMove);

  final GridState finalState;
  final int solvedAtMove;
}

sealed class VerifyFailure extends VerifyResult {
  const VerifyFailure();
}

class VerifyEmptyReplay extends VerifyFailure {
  const VerifyEmptyReplay();
}

/// Replay exceeds the 4096-move ceiling — rejected before any simulation
/// so an oversized replay cannot be used as a CPU DoS (spec §4).
class VerifyTooLong extends VerifyFailure {
  const VerifyTooLong();
}

/// Move [moveIndex] was Blocked. Verification is strict: a proof
/// containing illegal moves is not a proof.
class VerifyIllegalMove extends VerifyFailure {
  const VerifyIllegalMove(this.moveIndex);

  final int moveIndex;
}

class VerifyNotSolved extends VerifyFailure {
  const VerifyNotSolved();
}

/// Replays a recorded solution through the SAME Simulation used for play —
/// the publish/import gate's proof checker (spec §4). Never forks its own
/// transition logic.
class ReplayVerifier {
  const ReplayVerifier(this.simulation);

  final Simulation simulation;

  VerifyResult verify(Level level, List<Direction> moves) {
    if (moves.isEmpty) return const VerifyEmptyReplay();
    if (moves.length > codecMaxSolutionMoves) return const VerifyTooLong();
    var state = simulation.initialState(level);
    if (simulation.ruleSet.isSolved(state)) return VerifySuccess(state, 0);
    for (var i = 0; i < moves.length; i++) {
      switch (simulation.apply(state, moves[i])) {
        case Blocked():
          return VerifyIllegalMove(i);
        case Moved(state: final next):
          state = next;
          if (simulation.ruleSet.isSolved(state)) {
            return VerifySuccess(state, i + 1);
          }
      }
    }
    return const VerifyNotSolved();
  }
}
