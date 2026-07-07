import 'decode_error.dart';
import 'direction.dart';
import 'level.dart';
import 'level_codec.dart';
import 'replay_verifier.dart';
import 'ruleset.dart';
import 'simulation.dart';
import 'validation.dart';

/// Outcome of importing an untrusted share code. Sealed.
sealed class ImportOutcome {
  const ImportOutcome();
}

/// The code decoded, validated, AND proved solvable by its embedded
/// replay. Only levels wrapped in this type may become playable.
class ImportSuccess extends ImportOutcome {
  const ImportSuccess(this.level, this.solution);

  final Level level;
  final List<Direction> solution;
}

class ImportDecodeFailure extends ImportOutcome {
  const ImportDecodeFailure(this.error);

  final DecodeError error;
}

class ImportValidationFailure extends ImportOutcome {
  const ImportValidationFailure(this.errors);

  final List<ValidationError> errors;
}

class ImportVerifyFailure extends ImportOutcome {
  const ImportVerifyFailure(this.failure);

  final VerifyFailure failure;
}

/// The publish gate, enforced at IMPORT time (spec §4): decode ->
/// validateStructure -> verify embedded solution, all mandatory, all
/// through the same RuleSet/Simulation used for play. A hand-crafted code
/// for an impossible level dies at the verify stage — the code carries its
/// own proof or it does not get in.
class LevelImporter {
  const LevelImporter(this.ruleSet);

  final RuleSet ruleSet;

  ImportOutcome import(String code) {
    switch (decode(code)) {
      case DecodeFailure(:final error):
        return ImportDecodeFailure(error);
      case DecodeSuccess(:final level, :final solution):
        final validation = ruleSet.validateStructure(level);
        if (!validation.isValid) {
          return ImportValidationFailure(validation.errors);
        }
        final verifier = ReplayVerifier(Simulation(ruleSet));
        return switch (verifier.verify(level, solution)) {
          VerifySuccess() => ImportSuccess(level, solution),
          final VerifyFailure failure => ImportVerifyFailure(failure),
        };
    }
  }
}
