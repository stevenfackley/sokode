import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';
import 'helpers/seal_code.dart';

void main() {
  Level level() => levelFromAscii([
        '######',
        r'#@$ .#',
        '#    #',
        '######',
      ]);
  String valid() => encode(level(), const [Direction.right, Direction.right]);

  DecodeError errorOf(String code) => (decode(code) as DecodeFailure).error;

  /// Rebuilds the valid code's body with one byte replaced, re-sealed with
  /// a correct CRC (so the mutation itself is what the decoder sees).
  String mutated(int index, int value) {
    final body = rawBytes(valid());
    final withoutCrc = body.sublist(0, body.length - 4);
    withoutCrc[index] = value;
    return sealCode(withoutCrc);
  }

  test('badCharset: illegal characters, empty string, invalid base64', () {
    expect(errorOf('not base64url!!!'), DecodeError.badCharset);
    expect(errorOf(''), DecodeError.badCharset);
    expect(errorOf('A'), DecodeError.badCharset); // 1 char is invalid b64
  });

  test('truncated: fewer than header+crc bytes', () {
    expect(errorOf(sealCode(const [0x53, 0x4B, 1])), DecodeError.truncated);
  });

  test('badMagic', () {
    expect(errorOf(mutated(0, 0x58)), DecodeError.badMagic);
  });

  test('badChecksum: any bit flip without resealing', () {
    final bytes = rawBytes(valid());
    bytes[8] ^= 0xFF; // corrupt a tile byte, keep stale CRC
    final code = sealCode(bytes.sublist(0, bytes.length - 4), crcDelta: 1);
    expect(errorOf(code), DecodeError.badChecksum);
  });

  test('unsupportedVersion', () {
    expect(errorOf(mutated(2, 9)), DecodeError.unsupportedVersion);
  });

  test('unsupportedRuleset', () {
    expect(errorOf(mutated(3, 7)), DecodeError.unsupportedRuleset);
  });

  test('missingSolution: flags bit0 = 0', () {
    expect(errorOf(mutated(4, 0x00)), DecodeError.missingSolution);
  });

  test('reservedFlagBits: any of bits 1-7 set', () {
    expect(errorOf(mutated(4, 0x03)), DecodeError.reservedFlagBits);
  });

  test('dimensionOutOfBounds: 3, 33, 255, 0', () {
    expect(errorOf(mutated(5, 3)), DecodeError.dimensionOutOfBounds);
    expect(errorOf(mutated(5, 33)), DecodeError.dimensionOutOfBounds);
    expect(errorOf(mutated(6, 255)), DecodeError.dimensionOutOfBounds);
    expect(errorOf(mutated(6, 0)), DecodeError.dimensionOutOfBounds);
  });

  test('a code claiming huge dims dies before any tile allocation', () {
    // 32x32 is the max; 200x200 must be rejected at the header compare.
    final body = [0x53, 0x4B, 1, 1, 1, 200, 200];
    expect(errorOf(sealCode(body)), DecodeError.dimensionOutOfBounds);
  });

  test('truncated: valid header, tile section cut short', () {
    final body = [0x53, 0x4B, 1, 1, 1, 6, 4, 0x00, 0x00]; // 2 of 12 bytes
    expect(errorOf(sealCode(body)), DecodeError.truncated);
  });

  test('invalidTile: reserved nibble 13-15', () {
    expect(errorOf(mutated(7, 0xDD)), DecodeError.invalidTile); // 13,13
  });

  test('entityOutOfBounds: player index >= cellCount', () {
    // player u16 sits right after 12 tile bytes: offsets 19..20
    final body = rawBytes(valid()).sublist(0, rawBytes(valid()).length - 4);
    body[19] = 0xFF;
    body[20] = 0xFF;
    expect(errorOf(sealCode(body)), DecodeError.entityOutOfBounds);
  });

  test('solutionTooLong: moveCount > 4096', () {
    // moveCount u16 at offset 24..25 (header 7 + tiles 12 + player 2 +
    // count 1 + one crate 2). Also extend body so length checks pass first?
    // No: solutionTooLong is checked immediately after reading the count,
    // BEFORE reading move bytes — so mutating the count alone suffices.
    final body = rawBytes(valid()).sublist(0, rawBytes(valid()).length - 4);
    body[24] = 0xFF;
    body[25] = 0xFF; // 65535 > 4096
    expect(errorOf(sealCode(body)), DecodeError.solutionTooLong);
  });

  test('missingSolution: moveCount == 0', () {
    final body = rawBytes(valid()).sublist(0, rawBytes(valid()).length - 4);
    body[24] = 0;
    body[25] = 0;
    expect(errorOf(sealCode(body)), DecodeError.missingSolution);
  });

  test('payloadLengthMismatch: trailing surplus bytes', () {
    final body = rawBytes(valid()).sublist(0, rawBytes(valid()).length - 4);
    expect(
        errorOf(sealCode([...body, 0x00])), DecodeError.payloadLengthMismatch);
  });

  test('payloadLengthMismatch: nonzero padding bits in final move byte', () {
    // 2 moves used -> low 4 bits of the single move byte must be 0.
    final body = rawBytes(valid()).sublist(0, rawBytes(valid()).length - 4);
    body[body.length - 1] |= 0x01; // last body byte is the move byte
    expect(errorOf(sealCode(body)), DecodeError.payloadLengthMismatch);
  });
}
