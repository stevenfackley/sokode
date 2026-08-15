import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/content/seed_library.dart';
import 'package:sokode_app/screens/level_list_screen.dart';
import 'package:sokode_app/store/level_repository.dart';
import 'package:sokode_core/sokode_core.dart';

Level _oneMove() => Level(
  width: 5,
  height: 4,
  tiles: [
    ...List.filled(5, Tile.wall),
    Tile.wall,
    Tile.floor,
    Tile.floor,
    Tile.target,
    Tile.wall,
    ...List.filled(5, Tile.wall),
    ...List.filled(5, Tile.wall),
  ],
  playerIndex: 6,
  crateIndexes: const [7],
);

List<SeedEntry> _fakeSeeds() {
  final level = _oneMove();
  return [
    SeedEntry(
      pack: 'Warm Up',
      code: encode(level, const [Direction.right]),
      level: level,
      title: titleForLevel(level),
      parMoves: 1,
    ),
  ];
}

void main() {
  testWidgets('samples open on the first tab of a fresh library', (
    tester,
  ) async {
    final seeds = _fakeSeeds();
    await tester.pumpWidget(
      MaterialApp(
        home: LevelListScreen(
          repository: MemoryLevelRepository(),
          seeds: seeds,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Warm Up'), findsOneWidget, reason: 'pack heading');
    expect(find.text('1. ${seeds.single.title}'), findsOneWidget);
    expect(find.text('Par 1'), findsOneWidget);
  });

  testWidgets('a sample plays to a win without being imported first', (
    tester,
  ) async {
    final repo = MemoryLevelRepository();
    final seeds = _fakeSeeds();
    await tester.pumpWidget(
      MaterialApp(
        home: LevelListScreen(repository: repo, seeds: seeds),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('seed-${seeds.single.code}')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('win-dialog')), findsOneWidget);
    expect(
      await repo.loadCodes(),
      isEmpty,
      reason: 'shipped content is not user library content',
    );
  });

  testWidgets('an empty catalog degrades to a message, not a crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LevelListScreen(
          repository: MemoryLevelRepository(),
          seeds: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No sample levels in this build.'), findsOneWidget);
  });
}
