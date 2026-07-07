import 'dart:math';

import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/random_level.dart';

void main() {
  const rules = SokobanPlus();

  void checkInvariants(Level level, GridState state) {
    expect(state.crateIndexes.length, level.crateIndexes.length,
        reason: 'crate count conserved');
    expect(state.crateIndexes.toSet().length, state.crateIndexes.length,
        reason: 'no two crates share a cell');
    for (final e in [state.playerIndex, ...state.crateIndexes]) {
      expect(e, inInclusiveRange(0, level.cellCount - 1),
          reason: 'entities stay on the board');
      expect(level.tiles[e], isNot(Tile.wall),
          reason: 'entities never stand on walls');
      if (level.tiles[e].isGate) {
        expect(state.isGateOpenAt(e), isTrue,
            reason: 'entities never stand on a CLOSED gate — this is the '
                'invariant the occupied-gate rule exists to protect');
      }
    }
    expect(state.crateIndexes, isNot(contains(state.playerIndex)),
        reason: 'player and crate never overlap');
  }

  test('invariants hold across 200 random levels x 100 random moves', () {
    final random = Random(42); // fixed seed: failures are reproducible
    for (var trial = 0; trial < 200; trial++) {
      final level = randomLevel(random);
      var state = GridState.initial(level);
      checkInvariants(level, state);
      for (var move = 0; move < 100; move++) {
        final dir = Direction.values[random.nextInt(4)];
        final result = rules.step(state, dir);
        if (result is Moved) state = result.state;
        checkInvariants(level, state);
      }
    }
  });

  test('legalActions agrees with step outcomes on random states', () {
    final random = Random(7);
    for (var trial = 0; trial < 50; trial++) {
      final level = randomLevel(random);
      var state = GridState.initial(level);
      for (var move = 0; move < 30; move++) {
        final legal = rules.legalActions(state);
        for (final d in Direction.values) {
          expect(legal.contains(d), rules.step(state, d) is Moved,
              reason: 'legalActions must mirror step for $d');
        }
        if (legal.isEmpty) break;
        state =
            (rules.step(state, legal[random.nextInt(legal.length)]) as Moved)
                .state;
      }
    }
  });
}
