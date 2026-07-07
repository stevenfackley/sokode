import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  GridState start(List<String> rows) => GridState.initial(levelFromAscii(rows));

  test('player enters a one-way only in its arrow direction', () {
    final state = start(['#####', '#@> #', '#####']);
    expect(rules.step(state, Direction.right), isA<Moved>());
  });

  test('player cannot enter a one-way against the arrow', () {
    final state = start(['#####', '# >@#', '#####']);
    expect(rules.step(state, Direction.left), isA<Blocked>());
  });

  test('exit is unconstrained (entry-only rule)', () {
    // Player walks right onto the one-way, then exits UP — legal, because
    // only entry is constrained.
    final level = levelFromAscii([
      '#####',
      '#   #',
      '#@> #',
      '#####',
    ]);
    final onOneway =
        (rules.step(GridState.initial(level), Direction.right) as Moved).state;
    expect(onOneway.playerIndex, 12); // on the '>' cell
    expect(rules.step(onOneway, Direction.up), isA<Moved>(),
        reason: 'exiting a one-way in any direction is legal');
  });

  test('crate entry obeys the same rule', () {
    final ok = start(['######', r'#@$> #', '######']);
    expect(rules.step(ok, Direction.right), isA<Moved>());
    final blocked = start(['######', r'#@$< #', '######']);
    expect(rules.step(blocked, Direction.right), isA<Blocked>());
  });
}
