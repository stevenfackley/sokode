import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/render/board_view.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  testWidgets('renders player and crates at their state positions', (
    tester,
  ) async {
    final level = Level(
      width: 4,
      height: 4,
      tiles: List.filled(16, Tile.floor),
      playerIndex: 5,
      crateIndexes: const [6, 9],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: BoardView(level: level, state: GridState.initial(level)),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('player')), findsOneWidget);
    expect(find.byKey(const ValueKey('crate-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('crate-1')), findsOneWidget);
  });

  testWidgets('player widget moves when state changes', (tester) async {
    final level = Level(
      width: 4,
      height: 1,
      tiles: List.filled(4, Tile.floor),
      playerIndex: 0,
      crateIndexes: const [],
    );
    final initial = GridState.initial(level);
    final moved = GridState(
      level: level,
      playerIndex: 1,
      crateIndexes: const [],
      openGateIndexes: const [],
    );
    Widget build(GridState s) => MaterialApp(
      home: SizedBox(
        width: 400,
        height: 100,
        child: BoardView(level: level, state: s),
      ),
    );
    await tester.pumpWidget(build(initial));
    final before = tester.getTopLeft(find.byKey(const ValueKey('player')));
    await tester.pumpWidget(build(moved));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.byKey(const ValueKey('player')));
    expect(after.dx, greaterThan(before.dx));
  });
}
