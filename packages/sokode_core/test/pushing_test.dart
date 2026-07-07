import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  GridState start(List<String> rows) => GridState.initial(levelFromAscii(rows));

  test('pushes a crate into empty floor', () {
    final state = start(['######', r'#@$ .#', '######']);
    final result = rules.step(state, Direction.right) as Moved;
    expect(result.state.playerIndex, 8);
    expect(result.state.crateIndexes, [9]);
  });

  test('pushes a crate onto a target', () {
    final state = start(['#####', r'#@$.#', '#####']);
    final result = rules.step(state, Direction.right) as Moved;
    expect(result.state.crateIndexes, [8]);
  });

  test('cannot push a crate into a wall', () {
    final state = start(['#####', r'#@$##', '#####']);
    expect(rules.step(state, Direction.right), isA<Blocked>());
  });

  test('cannot push a crate into another crate', () {
    final state = start(['######', r'#@$$ #', '######']);
    expect(rules.step(state, Direction.right), isA<Blocked>());
  });

  test('cannot push a crate off the board', () {
    final level = Level(
      width: 3,
      height: 1,
      tiles: List.filled(3, Tile.floor),
      playerIndex: 1,
      crateIndexes: const [2],
    );
    expect(
        rules.step(GridState.initial(level), Direction.right), isA<Blocked>());
  });

  test('cannot push a crate into a closed gate; can into an open one', () {
    final closed = start(['######', r'#@$] #', '######']);
    expect(rules.step(closed, Direction.right), isA<Blocked>());
    final open = start(['######', r'#@$[ #', '######']);
    final result = rules.step(open, Direction.right) as Moved;
    expect(result.state.crateIndexes, [9]);
  });
}
