import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  GridState start(List<String> rows) => GridState.initial(levelFromAscii(rows));

  test('moves into empty floor', () {
    final state = start(['#####', '#@  #', '#####']);
    final result = rules.step(state, Direction.right);
    expect(result, isA<Moved>());
    expect((result as Moved).state.playerIndex, 7);
  });

  test('blocked by walls', () {
    final state = start(['#####', '#@  #', '#####']);
    expect(rules.step(state, Direction.left), isA<Blocked>());
    expect(rules.step(state, Direction.up), isA<Blocked>());
    expect(rules.step(state, Direction.down), isA<Blocked>());
  });

  test('blocked by the board edge (no wrap-around)', () {
    // Player on an open edge — 3x1 strip, no surrounding walls.
    final level = Level(
      width: 3,
      height: 1,
      tiles: List.filled(3, Tile.floor),
      playerIndex: 0,
      crateIndexes: const [],
    );
    final state = GridState.initial(level);
    expect(rules.step(state, Direction.left), isA<Blocked>());
    expect(rules.step(state, Direction.up), isA<Blocked>());
    final right = rules.step(state, Direction.right);
    expect((right as Moved).state.playerIndex, 1);
  });

  test('blocked by a closed gate; walks through an open one', () {
    final closed = start(['#####', '#@] #', '#####']);
    expect(rules.step(closed, Direction.right), isA<Blocked>());
    final open = start(['#####', '#@[ #', '#####']);
    expect(rules.step(open, Direction.right), isA<Moved>());
  });

  test('a Blocked step leaves no trace (input state unchanged)', () {
    final state = start(['#####', '#@  #', '#####']);
    final before =
        GridState.initial(levelFromAscii(['#####', '#@  #', '#####']));
    rules.step(state, Direction.left);
    expect(state, before);
  });
}
