import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  final level = levelFromAscii([
    '########',
    r'#@$ a] #',
    '#  .   #',
    '########',
  ]);
  const moves = [
    Direction.right, // push crate right
    Direction.right, // walk onto vacated... (crate at idx 11, player 10)
    Direction.down, // reposition
    Direction.right,
    Direction.up, // step onto switch 'a' (12) — gate 13 opens
  ];

  int runReplay() {
    const sim = Simulation(SokobanPlus());
    var state = sim.initialState(level);
    for (final m in moves) {
      final result = sim.apply(state, m);
      state = switch (result) {
        Moved(:final state) => state,
        Blocked() => state, // illegal moves in a replay leave state as-is
      };
    }
    return stateDigest(state);
  }

  test('same replay twice yields the identical digest', () {
    expect(runReplay(), runReplay());
  });

  test('GOLDEN: digest is pinned across refactors and platforms', () {
    // GOLDEN-PIN PROCEDURE: on first run this literal is -1 and the test
    // FAILS, printing the actual digest. Copy that number here, rerun,
    // commit. Any future change to this number is a determinism break —
    // treat as a bug, never re-pin without understanding why.
    final actual = runReplay();
    printOnFailure('actual digest: $actual');
    expect(actual, 7133549);
  });
}
