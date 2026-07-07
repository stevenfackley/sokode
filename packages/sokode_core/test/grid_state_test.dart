import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  test('initial state mirrors the level and opens the right gates', () {
    final level = levelFromAscii([
      '######',
      r'#@$[]#',
      '######',
    ]);
    final state = GridState.initial(level);
    expect(state.playerIndex, level.playerIndex);
    expect(state.crateIndexes, level.crateIndexes);
    expect(state.isGateOpenAt(9), isTrue); // '[' at row 1, col 3
    expect(state.isGateOpenAt(10), isFalse); // ']' at row 1, col 4
  });

  test('initial placement fires nothing: starting on a switch leaves gates',
      () {
    // Player starts ON switch A; gate A starts closed. Spec §2.3: initial
    // placement must NOT fire toggles.
    final ascii = levelFromAscii([
      '#####',
      '#@a]#',
      '#####',
    ]);
    final level = Level(
      width: ascii.width,
      height: ascii.height,
      tiles: ascii.tiles,
      playerIndex: 7, // the switch-A cell (row 1, col 2)
      crateIndexes: const [],
    );
    final state = GridState.initial(level);
    expect(state.isGateOpenAt(8), isFalse, reason: 'no toggle at setup');
  });

  test('value equality over player, crates, open gates', () {
    final level = levelFromAscii([
      '#####',
      r'#@$ #',
      '#####',
    ]);
    final a = GridState.initial(level);
    final b = GridState.initial(level);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    final moved = GridState(
      level: level,
      playerIndex: level.playerIndex + 1,
      crateIndexes: level.crateIndexes,
      openGateIndexes: const [],
    );
    expect(a == moved, isFalse);
  });

  test('occupancy queries', () {
    final level = levelFromAscii([
      '#####',
      r'#@$ #',
      '#####',
    ]);
    final state = GridState.initial(level);
    expect(state.hasCrateAt(7), isTrue);
    expect(state.hasCrateAt(8), isFalse);
    expect(state.isOccupied(6), isTrue); // player
    expect(state.isOccupied(7), isTrue); // crate
    expect(state.isOccupied(8), isFalse);
  });
}
