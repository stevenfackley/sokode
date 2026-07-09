import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/play/player_screen.dart';
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
  test('directionFromPanVelocity maps dominant axis with threshold', () {
    expect(directionFromPanVelocity(const Offset(300, 20)), Direction.right);
    expect(directionFromPanVelocity(const Offset(-300, 20)), Direction.left);
    expect(directionFromPanVelocity(const Offset(10, 300)), Direction.down);
    expect(directionFromPanVelocity(const Offset(10, -300)), Direction.up);
    expect(directionFromPanVelocity(const Offset(30, 30)), isNull);
  });

  testWidgets('arrow keys move the player; win dialog appears on solve', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PlayerScreen(level: _pushOnce())),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('win-dialog')), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets); // move count shown
  });

  testWidgets('undo button reverts a move', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PlayerScreen(level: _pushOnce())),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsWidgets); // move counter back to zero
  });
}
