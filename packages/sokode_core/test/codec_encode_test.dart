import 'dart:convert';

import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

Level goldenLevel() => levelFromAscii([
      '######',
      r'#@$ .#',
      '#    #',
      '######',
    ]);

const goldenSolution = [Direction.right, Direction.right];

void main() {
  test('encode is deterministic (canonical)', () {
    expect(encode(goldenLevel(), goldenSolution),
        encode(goldenLevel(), goldenSolution));
  });

  test('output is base64url without padding', () {
    final code = encode(goldenLevel(), goldenSolution);
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code), isTrue);
    expect(code.contains('='), isFalse);
  });

  test('byte structure: header fields and trailing CRC are correct', () {
    final code = encode(goldenLevel(), goldenSolution);
    final bytes = base64Url.decode(code.padRight((code.length + 3) & ~3, '='));
    expect(bytes[0], 0x53); // 'S'
    expect(bytes[1], 0x4B); // 'K'
    expect(bytes[2], 1); // version
    expect(bytes[3], 1); // ruleset
    expect(bytes[4], 1); // flags: hasSolution only
    expect(bytes[5], 6); // width
    expect(bytes[6], 4); // height
    final body = bytes.sublist(0, bytes.length - 4);
    final stored = (bytes[bytes.length - 4] << 24) |
        (bytes[bytes.length - 3] << 16) |
        (bytes[bytes.length - 2] << 8) |
        bytes[bytes.length - 1];
    expect(crc32(body), stored);
    // 7 header + 12 tiles (24 cells) + 2 player + 1 count + 2 crate
    // + 2 moveCount + 1 moves (2 moves) + 4 crc = 31
    expect(bytes.length, 31);
  });

  test('GOLDEN: pinned code string', () {
    // GOLDEN-PIN PROCEDURE: literal starts as '' and the test FAILS,
    // printing the actual code. Pin it, rerun, commit. A future change to
    // this string is a wire-format break — never re-pin casually.
    final actual = encode(goldenLevel(), goldenSolution);
    printOnFailure('actual code: $actual');
    expect(actual, 'U0sBAQEGBBERERAAIRAAAREREQAHAQAIAAJQPH0FDA');
  });
}
