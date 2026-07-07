import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const verifier = ReplayVerifier(Simulation(SokobanPlus()));

  Level pushTwice() => levelFromAscii([
        '######',
        r'#@$ .#',
        '#    #',
        '######',
      ]);

  test('a correct solution verifies', () {
    final result =
        verifier.verify(pushTwice(), const [Direction.right, Direction.right]);
    final success = result as VerifySuccess;
    expect(success.solvedAtMove, 2);
  });

  test('early win: trailing moves after the solve are ignored', () {
    final result = verifier.verify(
        pushTwice(), const [Direction.right, Direction.right, Direction.down]);
    expect((result as VerifySuccess).solvedAtMove, 2);
  });

  test('empty replay is rejected', () {
    expect(verifier.verify(pushTwice(), const []), isA<VerifyEmptyReplay>());
  });

  test('replay over the 4096 cap is rejected before simulation', () {
    final tooLong = List.filled(4097, Direction.up);
    expect(verifier.verify(pushTwice(), tooLong), isA<VerifyTooLong>());
  });

  test('an illegal move fails with its index (strict verification)', () {
    // Move 0: up into the wall — illegal.
    final result =
        verifier.verify(pushTwice(), const [Direction.up, Direction.right]);
    expect((result as VerifyIllegalMove).moveIndex, 0);
  });

  test('legal moves that do not solve are rejected', () {
    final result = verifier.verify(pushTwice(), const [Direction.down]);
    expect(result, isA<VerifyNotSolved>());
  });

  test('a pre-solved level verifies at move 0', () {
    final level = levelFromAscii([
      '#####',
      '#@* #',
      '#   #',
      '#####',
    ]);
    final result = verifier.verify(level, const [Direction.down]);
    expect((result as VerifySuccess).solvedAtMove, 0);
  });
}
