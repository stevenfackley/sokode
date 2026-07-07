import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';
import 'helpers/seal_code.dart';

Level goldenLevel() => levelFromAscii([
      '######',
      r'#@$ .#',
      '#    #',
      '######',
    ]);

const goldenSolution = [Direction.right, Direction.right];

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

  test('decode(encode(x)) reproduces level and solution exactly', () {
    final level = goldenLevel();
    final outcome = decode(encode(level, goldenSolution));
    final success = outcome as DecodeSuccess;
    expect(success.level.width, level.width);
    expect(success.level.height, level.height);
    expect(success.level.tiles, level.tiles);
    expect(success.level.playerIndex, level.playerIndex);
    expect(success.level.crateIndexes, level.crateIndexes);
    expect(success.solution, goldenSolution);
  });

  test('decode accepts non-canonical crate order (Level re-sorts)', () {
    // Encode a 2-crate level, swap the two crate index fields in the raw
    // bytes, re-seal, decode: same level, canonical order restored.
    final level = levelFromAscii([
      '######',
      r'#@$$.#',
      '#   .#',
      '######',
    ]);
    final code = encode(level, const [Direction.right]);
    final bytes = rawBytes(code);
    final body = bytes.sublist(0, bytes.length - 4);
    // tiles: 24 cells -> 12 bytes; crateCount at 7+12+2=21; crates at 22..25
    final tmp1 = body[22], tmp2 = body[23];
    body[22] = body[24];
    body[23] = body[25];
    body[24] = tmp1;
    body[25] = tmp2;
    final swapped = sealCode(body);
    final success = decode(swapped) as DecodeSuccess;
    expect(success.level.crateIndexes, level.crateIndexes);
  });
}
