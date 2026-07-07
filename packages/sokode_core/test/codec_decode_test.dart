import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

void main() {
  test('DecodeError is the closed 13-error set from ENCODING.md', () {
    expect(DecodeError.values, const [
      DecodeError.badCharset,
      DecodeError.truncated,
      DecodeError.badMagic,
      DecodeError.unsupportedVersion,
      DecodeError.unsupportedRuleset,
      DecodeError.reservedFlagBits,
      DecodeError.missingSolution,
      DecodeError.dimensionOutOfBounds,
      DecodeError.payloadLengthMismatch,
      DecodeError.badChecksum,
      DecodeError.invalidTile,
      DecodeError.entityOutOfBounds,
      DecodeError.solutionTooLong,
    ]);
  });

  test('outcome types carry their payloads', () {
    const failure = DecodeFailure(DecodeError.badMagic);
    expect(failure.error, DecodeError.badMagic);
  });
}
