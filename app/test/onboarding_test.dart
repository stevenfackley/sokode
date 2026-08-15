import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/screens/app_bootstrap.dart';
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
  testWidgets('a fresh install opens on the walkthrough', (tester) async {
    final repo = MemoryLevelRepository();
    await tester.pumpWidget(MaterialApp(home: AppBootstrap(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding')), findsOneWidget);
  });

  testWidgets('dismissing it records the flag and reveals the library', (
    tester,
  ) async {
    final repo = MemoryLevelRepository();
    await tester.pumpWidget(MaterialApp(home: AppBootstrap(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding')), findsNothing);
    expect(find.byType(LevelListScreen), findsOneWidget);
    expect(await repo.loadFlags(), contains(onboardingSeenFlag));
  });

  testWidgets('a returning player never sees it again', (tester) async {
    final repo = MemoryLevelRepository();
    await repo.setFlag(onboardingSeenFlag);
    await tester.pumpWidget(MaterialApp(home: AppBootstrap(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding')), findsNothing);
    expect(find.byType(LevelListScreen), findsOneWidget);
  });

  testWidgets('a web-fragment code still imports after the walkthrough', (
    tester,
  ) async {
    final repo = MemoryLevelRepository();
    final code = encode(_solvable(), const [Direction.right, Direction.right]);
    await tester.pumpWidget(
      MaterialApp(
        home: AppBootstrap(repository: repo, initialImportCode: code),
      ),
    );
    await tester.pumpAndSettle();
    expect(await repo.loadCodes(), isEmpty, reason: 'still onboarding');
    await tester.tap(find.byKey(const ValueKey('onboarding-done')));
    await tester.pumpAndSettle();
    expect((await repo.loadCodes()).single.kind, 'imported');
  });

  testWidgets('the library can reopen the walkthrough on demand', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LevelListScreen(repository: MemoryLevelRepository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('how-to-play-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-done')));
    await tester.pumpAndSettle();
    expect(find.byType(LevelListScreen), findsOneWidget);
  });
}
