import 'dart:math';

import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/random_valid_level.dart';
import 'helpers/seal_code.dart';

void main() {
  test('PROPERTY: decode(encode(x)) == x over 300 random levels', () {
    final random = Random(2026);
    for (var trial = 0; trial < 300; trial++) {
      final level = randomValidLevel(random);
      final moves = randomMoves(random);
      final outcome = decode(encode(level, moves));
      expect(outcome, isA<DecodeSuccess>(),
          reason: 'trial $trial must roundtrip');
      final success = outcome as DecodeSuccess;
      expect(success.level.width, level.width);
      expect(success.level.height, level.height);
      expect(success.level.tiles, level.tiles);
      expect(success.level.playerIndex, level.playerIndex);
      expect(success.level.crateIndexes, level.crateIndexes);
      expect(success.solution, moves);
    }
  });

  test('FUZZ: random base64url strings never throw', () {
    final random = Random(7);
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    for (var trial = 0; trial < 2000; trial++) {
      final length = random.nextInt(200);
      final code = String.fromCharCodes([
        for (var i = 0; i < length; i++)
          alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ]);
      // Must return an outcome — an uncaught throw fails the test.
      expect(decode(code), isA<DecodeOutcome>());
    }
  });

  test('FUZZ: random sealed byte bodies never throw', () {
    final random = Random(13);
    for (var trial = 0; trial < 500; trial++) {
      final body = [
        for (var i = 0, n = random.nextInt(120); i < n; i++)
          random.nextInt(256),
      ];
      expect(decode(sealCode(body)), isA<DecodeOutcome>());
    }
  });

  test('FUZZ: every truncation of a valid code fails typed, never throws', () {
    final random = Random(99);
    final code = encode(randomValidLevel(random), randomMoves(random));
    for (var cut = 0; cut < code.length; cut++) {
      final outcome = decode(code.substring(0, cut));
      expect(outcome, isA<DecodeFailure>(),
          reason: 'prefix of length $cut must be rejected');
    }
  });

  test('FUZZ: every single-byte corruption is rejected (stale CRC)', () {
    final random = Random(41);
    final code = encode(randomValidLevel(random), randomMoves(random));
    final bytes = rawBytes(code);
    for (var i = 0; i < bytes.length; i++) {
      final copy = [...bytes];
      copy[i] = copy[i] ^ 0x55;
      final corrupted = sealCode(copy.sublist(0, copy.length - 4), crcDelta: 0);
      // Re-sealing recomputes the CRC over the corrupted body, so header
      // mutations surface as their own typed errors; direct stale-CRC
      // corruption (no re-seal) must be badChecksum:
      final stale = base64UrlNoPad(copy);
      expect(decode(corrupted), isA<DecodeOutcome>());
      expect(decode(stale), isA<DecodeFailure>(),
          reason: 'byte $i corrupted with stale CRC must fail');
    }
  });
}
