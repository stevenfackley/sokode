/// Content build step: solve every level in `seed_catalog.dart` and emit the
/// resulting proof-carrying share codes as a generated Dart file for the app.
///
/// Run from `packages/sokode_core`:
///
/// ```
/// dart run tool/generate_seed_levels.dart
/// dart format ../../app/lib/content/seed_levels.dart
/// ```
///
/// Why generate codes instead of shipping `Level` objects: a sample level and
/// a stranger's pasted level must be the SAME kind of thing. Seeds go through
/// `LevelImporter` like everything else, so the shipped content is covered by
/// the decode -> validate -> verify gate rather than trusted by construction.
/// `app/test/seed_levels_test.dart` re-runs that gate on every code in CI.
///
/// The solver is a plain breadth-first search over `GridState` driven by the
/// production `Simulation` — it can only find solutions the real game accepts,
/// and being breadth-first the embedded proof is a shortest solution.
library;

import 'dart:collection';
import 'dart:io';

import 'package:sokode_core/sokode_core.dart';

// The ASCII legend has exactly one definition; the core's test helper owns
// it. This tool is dev-only content tooling, so reaching into test/ beats a
// second parser that could silently drift from the first.
import '../test/helpers/ascii_level.dart';
import 'seed_catalog.dart';

const _rules = SokobanPlus();
const _simulation = Simulation(_rules);

/// Hard ceiling on explored states. Sized so an unsolvable authored level
/// fails in seconds instead of eating the machine; every shipped level in the
/// catalog settles far below it.
const int _maxStates = 1200000;

void main(List<String> args) {
  final outputPath =
      args.isNotEmpty ? args.first : '../../app/lib/content/seed_levels.dart';

  final entries = <_SeedEntry>[];
  var failed = 0;

  for (var i = 0; i < seedCatalog.length; i++) {
    final spec = seedCatalog[i];
    final Level level;
    try {
      level = levelFromAscii(spec.rows);
    } on ArgumentError catch (error) {
      stderr.writeln('[${i + 1}] ${spec.pack}: unparseable — $error');
      failed++;
      continue;
    }

    final validation = _rules.validateStructure(level);
    if (!validation.isValid) {
      stderr.writeln('[${i + 1}] ${spec.pack}: invalid — ${validation.errors}');
      failed++;
      continue;
    }

    final solution = _solve(level);
    if (solution == null) {
      stderr.writeln('[${i + 1}] ${spec.pack}: NO SOLUTION found');
      failed++;
      continue;
    }

    final code = encode(level, solution);
    // Prove the shipped artifact, not the in-memory one: what the app will
    // actually receive is this string, so gate this string.
    final outcome = const LevelImporter(_rules).import(code);
    if (outcome is! ImportSuccess) {
      stderr.writeln('[${i + 1}] ${spec.pack}: code failed the import gate');
      failed++;
      continue;
    }

    entries.add(
      _SeedEntry(
        pack: spec.pack,
        code: code,
        parMoves: solution.length,
        title: titleForLevel(level),
      ),
    );
    stdout.writeln(
      '[${i + 1}] ${spec.pack}: ${solution.length} moves, '
      '${code.length} chars — "${titleForLevel(level)}"',
    );
  }

  if (failed > 0) {
    stderr.writeln('$failed level(s) rejected; nothing written.');
    exit(1);
  }

  final duplicateCodes =
      entries.length - entries.map((e) => e.code).toSet().length;
  if (duplicateCodes > 0) {
    stderr.writeln('$duplicateCodes duplicate level(s) in the catalog.');
    exit(1);
  }

  // Titles are derived, so two catalog entries can land on the same word
  // pair (1024 combinations). Shipped content should not read as duplicated:
  // nudge a wall in the losing level and regenerate.
  final byTitle = <String, List<String>>{};
  for (final entry in entries) {
    byTitle.putIfAbsent(entry.title, () => <String>[]).add(entry.pack);
  }
  final collisions = byTitle.entries.where((e) => e.value.length > 1);
  if (collisions.isNotEmpty) {
    for (final collision in collisions) {
      stderr.writeln(
        'title collision "${collision.key}" in ${collision.value}',
      );
    }
    exit(1);
  }

  File(outputPath).writeAsStringSync(_render(entries));
  stdout.writeln('Wrote ${entries.length} levels to $outputPath');
}

class _SeedEntry {
  const _SeedEntry({
    required this.pack,
    required this.code,
    required this.parMoves,
    required this.title,
  });

  final String pack;
  final String code;
  final int parMoves;

  /// Only used to annotate the generated file — the app derives titles at
  /// runtime so the word lists stay the single source of truth.
  final String title;
}

/// Shortest solution for [level], or null if none exists within [_maxStates].
///
/// Breadth-first over distinct `GridState`s (whose equality is exactly
/// player + crates + open gates, which is the whole of the mutable state).
/// Parent pointers rather than per-node paths keep memory linear in states.
List<Direction>? _solve(Level level) {
  final start = GridState.initial(level);
  if (_rules.isSolved(start)) return null; // v1 codes need >= 1 move.

  final states = <GridState>[start];
  final parents = <int>[-1];
  final actions = <Direction>[Direction.up]; // slot 0 is never read
  final seen = HashSet<GridState>()..add(start);

  for (var head = 0; head < states.length; head++) {
    if (states.length > _maxStates) return null;
    final state = states[head];
    for (final direction in Direction.values) {
      final result = _simulation.apply(state, direction);
      if (result is! Moved) continue;
      final next = result.state;
      if (!seen.add(next)) continue;
      states.add(next);
      parents.add(head);
      actions.add(direction);
      if (_rules.isSolved(next)) {
        final path = <Direction>[];
        for (var at = states.length - 1; at > 0; at = parents[at]) {
          path.add(actions[at]);
        }
        return path.reversed.toList();
      }
    }
  }
  return null;
}

String _render(List<_SeedEntry> entries) {
  final packs = <String>[];
  for (final entry in entries) {
    if (!packs.contains(entry.pack)) packs.add(entry.pack);
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit by hand.')
    ..writeln('//')
    ..writeln('// Source:     packages/sokode_core/tool/seed_catalog.dart')
    ..writeln('// Regenerate: dart run tool/generate_seed_levels.dart')
    ..writeln('//             (from packages/sokode_core, then dart format)')
    ..writeln()
    ..writeln('/// One shipped sample level.')
    ..writeln('///')
    ..writeln('/// [code] is an ordinary share code — the same kind a player')
    ..writeln('/// pastes in — so samples carry their own solution proof and')
    ..writeln('/// earn no special trust from the import gate.')
    ..writeln('class SeedLevel {')
    ..writeln('  const SeedLevel({')
    ..writeln('    required this.pack,')
    ..writeln('    required this.code,')
    ..writeln('    required this.parMoves,')
    ..writeln('  });')
    ..writeln()
    ..writeln('  /// Display grouping; see [seedPacks] for display order.')
    ..writeln('  final String pack;')
    ..writeln()
    ..writeln('  /// Proof-carrying share code.')
    ..writeln('  final String code;')
    ..writeln()
    ..writeln('  /// Length of the shortest solution known at generation')
    ..writeln('  /// time — the embedded proof. Shown as "par".')
    ..writeln('  final int parMoves;')
    ..writeln('}')
    ..writeln()
    ..writeln('/// Pack display order.')
    ..writeln('const List<String> seedPacks = <String>[');
  for (final pack in packs) {
    buffer.writeln("  '$pack',");
  }
  buffer
    ..writeln('];')
    ..writeln()
    ..writeln('/// The shipped sample levels, in difficulty order per pack.')
    ..writeln('const List<SeedLevel> seedLevels = <SeedLevel>[');
  for (final entry in entries) {
    buffer
      ..writeln('  // ${entry.title}')
      ..writeln('  SeedLevel(')
      ..writeln("    pack: '${entry.pack}',")
      ..writeln("    code: '${entry.code}',")
      ..writeln('    parMoves: ${entry.parMoves},')
      ..writeln('  ),');
  }
  buffer.writeln('];');
  return buffer.toString();
}
