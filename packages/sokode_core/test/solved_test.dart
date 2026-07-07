import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  test('solved when every target is covered by a crate', () {
    final level = levelFromAscii(['#####', r'#@$.#', '#####']);
    var state = GridState.initial(level);
    expect(rules.isSolved(state), isFalse);
    state = (rules.step(state, Direction.right) as Moved).state;
    expect(rules.isSolved(state), isTrue);
  });

  test('player standing on a target does not count as coverage', () {
    final level = levelFromAscii(['#####', '#+  #', '#####']);
    expect(rules.isSolved(GridState.initial(level)), isFalse);
  });

  test('extra crates beyond target count are fine', () {
    final level = levelFromAscii(['######', r'#@*$ #', '######']);
    // The single target (under the '*') is covered from the start.
    expect(rules.isSolved(GridState.initial(level)), isTrue);
  });

  test('legalActions lists exactly the non-Blocked directions', () {
    final level = levelFromAscii([
      '####',
      '#@ #',
      '#  #',
      '####',
    ]);
    final actions = rules.legalActions(GridState.initial(level));
    expect(actions, unorderedEquals([Direction.right, Direction.down]));
  });
}
