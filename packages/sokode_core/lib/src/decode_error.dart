import 'direction.dart';
import 'level.dart';

/// Every way an untrusted share code can fail to decode. Closed set —
/// ENCODING.md is the normative mapping. `decode` is total: hostile input
/// yields exactly one of these; it never throws.
enum DecodeError {
  badCharset,
  truncated,
  badMagic,
  unsupportedVersion,
  unsupportedRuleset,
  reservedFlagBits,
  missingSolution,
  dimensionOutOfBounds,
  payloadLengthMismatch,
  badChecksum,
  invalidTile,
  entityOutOfBounds,
  solutionTooLong,
}

/// Result of decoding a share code. Sealed: switches are exhaustive.
sealed class DecodeOutcome {
  const DecodeOutcome();
}

/// Structurally well-formed code. NOT yet validated or solvability-proven —
/// that is LevelImporter's job (decode -> validateStructure -> verify).
class DecodeSuccess extends DecodeOutcome {
  const DecodeSuccess(this.level, this.solution);

  final Level level;

  /// The author's embedded solution replay (1..=4096 moves).
  final List<Direction> solution;
}

/// The code is rejected; [error] says exactly why (ENCODING.md mapping).
class DecodeFailure extends DecodeOutcome {
  const DecodeFailure(this.error);

  final DecodeError error;
}
