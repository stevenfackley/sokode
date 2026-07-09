import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/play/player_session.dart';
import 'package:sokode_core/sokode_core.dart';

Level _pushOnce() => Level(
  width: 5,
  height: 3,
  tiles: [
    ...List.filled(5, Tile.wall),
    Tile.wall,
    Tile.floor,
    Tile.floor,
    Tile.floor,
    Tile.target,
    ...List.filled(5, Tile.wall),
  ],
  playerIndex: 6,
  crateIndexes: const [7],
);

void main() {
  test('legal move advances state and records the move', () {
    final session = PlayerSession(_pushOnce());
    expect(session.tryMove(Direction.right), isTrue);
    expect(session.moveCount, 1);
    expect(session.moves, [Direction.right]);
    expect(session.state.playerIndex, 7);
  });

  test('blocked move records nothing', () {
    final session = PlayerSession(_pushOnce());
    expect(session.tryMove(Direction.up), isFalse);
    expect(session.moveCount, 0);
  });

  test('undo pops both state and move (undo is NOT in the replay)', () {
    final session = PlayerSession(_pushOnce())..tryMove(Direction.right);
    session.undo();
    expect(session.moveCount, 0);
    expect(session.state.playerIndex, 6);
    session.undo(); // no-op at initial state
    expect(session.state.playerIndex, 6);
  });

  test('reset returns to initial and clears the recording', () {
    final session = PlayerSession(_pushOnce())..tryMove(Direction.right);
    session.reset();
    expect(session.moveCount, 0);
    expect(session.state, GridState.initial(_pushOnce()));
  });

  test('win: crate onto target sets isSolved; further moves are ignored', () {
    final session = PlayerSession(_pushOnce())
      ..tryMove(Direction.right)
      ..tryMove(Direction.right);
    expect(session.isSolved, isTrue);
    expect(
      session.tryMove(Direction.left),
      isFalse,
      reason: 'input after win must not corrupt the recorded solution',
    );
    expect(session.moves, [Direction.right, Direction.right]);
  });

  test('notifies listeners on move, undo, reset', () {
    final session = PlayerSession(_pushOnce());
    var notifications = 0;
    session.addListener(() => notifications++);
    session
      ..tryMove(Direction.right)
      ..undo()
      ..reset();
    expect(notifications, 3);
  });
}
