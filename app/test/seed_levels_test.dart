import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/content/seed_levels.dart';
import 'package:sokode_app/content/seed_library.dart';
import 'package:sokode_core/sokode_core.dart';

/// The shipped content's acceptance test. Seeds are generated offline by
/// `packages/sokode_core/tool/generate_seed_levels.dart`, so this is where a
/// bad regeneration — a truncated code, an unsolvable board, a level whose
/// proof no longer replays after a rules change — gets caught.
void main() {
  const importer = LevelImporter(SokobanPlus());

  test('ships enough sample levels to fill a fresh install (spec phase 6)', () {
    expect(seedLevels.length, greaterThanOrEqualTo(20));
    expect(seedLevels.length, lessThanOrEqualTo(30));
  });

  test('every seed passes the full import gate', () {
    for (final seed in seedLevels) {
      expect(
        importer.import(seed.code),
        isA<ImportSuccess>(),
        reason: '${seed.pack}: ${seed.code}',
      );
    }
  });

  test('embedded proof matches the recorded par', () {
    for (final seed in seedLevels) {
      final outcome = importer.import(seed.code) as ImportSuccess;
      expect(
        outcome.solution,
        hasLength(seed.parMoves),
        reason: '${seed.pack}: ${seed.code}',
      );
    }
  });

  test('codes are canonical — re-encoding is a fixed point', () {
    for (final seed in seedLevels) {
      final outcome = importer.import(seed.code) as ImportSuccess;
      expect(
        encode(outcome.level, outcome.solution),
        seed.code,
        reason: 'seed code is not the canonical encoding of its own level',
      );
    }
  });

  test('no duplicate levels', () {
    expect(seedLevels.map((s) => s.code).toSet(), hasLength(seedLevels.length));
  });

  test('derived titles are unique, so the list never reads as duplicated', () {
    final titles = loadSeedLibrary().map((e) => e.title).toList();
    expect(titles.toSet(), hasLength(titles.length));
  });

  test('every declared pack exists and every seed belongs to one', () {
    expect(seedPacks, isNotEmpty);
    for (final pack in seedPacks) {
      expect(
        seedLevels.where((s) => s.pack == pack),
        isNotEmpty,
        reason: 'empty pack "$pack"',
      );
    }
    for (final seed in seedLevels) {
      expect(seedPacks, contains(seed.pack));
    }
  });

  test('seeds are grouped: a pack never reappears after it ends', () {
    final seen = <String>[];
    String? current;
    for (final seed in seedLevels) {
      if (seed.pack == current) continue;
      expect(seen, isNot(contains(seed.pack)), reason: 'split ${seed.pack}');
      seen.add(seed.pack);
      current = seed.pack;
    }
  });

  test('loadSeedLibrary yields playable, gate-checked entries', () {
    final library = loadSeedLibrary();
    expect(library, hasLength(seedLevels.length));
    for (final entry in library) {
      expect(entry.title.split(' '), hasLength(2));
      expect(entry.parMoves, greaterThan(0));
      expect(
        const SokobanPlus().validateStructure(entry.level).isValid,
        isTrue,
      );
    }
  });

  test('a corrupted seed is dropped, not played', () {
    // Seeds earn no special trust: the runtime gate is the same one a
    // stranger's pasted code meets.
    final library = loadSeedLibrary(
      levels: const [
        SeedLevel(pack: 'Broken', code: 'not-a-real-code', parMoves: 1),
      ],
    );
    expect(library, isEmpty);
  });
}
