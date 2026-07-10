import 'package:sokode_core/sokode_core.dart';

/// Human-readable, non-technical strings for every import failure. UI
/// copy only — the typed values remain the source of truth.
String describeImportFailure(ImportOutcome outcome) => switch (outcome) {
  ImportSuccess() => 'Level imported.',
  ImportDecodeFailure(:final error) => switch (error) {
    DecodeError.badCharset ||
    DecodeError.badMagic ||
    DecodeError.truncated ||
    DecodeError.badChecksum ||
    DecodeError.payloadLengthMismatch ||
    DecodeError.invalidTile ||
    DecodeError.entityOutOfBounds =>
      'That code is damaged or incomplete — check you copied all of it.',
    DecodeError.unsupportedVersion ||
    DecodeError.unsupportedRuleset ||
    DecodeError.reservedFlagBits =>
      'That code was made with a newer version of Sokode. Update the app.',
    DecodeError.dimensionOutOfBounds || DecodeError.solutionTooLong =>
      "That code describes a level outside Sokode's limits.",
    DecodeError.missingSolution =>
      "That code has no solution proof, so it can't be trusted.",
  },
  ImportValidationFailure() =>
    "That level is not structurally valid, so it can't be played.",
  ImportVerifyFailure() =>
    "That level's solution proof doesn't check out — it may be fake.",
};
