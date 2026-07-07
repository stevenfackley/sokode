import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  test('player stepping on a switch toggles its whole channel', () {
    // '#@a].#' — gate A closed at index 9; '[' would be open.
    final level = levelFromAscii(['######', '#@a].#', '######']);
    var state = GridState.initial(level);
    expect(state.isGateOpenAt(9), isFalse);
    state = (rules.step(state, Direction.right) as Moved).state; // onto 'a'
    expect(state.isGateOpenAt(9), isTrue, reason: 'toggle opened the gate');
    state = (rules.step(state, Direction.right) as Moved).state; // onto gate
    expect(state.playerIndex, 9);
  });

  test('toggle affects only its own channel', () {
    final level = levelFromAscii(['#######', '#@a]} #', '#######']);
    var state = GridState.initial(level);
    state = (rules.step(state, Direction.right) as Moved).state;
    expect(state.isGateOpenAt(10), isTrue, reason: 'channel A toggled');
    expect(state.isGateOpenAt(11), isFalse, reason: 'channel B untouched');
  });

  test('open gates close on toggle — unless occupied (spec §2.3)', () {
    // Crate parked ON an open gate A; a second gate A is open elsewhere.
    final base = levelFromAscii(['#######', '#@a[[ #', '#######']);
    final level = Level(
      width: base.width,
      height: base.height,
      tiles: base.tiles,
      playerIndex: base.playerIndex,
      crateIndexes: const [10], // crate on the first '[' (index 10)
    );
    var state = GridState.initial(level);
    expect(state.isGateOpenAt(10), isTrue);
    expect(state.isGateOpenAt(11), isTrue);
    state = (rules.step(state, Direction.right) as Moved).state; // onto 'a'
    expect(state.isGateOpenAt(10), isTrue,
        reason: 'occupied gate must NOT close');
    expect(state.isGateOpenAt(11), isFalse,
        reason: 'unoccupied gate closes normally');
  });

  test('crate arriving on a switch fires the toggle too', () {
    final level = levelFromAscii(['######', r'#@$a]#', '######']);
    var state = GridState.initial(level);
    state = (rules.step(state, Direction.right) as Moved).state;
    // Crate moved onto 'a' (index 9); gate at 10 must now be open.
    expect(state.crateIndexes, [9]);
    expect(state.isGateOpenAt(10), isTrue);
  });

  test('push where crate AND player both land on switches fires twice', () {
    // Row 1 (indexes 6..11): # _ a a ] #
    // Player on floor (7), crate starts ON the first switch (8) — setup
    // fires nothing. Push right: crate 8 -> 9 (switch A, fire #1 opens the
    // gate), player 7 -> 8 (switch A, fire #2 closes it again, unoccupied).
    // Net closed proves BOTH arrivals fired.
    final tiles = [
      Tile.wall, Tile.wall, Tile.wall, Tile.wall, Tile.wall, Tile.wall, //
      Tile.wall, Tile.floor, Tile.switchA, Tile.switchA, Tile.gateAClosed,
      Tile.wall, //
      Tile.wall, Tile.wall, Tile.wall, Tile.wall, Tile.wall, Tile.wall,
    ];
    final doubleFire = Level(
      width: 6,
      height: 3,
      tiles: tiles,
      playerIndex: 7,
      crateIndexes: const [8],
    );
    var state = GridState.initial(doubleFire);
    expect(state.isGateOpenAt(10), isFalse, reason: 'setup fires nothing');
    state = (rules.step(state, Direction.right) as Moved).state;
    expect(state.isGateOpenAt(10), isFalse,
        reason: 'two toggles = net closed; proves both arrivals fire');
  });
}
