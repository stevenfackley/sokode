import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/screens/level_list_screen.dart';
import 'package:sokode_app/store/level_repository.dart';
import 'package:sokode_core/sokode_core.dart';

Level _solvable() => Level(
  width: 5,
  height: 4,
  tiles: [
    ...List.filled(5, Tile.wall),
    Tile.wall,
    Tile.floor,
    Tile.floor,
    Tile.floor,
    Tile.target,
    ...List.filled(5, Tile.wall),
    ...List.filled(5, Tile.wall),
  ],
  playerIndex: 6,
  crateIndexes: const [7],
);

void main() {
  testWidgets('importing a genuine code adds it to Imported', (tester) async {
    final repo = MemoryLevelRepository();
    final code = encode(_solvable(), const [Direction.right, Direction.right]);
    await tester.pumpWidget(
      MaterialApp(home: LevelListScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('import-field')), code);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await repo.loadCodes()).single.kind, 'imported');
  });

  testWidgets('a forged code is rejected with human copy and NOT saved', (
    tester,
  ) async {
    final repo = MemoryLevelRepository();
    await tester.pumpWidget(
      MaterialApp(home: LevelListScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('import-field')),
      'not-a-real-code',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-error')), findsOneWidget);
    expect(await repo.loadCodes(), isEmpty);
  });
}
