import 'package:sokode_core/sokode_core.dart';

import 'seed_levels.dart';

/// A sample level that has passed the import gate and is ready to play.
class SeedEntry {
  const SeedEntry({
    required this.pack,
    required this.code,
    required this.level,
    required this.title,
    required this.parMoves,
  });

  final String pack;
  final String code;
  final Level level;

  /// Derived from the level, never authored (spec §5: no free text).
  final String title;

  /// Shortest known solution length, shown as par.
  final int parMoves;
}

/// Decodes the shipped sample codes through the ordinary [LevelImporter].
///
/// Samples are share codes, so they get exactly the trust any pasted code
/// gets: a seed whose proof failed to verify is dropped, not played. That
/// costs one replay per level at startup (23 levels, tens of steps each) and
/// buys a single code path — there is no "trusted content" branch that could
/// drift from the one players' codes travel.
List<SeedEntry> loadSeedLibrary({
  LevelImporter importer = const LevelImporter(SokobanPlus()),
  List<SeedLevel> levels = seedLevels,
}) {
  final entries = <SeedEntry>[];
  for (final seed in levels) {
    final outcome = importer.import(seed.code);
    if (outcome is! ImportSuccess) continue;
    entries.add(
      SeedEntry(
        pack: seed.pack,
        code: seed.code,
        level: outcome.level,
        title: titleForLevel(outcome.level),
        parMoves: seed.parMoves,
      ),
    );
  }
  return entries;
}
