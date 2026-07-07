# Sokode Plan 01 — Core Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `packages/sokode_core` — the pure, deterministic Sokoban+ engine (spec phases 0–1) — with CI, on GitHub.

**Architecture:** Pure Dart package, zero Flutter imports (CI-enforced). Immutable `GridState`; a 4-method `RuleSet` interface with `SokobanPlus` as the only implementer; thin `Simulation` wrapper. All semantics pinned in spec §2.3 get a dedicated test.

**Tech Stack:** Dart 3 (stable), `package:test`, `package:lints`, GitHub Actions. No property-testing library — hand-rolled seeded-random walks (deterministic, zero deps; trade-off: less shrinking power, no dependency risk).

**Spec:** `docs/superpowers/specs/2026-07-06-sokode-v1-design.md` — read §2 before starting.

**Conventions for every task:** work on branch `feat/01-core-engine`; run commands from `packages/sokode_core/` unless stated; commit messages are Conventional Commits with **no AI attribution trailers**.

**One spec addendum this plan introduces (record it in ARCHITECTURE.md, Task 14):** when a push makes both the crate and the player arrive on switches in the same step, the **crate's toggle resolves before the player's** (both evaluated against post-move positions). The spec pinned toggle behavior but not this ordering; it must be deterministic.

---

## File Structure

```
sokode/
  .github/workflows/ci.yml            # analyze + format + test (Task 1)
  packages/sokode_core/
    pubspec.yaml                      # pure Dart — no flutter dependency ever
    analysis_options.yaml             # strict-casts/inference/raw-types
    lib/sokode_core.dart              # exports only
    lib/src/direction.dart            # Direction enum + 2-bit encoding
    lib/src/tile.dart                 # 13-entry Tile palette + nibble codec
    lib/src/level.dart                # immutable authored level
    lib/src/grid_state.dart           # immutable runtime state
    lib/src/step_result.dart          # sealed Moved/Blocked
    lib/src/ruleset.dart              # RuleSet interface
    lib/src/validation.dart           # ValidationError + ValidationResult
    lib/src/sokoban_plus.dart         # the v1 ruleset
    lib/src/simulation.dart           # Simulation wrapper
    lib/src/state_digest.dart         # cross-platform deterministic fingerprint
    test/helpers/ascii_level.dart     # ASCII map -> Level (test-only)
    test/helpers/random_level.dart    # seeded generator (test-only)
    test/*.dart                       # one test file per module
  ARCHITECTURE.md                     # Task 14
```

---

### Task 1: Repo, package scaffold, CI

**Files:**
- Create: `packages/sokode_core/pubspec.yaml`, `packages/sokode_core/analysis_options.yaml`, `packages/sokode_core/lib/sokode_core.dart`, `packages/sokode_core/test/smoke_test.dart`, `.github/workflows/ci.yml`, `README.md`, `.gitignore`

- [ ] **Step 1: Create the GitHub repo and working branch**

From `C:\Users\steve\projects\sokode` (branch `docs/design-spec` already has spec + plans committed):

```bash
gh repo create stevenfackley/sokode --private --source . --push
git switch -c feat/01-core-engine
```

Expected: repo exists, `docs/design-spec` pushed, now on `feat/01-core-engine`. (Visibility can be flipped later with `gh repo edit stevenfackley/sokode --visibility public --accept-visibility-change-consequences`.)

- [ ] **Step 2: Write the scaffold files**

`.gitignore` (repo root):

```gitignore
.dart_tool/
build/
pubspec.lock
```

`README.md` (repo root):

```markdown
# Sokode

Deterministic Sokoban+ maker/player. Levels travel as self-verifying share codes. No server.

Spec: `docs/superpowers/specs/2026-07-06-sokode-v1-design.md`

## Core package

```sh
cd packages/sokode_core
dart pub get
dart analyze --fatal-infos
dart test
```
```

`packages/sokode_core/pubspec.yaml`:

```yaml
name: sokode_core
description: Pure deterministic core for Sokode (grid state, rules, simulation).
version: 0.1.0
publish_to: none
environment:
  sdk: ^3.5.0
dev_dependencies:
  lints: ^5.0.0
  test: ^1.25.0
```

`packages/sokode_core/analysis_options.yaml`:

```yaml
include: package:lints/recommended.yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

`packages/sokode_core/lib/sokode_core.dart`:

```dart
/// Pure, deterministic core for Sokode. No Flutter imports allowed —
/// enforced by test/import_boundary_test.dart.
library;
```

`packages/sokode_core/test/smoke_test.dart`:

```dart
import 'package:test/test.dart';

void main() {
  test('harness runs', () {
    expect(1 + 1, 2);
  });
}
```

- [ ] **Step 3: Verify the package builds and tests pass**

```bash
cd packages/sokode_core
dart pub get
dart analyze --fatal-infos
dart test
```

Expected: analyze clean, `+1: All tests passed!`

- [ ] **Step 4: Write CI**

`.github/workflows/ci.yml`:

```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:
jobs:
  core:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: packages/sokode_core
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      - run: dart pub get
      - run: dart format --output=none --set-exit-if-changed .
      - run: dart analyze --fatal-infos
      - run: dart test
```

- [ ] **Step 5: Format, commit, push, verify CI**

```bash
cd packages/sokode_core && dart format . && cd ../..
git add -A
git commit -m "chore: scaffold sokode_core package and CI"
git push -u origin feat/01-core-engine
gh run watch --repo stevenfackley/sokode --exit-status
```

Expected: CI run for the branch's PR trigger appears once a PR exists; if `gh run watch` finds no run yet, open the PR at the end of the plan — for now `dart test` passing locally is the gate.

---

### Task 2: Direction

**Files:**
- Create: `packages/sokode_core/lib/src/direction.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/direction_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

void main() {
  test('2-bit encodings are stable (codec + replay format depend on them)', () {
    expect(Direction.up.encoding, 0);
    expect(Direction.right.encoding, 1);
    expect(Direction.down.encoding, 2);
    expect(Direction.left.encoding, 3);
  });

  test('fromEncoding roundtrips', () {
    for (final d in Direction.values) {
      expect(Direction.fromEncoding(d.encoding), d);
    }
  });

  test('deltas point the right way (y grows downward, row-major)', () {
    expect(Direction.up.dx, 0);
    expect(Direction.up.dy, -1);
    expect(Direction.right.dx, 1);
    expect(Direction.right.dy, 0);
    expect(Direction.down.dx, 0);
    expect(Direction.down.dy, 1);
    expect(Direction.left.dx, -1);
    expect(Direction.left.dy, 0);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/direction_test.dart` → FAIL (Direction undefined).

- [ ] **Step 3: Implement**

`lib/src/direction.dart`:

```dart
/// A cardinal movement action. The `encoding` values are the 2-bit replay
/// alphabet used by the share-code format (ENCODING.md) — never renumber.
enum Direction {
  up(0, 0, -1),
  right(1, 1, 0),
  down(2, 0, 1),
  left(3, -1, 0);

  const Direction(this.encoding, this.dx, this.dy);

  /// 2-bit wire value. Invariant: equals this enum's declaration index.
  final int encoding;

  /// Column delta (+1 = right).
  final int dx;

  /// Row delta (+1 = down; grids are row-major, y grows downward).
  final int dy;

  /// Decodes a 2-bit value. Total: masks to 2 bits, cannot throw.
  static Direction fromEncoding(int bits) => Direction.values[bits & 3];
}
```

Append to `lib/sokode_core.dart`:

```dart
export 'src/direction.dart';
```

- [ ] **Step 4: Run to verify it passes** — `dart test test/direction_test.dart` → PASS.

- [ ] **Step 5: Commit**

```bash
dart format . && git add -A && git commit -m "feat: add Direction with stable 2-bit encoding"
```

---

### Task 3: Tile palette

**Files:**
- Create: `packages/sokode_core/lib/src/tile.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/tile_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

void main() {
  test('nibble values are stable (share-code format depends on them)', () {
    expect(Tile.floor.nibble, 0);
    expect(Tile.wall.nibble, 1);
    expect(Tile.target.nibble, 2);
    expect(Tile.onewayUp.nibble, 3);
    expect(Tile.onewayRight.nibble, 4);
    expect(Tile.onewayDown.nibble, 5);
    expect(Tile.onewayLeft.nibble, 6);
    expect(Tile.switchA.nibble, 7);
    expect(Tile.switchB.nibble, 8);
    expect(Tile.gateAOpen.nibble, 9);
    expect(Tile.gateAClosed.nibble, 10);
    expect(Tile.gateBOpen.nibble, 11);
    expect(Tile.gateBClosed.nibble, 12);
    expect(Tile.values.length, 13);
  });

  test('fromNibble roundtrips and rejects reserved values', () {
    for (final t in Tile.values) {
      expect(Tile.fromNibble(t.nibble), t);
    }
    expect(Tile.fromNibble(13), isNull);
    expect(Tile.fromNibble(15), isNull);
    expect(Tile.fromNibble(-1), isNull);
  });

  test('classification getters', () {
    expect(Tile.onewayRight.onewayDirection, Direction.right);
    expect(Tile.floor.onewayDirection, isNull);
    expect(Tile.switchA.switchChannel, 0);
    expect(Tile.switchB.switchChannel, 1);
    expect(Tile.wall.switchChannel, isNull);
    expect(Tile.gateAOpen.gateChannel, 0);
    expect(Tile.gateBClosed.gateChannel, 1);
    expect(Tile.target.gateChannel, isNull);
    expect(Tile.gateAOpen.gateStartsOpen, isTrue);
    expect(Tile.gateAClosed.gateStartsOpen, isFalse);
    expect(Tile.gateAOpen.isGate, isTrue);
    expect(Tile.switchA.isGate, isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/tile_test.dart` → FAIL.

- [ ] **Step 3: Implement**

`lib/src/tile.dart`:

```dart
import 'direction.dart';

/// The 13-entry static tile palette (spec §3). `nibble` is the 4-bit wire
/// value in the share-code format — never renumber. Values 13–15 reserved.
enum Tile {
  floor(0),
  wall(1),
  target(2),
  onewayUp(3),
  onewayRight(4),
  onewayDown(5),
  onewayLeft(6),
  switchA(7),
  switchB(8),
  gateAOpen(9),
  gateAClosed(10),
  gateBOpen(11),
  gateBClosed(12);

  const Tile(this.nibble);

  /// 4-bit wire value. Invariant: equals this enum's declaration index.
  final int nibble;

  /// Decodes a nibble. Returns null for reserved/out-of-range values —
  /// the codec maps that to DecodeError.invalidTile. Never throws.
  static Tile? fromNibble(int value) =>
      value >= 0 && value < values.length ? values[value] : null;

  /// The entry direction this one-way tile permits, or null if not one-way.
  Direction? get onewayDirection => switch (this) {
        Tile.onewayUp => Direction.up,
        Tile.onewayRight => Direction.right,
        Tile.onewayDown => Direction.down,
        Tile.onewayLeft => Direction.left,
        _ => null,
      };

  /// Switch channel (0 = A, 1 = B), or null if not a switch.
  int? get switchChannel => switch (this) {
        Tile.switchA => 0,
        Tile.switchB => 1,
        _ => null,
      };

  /// Gate channel (0 = A, 1 = B), or null if not a gate.
  int? get gateChannel => switch (this) {
        Tile.gateAOpen || Tile.gateAClosed => 0,
        Tile.gateBOpen || Tile.gateBClosed => 1,
        _ => null,
      };

  bool get isGate => gateChannel != null;

  /// Whether a gate tile begins the level open. Meaningless for non-gates.
  bool get gateStartsOpen => this == Tile.gateAOpen || this == Tile.gateBOpen;
}
```

Append to `lib/sokode_core.dart`: `export 'src/tile.dart';`

- [ ] **Step 4: Run to verify it passes** — `dart test test/tile_test.dart` → PASS.

- [ ] **Step 5: Commit** — `dart format . && git add -A && git commit -m "feat: add 13-entry Tile palette with nibble codec"`

---

### Task 4: Level + ASCII test helper

**Files:**
- Create: `packages/sokode_core/lib/src/level.dart`, `packages/sokode_core/test/helpers/ascii_level.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/level_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  test('crate indexes are canonically sorted regardless of input order', () {
    final level = Level(
      width: 4,
      height: 2,
      tiles: List.filled(8, Tile.floor),
      playerIndex: 0,
      crateIndexes: const [5, 2, 3],
    );
    expect(level.crateIndexes, [2, 3, 5]);
  });

  test('tiles and crateIndexes are unmodifiable', () {
    final level = Level(
      width: 4,
      height: 2,
      tiles: List.filled(8, Tile.floor),
      playerIndex: 0,
      crateIndexes: const [5],
    );
    expect(() => level.tiles[0] = Tile.wall, throwsUnsupportedError);
    expect(() => level.crateIndexes.add(1), throwsUnsupportedError);
  });

  test('ascii helper builds the expected level', () {
    final level = levelFromAscii([
      '#####',
      r'#@$.#',
      '#####',
    ]);
    expect(level.width, 5);
    expect(level.height, 3);
    expect(level.playerIndex, 6); // row 1, col 1
    expect(level.crateIndexes, [7]); // row 1, col 2
    expect(level.tileAt(8), Tile.target);
    expect(level.tileAt(0), Tile.wall);
    expect(level.tileAt(6), Tile.floor); // player marker leaves floor behind
  });

  test('ascii helper handles crate-on-target and player-on-target', () {
    final level = levelFromAscii([
      '####',
      '#+*#',
      '####',
    ]);
    expect(level.playerIndex, 5);
    expect(level.crateIndexes, [6]);
    expect(level.tileAt(5), Tile.target);
    expect(level.tileAt(6), Tile.target);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/level_test.dart` → FAIL.

- [ ] **Step 3: Implement**

`lib/src/level.dart`:

```dart
import 'tile.dart';

/// An authored, static level: the tile grid plus initial entity placement.
/// Immutable. Dimension caps (4..=32) are enforced by the validator and
/// codec (spec §3), not here — tests may build smaller boards.
class Level {
  /// [tiles] must have exactly `width * height` entries (row-major).
  /// [crateIndexes] is defensively copied and sorted ascending — the
  /// canonical order the share-code format requires.
  Level({
    required this.width,
    required this.height,
    required List<Tile> tiles,
    required this.playerIndex,
    required List<int> crateIndexes,
  })  : tiles = List.unmodifiable(tiles),
        crateIndexes = List.unmodifiable([...crateIndexes]..sort()) {
    assert(tiles.length == width * height, 'tiles must be width*height');
  }

  final int width;
  final int height;

  /// Row-major static tiles. Unmodifiable.
  final List<Tile> tiles;

  /// Cell index (`y * width + x`) of the player's start.
  final int playerIndex;

  /// Sorted ascending, unmodifiable. Invariant: canonical order.
  final List<int> crateIndexes;

  int get cellCount => width * height;

  Tile tileAt(int index) => tiles[index];
}
```

`test/helpers/ascii_level.dart` (test-only — not part of the public API):

```dart
import 'package:sokode_core/sokode_core.dart';

/// Builds a Level from an ASCII map. Legend:
///   `#` wall   ` ` floor   `.` target
///   `@` player-on-floor    `+` player-on-target
///   `$` crate-on-floor     `*` crate-on-target
///   `^ > v <` one-way (permitted entry direction)
///   `a` switch A   `b` switch B
///   `[` gate A open   `]` gate A closed
///   `{` gate B open   `}` gate B closed
Level levelFromAscii(List<String> rows) {
  final height = rows.length;
  final width = rows.first.length;
  final tiles = <Tile>[];
  int? player;
  final crates = <int>[];
  for (var y = 0; y < height; y++) {
    if (rows[y].length != width) {
      throw ArgumentError('row $y has length ${rows[y].length}, want $width');
    }
    for (var x = 0; x < width; x++) {
      final index = y * width + x;
      final ch = rows[y][x];
      tiles.add(switch (ch) {
        '#' => Tile.wall,
        ' ' || '@' || r'$' => Tile.floor,
        '.' || '+' || '*' => Tile.target,
        '^' => Tile.onewayUp,
        '>' => Tile.onewayRight,
        'v' => Tile.onewayDown,
        '<' => Tile.onewayLeft,
        'a' => Tile.switchA,
        'b' => Tile.switchB,
        '[' => Tile.gateAOpen,
        ']' => Tile.gateAClosed,
        '{' => Tile.gateBOpen,
        '}' => Tile.gateBClosed,
        _ => throw ArgumentError('unknown map char "$ch" at ($x,$y)'),
      });
      if (ch == '@' || ch == '+') player = index;
      if (ch == r'$' || ch == '*') crates.add(index);
    }
  }
  return Level(
    width: width,
    height: height,
    tiles: tiles,
    playerIndex: player!,
    crateIndexes: crates,
  );
}
```

Append to `lib/sokode_core.dart`: `export 'src/level.dart';`

- [ ] **Step 4: Run to verify it passes** — `dart test test/level_test.dart` → PASS.

- [ ] **Step 5: Commit** — `dart format . && git add -A && git commit -m "feat: add immutable Level and ascii test helper"`

---

### Task 5: GridState

**Files:**
- Create: `packages/sokode_core/lib/src/grid_state.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/grid_state_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/grid_state_test.dart` → FAIL.

- [ ] **Step 3: Implement**

`lib/src/grid_state.dart`:

```dart
import 'level.dart';

/// Immutable runtime state: entity positions plus per-gate open/closed.
///
/// Gate state is per-cell, not per-channel parity: the "a toggle never
/// closes an occupied gate" rule (spec §2.3) lets individual gates desync
/// from their channel, so parity alone cannot represent reachable states.
///
/// Canonical form: `crateIndexes` and `openGateIndexes` are always sorted
/// ascending — equality, hashing, and stateDigest rely on it.
class GridState {
  GridState({
    required this.level,
    required this.playerIndex,
    required List<int> crateIndexes,
    required List<int> openGateIndexes,
  })  : crateIndexes = List.unmodifiable([...crateIndexes]..sort()),
        openGateIndexes = List.unmodifiable([...openGateIndexes]..sort());

  /// Builds the pre-first-move state. Reads gate openness straight from the
  /// tile palette; deliberately fires NO switch toggles (spec §2.3:
  /// "initial placement fires nothing").
  factory GridState.initial(Level level) {
    final open = <int>[];
    for (var i = 0; i < level.cellCount; i++) {
      final tile = level.tiles[i];
      if (tile.isGate && tile.gateStartsOpen) open.add(i);
    }
    return GridState(
      level: level,
      playerIndex: level.playerIndex,
      crateIndexes: level.crateIndexes,
      openGateIndexes: open,
    );
  }

  final Level level;
  final int playerIndex;

  /// Sorted ascending, unmodifiable.
  final List<int> crateIndexes;

  /// Cell indexes of gates that are currently open. Sorted, unmodifiable.
  final List<int> openGateIndexes;

  /// Linear scan — crate lists are tiny (≤ ~50); an index structure would
  /// cost more in copying than it saves in lookups.
  bool hasCrateAt(int index) => crateIndexes.contains(index);

  bool isGateOpenAt(int index) => openGateIndexes.contains(index);

  bool isOccupied(int index) => index == playerIndex || hasCrateAt(index);

  @override
  bool operator ==(Object other) =>
      other is GridState &&
      other.playerIndex == playerIndex &&
      _listEquals(other.crateIndexes, crateIndexes) &&
      _listEquals(other.openGateIndexes, openGateIndexes);

  /// In-process hash only. Cross-platform/deterministic fingerprinting is
  /// stateDigest's job, not hashCode's.
  @override
  int get hashCode => Object.hash(
        playerIndex,
        Object.hashAll(crateIndexes),
        Object.hashAll(openGateIndexes),
      );
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

Append to `lib/sokode_core.dart`: `export 'src/grid_state.dart';`

- [ ] **Step 4: Run to verify it passes** — `dart test test/grid_state_test.dart` → PASS.

- [ ] **Step 5: Commit** — `dart format . && git add -A && git commit -m "feat: add immutable GridState with per-gate state"`

---

### Task 6: RuleSet interface + basic movement

**Files:**
- Create: `packages/sokode_core/lib/src/step_result.dart`, `packages/sokode_core/lib/src/ruleset.dart`, `packages/sokode_core/lib/src/validation.dart`, `packages/sokode_core/lib/src/sokoban_plus.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/movement_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  GridState start(List<String> rows) => GridState.initial(levelFromAscii(rows));

  test('moves into empty floor', () {
    final state = start(['#####', '#@  #', '#####']);
    final result = rules.step(state, Direction.right);
    expect(result, isA<Moved>());
    expect((result as Moved).state.playerIndex, 7);
  });

  test('blocked by walls', () {
    final state = start(['#####', '#@  #', '#####']);
    expect(rules.step(state, Direction.left), isA<Blocked>());
    expect(rules.step(state, Direction.up), isA<Blocked>());
    expect(rules.step(state, Direction.down), isA<Blocked>());
  });

  test('blocked by the board edge (no wrap-around)', () {
    // Player on an open edge — 3x1 strip, no surrounding walls.
    final level = Level(
      width: 3,
      height: 1,
      tiles: List.filled(3, Tile.floor),
      playerIndex: 0,
      crateIndexes: const [],
    );
    final state = GridState.initial(level);
    expect(rules.step(state, Direction.left), isA<Blocked>());
    expect(rules.step(state, Direction.up), isA<Blocked>());
    final right = rules.step(state, Direction.right);
    expect((right as Moved).state.playerIndex, 1);
  });

  test('blocked by a closed gate; walks through an open one', () {
    final closed = start(['#####', '#@] #', '#####']);
    expect(rules.step(closed, Direction.right), isA<Blocked>());
    final open = start(['#####', '#@[ #', '#####']);
    expect(rules.step(open, Direction.right), isA<Moved>());
  });

  test('a Blocked step leaves no trace (input state unchanged)', () {
    final state = start(['#####', '#@  #', '#####']);
    final before = GridState.initial(levelFromAscii(['#####', '#@  #', '#####']));
    rules.step(state, Direction.left);
    expect(state, before);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/movement_test.dart` → FAIL.

- [ ] **Step 3: Implement**

`lib/src/step_result.dart`:

```dart
import 'grid_state.dart';

/// Outcome of applying one action. Sealed: exhaustive switches everywhere.
sealed class StepResult {
  const StepResult();
}

/// The action was legal; [state] is the post-move state.
class Moved extends StepResult {
  const Moved(this.state);
  final GridState state;
}

/// The action was illegal; the pre-move state stands.
class Blocked extends StepResult {
  const Blocked();
}
```

`lib/src/validation.dart`:

```dart
/// Static structural defects a Level can have (spec §4).
enum ValidationError {
  dimensionOutOfBounds,
  noTargets,
  fewerCratesThanTargets,
  entityOutOfBounds,
  entityOnBlockedTile,
  duplicateCrate,
  playerOnCrate,
}

/// Result of RuleSet.validateStructure. Empty errors == valid.
class ValidationResult {
  const ValidationResult(this.errors);
  final List<ValidationError> errors;
  bool get isValid => errors.isEmpty;
}
```

`lib/src/ruleset.dart`:

```dart
import 'direction.dart';
import 'grid_state.dart';
import 'level.dart';
import 'step_result.dart';
import 'validation.dart';

/// The extension point for game rules (spec §2.1). v1 ships SokobanPlus;
/// Baba-style / nonogram rulesets implement this later without touching
/// the simulation, codec, or verifier.
abstract interface class RuleSet {
  /// Pure transition. Never mutates [state]; returns Blocked for any
  /// illegal action rather than throwing.
  StepResult step(GridState state, Direction action);

  /// Win condition for [state].
  bool isSolved(GridState state);

  /// The subset of Direction.values whose step() is Moved.
  List<Direction> legalActions(GridState state);

  /// Ruleset-specific static checks on an authored level (spec §4).
  ValidationResult validateStructure(Level level);
}
```

`lib/src/sokoban_plus.dart` (movement only in this task — pushing, one-ways beyond entry checks, switches, solving, and validation land in Tasks 7–11; the private helpers below are already shaped for them):

```dart
import 'direction.dart';
import 'grid_state.dart';
import 'level.dart';
import 'ruleset.dart';
import 'step_result.dart';
import 'tile.dart';
import 'validation.dart';

/// The v1 ruleset. Semantics pinned in spec §2.3 — every bullet there has
/// a test in this package.
class SokobanPlus implements RuleSet {
  const SokobanPlus();

  @override
  StepResult step(GridState state, Direction action) {
    final target = _neighbor(state.level, state.playerIndex, action);
    if (target == null) return const Blocked();
    if (!_canEnter(state, target, action)) return const Blocked();
    if (state.hasCrateAt(target)) {
      return const Blocked(); // pushing lands in Task 7
    }
    return Moved(_movePlayer(state, target));
  }

  @override
  bool isSolved(GridState state) => false; // Task 10

  @override
  List<Direction> legalActions(GridState state) => const []; // Task 10

  @override
  ValidationResult validateStructure(Level level) =>
      const ValidationResult([]); // Task 11

  /// Neighbor cell index in [dir], or null when off-board (edges block —
  /// no wrap-around; index±1 alone would wrap rows, hence x/y math).
  int? _neighbor(Level level, int index, Direction dir) {
    final x = index % level.width + dir.dx;
    final y = index ~/ level.width + dir.dy;
    if (x < 0 || x >= level.width || y < 0 || y >= level.height) return null;
    return y * level.width + x;
  }

  /// Entry rules shared by player and crates (spec §2.3: one-ways
  /// constrain entry only, and apply to both).
  bool _canEnter(GridState state, int index, Direction dir) {
    final tile = state.level.tiles[index];
    if (tile == Tile.wall) return false;
    if (tile.isGate && !state.isGateOpenAt(index)) return false;
    final oneway = tile.onewayDirection;
    if (oneway != null && oneway != dir) return false;
    return true;
  }

  GridState _movePlayer(GridState state, int to) => GridState(
        level: state.level,
        playerIndex: to,
        crateIndexes: state.crateIndexes,
        openGateIndexes: state.openGateIndexes,
      );
}
```

Append to `lib/sokode_core.dart`:

```dart
export 'src/ruleset.dart';
export 'src/sokoban_plus.dart';
export 'src/step_result.dart';
export 'src/validation.dart';
```

- [ ] **Step 4: Run to verify it passes** — `dart test test/movement_test.dart` → PASS (note: the crate cell blocks in this task, so no movement test may rely on pushing yet).

- [ ] **Step 5: Commit** — `dart format . && git add -A && git commit -m "feat: add RuleSet interface and SokobanPlus basic movement"`

---

### Task 7: Crate pushing

**Files:**
- Modify: `packages/sokode_core/lib/src/sokoban_plus.dart`
- Test: `packages/sokode_core/test/pushing_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  GridState start(List<String> rows) => GridState.initial(levelFromAscii(rows));

  test('pushes a crate into empty floor', () {
    final state = start(['######', r'#@$ .#', '######']);
    final result = rules.step(state, Direction.right) as Moved;
    expect(result.state.playerIndex, 8);
    expect(result.state.crateIndexes, [9]);
  });

  test('pushes a crate onto a target', () {
    final state = start(['#####', r'#@$.#', '#####']);
    final result = rules.step(state, Direction.right) as Moved;
    expect(result.state.crateIndexes, [8]);
  });

  test('cannot push a crate into a wall', () {
    final state = start(['#####', r'#@$##', '#####']);
    expect(rules.step(state, Direction.right), isA<Blocked>());
  });

  test('cannot push a crate into another crate', () {
    final state = start(['######', r'#@$$ #', '######']);
    expect(rules.step(state, Direction.right), isA<Blocked>());
  });

  test('cannot push a crate off the board', () {
    final level = Level(
      width: 3,
      height: 1,
      tiles: List.filled(3, Tile.floor),
      playerIndex: 1,
      crateIndexes: const [2],
    );
    expect(rules.step(GridState.initial(level), Direction.right),
        isA<Blocked>());
  });

  test('cannot push a crate into a closed gate; can into an open one', () {
    final closed = start(['######', r'#@$] #', '######']);
    expect(rules.step(closed, Direction.right), isA<Blocked>());
    final open = start(['######', r'#@$[ #', '######']);
    final result = rules.step(open, Direction.right) as Moved;
    expect(result.state.crateIndexes, [9]);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/pushing_test.dart` → FAIL (push currently Blocked).

- [ ] **Step 3: Implement** — in `sokoban_plus.dart`, replace the crate branch of `step` and add `_withPush`:

```dart
  @override
  StepResult step(GridState state, Direction action) {
    final target = _neighbor(state.level, state.playerIndex, action);
    if (target == null) return const Blocked();
    if (!_canEnter(state, target, action)) return const Blocked();
    if (state.hasCrateAt(target)) {
      final beyond = _neighbor(state.level, target, action);
      if (beyond == null) return const Blocked();
      if (state.hasCrateAt(beyond)) return const Blocked();
      if (!_canEnter(state, beyond, action)) return const Blocked();
      return Moved(_withPush(state, playerTo: target, crateTo: beyond));
    }
    return Moved(_movePlayer(state, target));
  }

  /// Crate leaves [playerTo] (the player takes its cell) and lands on
  /// [crateTo]. The GridState constructor re-sorts, keeping canonical order.
  GridState _withPush(GridState state,
      {required int playerTo, required int crateTo}) {
    final crates = state.crateIndexes.toList()
      ..remove(playerTo)
      ..add(crateTo);
    return GridState(
      level: state.level,
      playerIndex: playerTo,
      crateIndexes: crates,
      openGateIndexes: state.openGateIndexes,
    );
  }
```

- [ ] **Step 4: Run to verify all tests pass** — `dart test` → PASS (movement tests must still pass).

- [ ] **Step 5: Commit** — `dart format . && git add -A && git commit -m "feat: implement crate pushing"`

---

### Task 8: One-way tiles

**Files:**
- Test: `packages/sokode_core/test/oneway_test.dart` (implementation already exists in `_canEnter` — this task proves it end to end and catches regressions)

- [ ] **Step 1: Write the test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  GridState start(List<String> rows) => GridState.initial(levelFromAscii(rows));

  test('player enters a one-way only in its arrow direction', () {
    final state = start(['#####', '#@> #', '#####']);
    expect(rules.step(state, Direction.right), isA<Moved>());
  });

  test('player cannot enter a one-way against the arrow', () {
    final state = start(['#####', '# >@#', '#####']);
    expect(rules.step(state, Direction.left), isA<Blocked>());
  });

  test('exit is unconstrained (entry-only rule)', () {
    // Player walks right onto the one-way, then exits UP — legal, because
    // only entry is constrained.
    final level = levelFromAscii([
      '#####',
      '#   #',
      '#@> #',
      '#####',
    ]);
    final onOneway =
        (rules.step(GridState.initial(level), Direction.right) as Moved).state;
    expect(onOneway.playerIndex, 12); // on the '>' cell
    expect(rules.step(onOneway, Direction.up), isA<Moved>(),
        reason: 'exiting a one-way in any direction is legal');
  });

  test('crate entry obeys the same rule', () {
    final ok = start(['######', r'#@$> #', '######']);
    expect(rules.step(ok, Direction.right), isA<Moved>());
    final blocked = start(['######', r'#@$< #', '######']);
    expect(rules.step(blocked, Direction.right), isA<Blocked>());
  });
}
```

(If the `ascii` scaffolding line offends, delete both it and the final expect — it exists only to show a second valid board. Either version must pass.)

- [ ] **Step 2: Run** — `dart test test/oneway_test.dart` → PASS immediately (behavior shipped with `_canEnter` in Task 6). If any case FAILS, fix `_canEnter` — the rule is: entry requires `onewayDirection == null || onewayDirection == dir`; exits are never checked.

- [ ] **Step 3: Commit** — `dart format . && git add -A && git commit -m "test: pin one-way entry-only semantics"`

---

### Task 9: Switches and gates

**Files:**
- Modify: `packages/sokode_core/lib/src/sokoban_plus.dart`
- Test: `packages/sokode_core/test/switch_gate_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  test('player stepping on a switch toggles its whole channel', () {
    // '#@a].#' — gate A closed at index 9; '[' would be open.
    final level = levelFromAscii(['######', '#@a].#', '######']);
    var state = GridState.initial(level);
    expect(state.isGateOpenAt(9), isFalse);
    state = (rules.step(state, Direction.right) as Moved).state; // onto 'a'
    expect(state.isGateOpenAt(9), isTrue, reason: 'toggle opened the gate');
    state = (rules.step(state, Direction.right) as Moved).state; // onto gate
    expect(state.playerIndex, 9);
  });

  test('toggle affects only its own channel', () {
    final level = levelFromAscii(['#######', '#@a]} #', '#######']);
    var state = GridState.initial(level);
    state = (rules.step(state, Direction.right) as Moved).state;
    expect(state.isGateOpenAt(10), isTrue, reason: 'channel A toggled');
    expect(state.isGateOpenAt(11), isFalse, reason: 'channel B untouched');
  });

  test('open gates close on toggle — unless occupied (spec §2.3)', () {
    // Crate parked ON an open gate A; a second gate A is open elsewhere.
    final base = levelFromAscii(['#######', '#@a[[ #', '#######']);
    final level = Level(
      width: base.width,
      height: base.height,
      tiles: base.tiles,
      playerIndex: base.playerIndex,
      crateIndexes: const [10], // crate on the first '[' (index 10)
    );
    var state = GridState.initial(level);
    expect(state.isGateOpenAt(10), isTrue);
    expect(state.isGateOpenAt(11), isTrue);
    state = (rules.step(state, Direction.right) as Moved).state; // onto 'a'
    expect(state.isGateOpenAt(10), isTrue,
        reason: 'occupied gate must NOT close');
    expect(state.isGateOpenAt(11), isFalse,
        reason: 'unoccupied gate closes normally');
  });

  test('crate arriving on a switch fires the toggle too', () {
    final level = levelFromAscii(['######', r'#@$a]#', '######']);
    var state = GridState.initial(level);
    state = (rules.step(state, Direction.right) as Moved).state;
    // Crate moved onto 'a' (index 9); gate at 10 must now be open.
    expect(state.crateIndexes, [9]);
    expect(state.isGateOpenAt(10), isTrue);
  });

  test('push where crate AND player both land on switches fires twice', () {
    // Row 1 (indexes 6..11): # _ a a ] #
    // Player on floor (7), crate starts ON the first switch (8) — setup
    // fires nothing. Push right: crate 8 -> 9 (switch A, fire #1 opens the
    // gate), player 7 -> 8 (switch A, fire #2 closes it again, unoccupied).
    // Net closed proves BOTH arrivals fired.
    final tiles = [
      Tile.wall, Tile.wall, Tile.wall, Tile.wall, Tile.wall, Tile.wall, //
      Tile.wall, Tile.floor, Tile.switchA, Tile.switchA, Tile.gateAClosed,
      Tile.wall, //
      Tile.wall, Tile.wall, Tile.wall, Tile.wall, Tile.wall, Tile.wall,
    ];
    final doubleFire = Level(
      width: 6,
      height: 3,
      tiles: tiles,
      playerIndex: 7,
      crateIndexes: const [8],
    );
    var state = GridState.initial(doubleFire);
    expect(state.isGateOpenAt(10), isFalse, reason: 'setup fires nothing');
    state = (rules.step(state, Direction.right) as Moved).state;
    expect(state.isGateOpenAt(10), isFalse,
        reason: 'two toggles = net closed; proves both arrivals fire');
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/switch_gate_test.dart` → FAIL (no toggles yet).

- [ ] **Step 3: Implement** — in `sokoban_plus.dart`, wire toggles into `step` and add `_fireSwitch`:

```dart
  @override
  StepResult step(GridState state, Direction action) {
    final target = _neighbor(state.level, state.playerIndex, action);
    if (target == null) return const Blocked();
    if (!_canEnter(state, target, action)) return const Blocked();
    if (state.hasCrateAt(target)) {
      final beyond = _neighbor(state.level, target, action);
      if (beyond == null) return const Blocked();
      if (state.hasCrateAt(beyond)) return const Blocked();
      if (!_canEnter(state, beyond, action)) return const Blocked();
      var next = _withPush(state, playerTo: target, crateTo: beyond);
      // Deterministic order (ARCHITECTURE.md): crate toggle before player
      // toggle, both against post-move occupancy.
      next = _fireSwitch(next, beyond);
      next = _fireSwitch(next, target);
      return Moved(next);
    }
    var next = _movePlayer(state, target);
    next = _fireSwitch(next, target);
    return Moved(next);
  }

  /// If [arrivedAt] is a switch, toggles every gate of its channel in
  /// ascending cell order: closed -> open always; open -> closed only if
  /// unoccupied (spec §2.3 "never close an occupied gate"). Occupancy is
  /// evaluated against [state]'s (post-move) positions.
  GridState _fireSwitch(GridState state, int arrivedAt) {
    final channel = state.level.tiles[arrivedAt].switchChannel;
    if (channel == null) return state;
    final open = state.openGateIndexes.toList();
    for (var i = 0; i < state.level.cellCount; i++) {
      if (state.level.tiles[i].gateChannel != channel) continue;
      if (open.contains(i)) {
        if (!state.isOccupied(i)) open.remove(i);
      } else {
        open.add(i);
      }
    }
    return GridState(
      level: state.level,
      playerIndex: state.playerIndex,
      crateIndexes: state.crateIndexes,
      openGateIndexes: open,
    );
  }
```

- [ ] **Step 4: Run the full suite** — `dart test` → PASS.

- [ ] **Step 5: Commit** — `dart format . && git add -A && git commit -m "feat: implement switch toggles and occupied-gate rule"`

---

### Task 10: isSolved + legalActions

**Files:**
- Modify: `packages/sokode_core/lib/src/sokoban_plus.dart`
- Test: `packages/sokode_core/test/solved_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  test('solved when every target is covered by a crate', () {
    final level = levelFromAscii(['#####', r'#@$.#', '#####']);
    var state = GridState.initial(level);
    expect(rules.isSolved(state), isFalse);
    state = (rules.step(state, Direction.right) as Moved).state;
    expect(rules.isSolved(state), isTrue);
  });

  test('player standing on a target does not count as coverage', () {
    final level = levelFromAscii(['#####', '#+  #', '#####']);
    expect(rules.isSolved(GridState.initial(level)), isFalse);
  });

  test('extra crates beyond target count are fine', () {
    final level = levelFromAscii(['######', r'#@*$ #', '######']);
    // The single target (under the '*') is covered from the start.
    expect(rules.isSolved(GridState.initial(level)), isTrue);
  });

  test('legalActions lists exactly the non-Blocked directions', () {
    final level = levelFromAscii([
      '####',
      '#@ #',
      '#  #',
      '####',
    ]);
    final actions = rules.legalActions(GridState.initial(level));
    expect(actions, unorderedEquals([Direction.right, Direction.down]));
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/solved_test.dart` → FAIL.

- [ ] **Step 3: Implement** — replace the two stubs in `sokoban_plus.dart`:

```dart
  @override
  bool isSolved(GridState state) {
    for (var i = 0; i < state.level.cellCount; i++) {
      if (state.level.tiles[i] == Tile.target && !state.hasCrateAt(i)) {
        return false;
      }
    }
    return true;
  }

  @override
  List<Direction> legalActions(GridState state) => [
        for (final d in Direction.values)
          if (step(state, d) is Moved) d,
      ];
```

- [ ] **Step 4: Run the full suite** — `dart test` → PASS.

- [ ] **Step 5: Commit** — `dart format . && git add -A && git commit -m "feat: implement isSolved and legalActions"`

---

### Task 11: validateStructure

**Files:**
- Modify: `packages/sokode_core/lib/src/sokoban_plus.dart`
- Test: `packages/sokode_core/test/validation_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  Level valid() => levelFromAscii([
        '######',
        r'#@$ .#',
        '#    #',
        '#    #',
        '######',
      ]);

  test('a well-formed level validates clean', () {
    final result = rules.validateStructure(valid());
    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
  });

  test('dimension caps 4..=32 (spec §4)', () {
    Level sized(int w, int h) => Level(
          width: w,
          height: h,
          tiles: List.filled(w * h, Tile.floor)
            ..[1] = Tile.target,
          playerIndex: 0,
          crateIndexes: const [1],
        );
    expect(rules.validateStructure(sized(3, 8)).errors,
        contains(ValidationError.dimensionOutOfBounds));
    expect(rules.validateStructure(sized(8, 33)).errors,
        contains(ValidationError.dimensionOutOfBounds));
    expect(rules.validateStructure(sized(4, 4)).errors,
        isNot(contains(ValidationError.dimensionOutOfBounds)));
    expect(rules.validateStructure(sized(32, 32)).errors,
        isNot(contains(ValidationError.dimensionOutOfBounds)));
  });

  test('requires at least one target', () {
    final level = levelFromAscii(['#####', r'#@$ #', '#####', '#####']);
    expect(rules.validateStructure(level).errors,
        contains(ValidationError.noTargets));
  });

  test('requires crates >= targets', () {
    // 3 targets, 1 crate
    final level = levelFromAscii(['#####', r'#@$.#', '#.. #', '#####']);
    expect(rules.validateStructure(level).errors,
        contains(ValidationError.fewerCratesThanTargets));
  });

  test('rejects entities on walls or closed gates', () {
    final base = valid();
    final onWall = Level(
      width: base.width,
      height: base.height,
      tiles: base.tiles,
      playerIndex: 0, // a wall cell
      crateIndexes: base.crateIndexes,
    );
    expect(rules.validateStructure(onWall).errors,
        contains(ValidationError.entityOnBlockedTile));
  });

  test('rejects out-of-bounds entities, duplicate crates, player-on-crate',
      () {
    final base = valid();
    Level withCrates(List<int> crates, {int? player}) => Level(
          width: base.width,
          height: base.height,
          tiles: base.tiles,
          playerIndex: player ?? base.playerIndex,
          crateIndexes: crates,
        );
    expect(rules.validateStructure(withCrates(const [999])).errors,
        contains(ValidationError.entityOutOfBounds));
    expect(rules.validateStructure(withCrates(const [8, 8])).errors,
        contains(ValidationError.duplicateCrate));
    expect(
        rules
            .validateStructure(withCrates(const [7], player: 7))
            .errors,
        contains(ValidationError.playerOnCrate));
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/validation_test.dart` → FAIL (stub returns valid).

- [ ] **Step 3: Implement** — replace the stub in `sokoban_plus.dart`:

```dart
  @override
  ValidationResult validateStructure(Level level) {
    final errors = <ValidationError>[];
    if (level.width < 4 ||
        level.width > 32 ||
        level.height < 4 ||
        level.height > 32) {
      errors.add(ValidationError.dimensionOutOfBounds);
    }
    final targets =
        level.tiles.where((t) => t == Tile.target).length;
    if (targets == 0) errors.add(ValidationError.noTargets);
    if (level.crateIndexes.length < targets) {
      errors.add(ValidationError.fewerCratesThanTargets);
    }
    bool blocked(Tile t) =>
        t == Tile.wall || t == Tile.gateAClosed || t == Tile.gateBClosed;
    for (final e in [level.playerIndex, ...level.crateIndexes]) {
      if (e < 0 || e >= level.cellCount) {
        errors.add(ValidationError.entityOutOfBounds);
      } else if (blocked(level.tiles[e])) {
        errors.add(ValidationError.entityOnBlockedTile);
      }
    }
    if (level.crateIndexes.toSet().length != level.crateIndexes.length) {
      errors.add(ValidationError.duplicateCrate);
    }
    if (level.crateIndexes.contains(level.playerIndex)) {
      errors.add(ValidationError.playerOnCrate);
    }
    return ValidationResult(errors);
  }
```

- [ ] **Step 4: Run the full suite** — `dart test` → PASS.

- [ ] **Step 5: Commit** — `dart format . && git add -A && git commit -m "feat: implement structural level validation"`

---

### Task 12: Simulation, stateDigest, determinism golden test

**Files:**
- Create: `packages/sokode_core/lib/src/simulation.dart`, `packages/sokode_core/lib/src/state_digest.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/determinism_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  final level = levelFromAscii([
    '########',
    r'#@$ a] #',
    '#  .   #',
    '########',
  ]);
  const moves = [
    Direction.right, // push crate right
    Direction.right, // walk onto vacated... (crate at idx 11, player 10)
    Direction.down, // reposition
    Direction.right,
    Direction.up, // step onto switch 'a' (12) — gate 13 opens
  ];

  int runReplay() {
    const sim = Simulation(SokobanPlus());
    var state = sim.initialState(level);
    for (final m in moves) {
      final result = sim.apply(state, m);
      state = switch (result) {
        Moved(:final state) => state,
        Blocked() => state, // illegal moves in a replay leave state as-is
      };
    }
    return stateDigest(state);
  }

  test('same replay twice yields the identical digest', () {
    expect(runReplay(), runReplay());
  });

  test('GOLDEN: digest is pinned across refactors and platforms', () {
    // GOLDEN-PIN PROCEDURE: on first run this literal is -1 and the test
    // FAILS, printing the actual digest. Copy that number here, rerun,
    // commit. Any future change to this number is a determinism break —
    // treat as a bug, never re-pin without understanding why.
    final actual = runReplay();
    printOnFailure('actual digest: $actual');
    expect(actual, -1);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/determinism_test.dart` → the golden test FAILS (Simulation/stateDigest undefined first; then, once implemented, fails printing the actual digest).

- [ ] **Step 3: Implement**

`lib/src/simulation.dart`:

```dart
import 'direction.dart';
import 'grid_state.dart';
import 'level.dart';
import 'ruleset.dart';
import 'step_result.dart';

/// The single entry point for advancing game state. Play, replay
/// verification (Plan 02), and the import gate all go through this class —
/// never fork a second transition path (spec §2.2).
class Simulation {
  const Simulation(this.ruleSet);

  final RuleSet ruleSet;

  GridState initialState(Level level) => GridState.initial(level);

  StepResult apply(GridState state, Direction action) =>
      ruleSet.step(state, action);
}
```

`lib/src/state_digest.dart`:

```dart
import 'grid_state.dart';

/// Deterministic, cross-platform fingerprint of a GridState.
///
/// Deliberately NOT a cryptographic hash and NOT hashCode: it must produce
/// the same value on the Dart VM and on the web (JS numbers), so all
/// arithmetic stays below 2^53. h*31 + v with h < 1e9+7 and v <= 65535
/// peaks around 3.1e10 — exact in a double. Used by the determinism golden
/// test and (later) the title generator.
int stateDigest(GridState state) {
  const modulus = 1000000007;
  var h = 7;
  void mix(int v) {
    h = (h * 31 + v + 2) % modulus;
  }

  mix(state.playerIndex);
  state.crateIndexes.forEach(mix);
  mix(modulus - 1); // section separator
  state.openGateIndexes.forEach(mix);
  return h;
}
```

Append to `lib/sokode_core.dart`:

```dart
export 'src/simulation.dart';
export 'src/state_digest.dart';
```

- [ ] **Step 4: Pin the golden value** — run `dart test test/determinism_test.dart`; the golden test fails and `printOnFailure` shows `actual digest: <N>`. Replace the `-1` literal with `<N>`. Rerun: PASS. (This is the one place a "failing test → pin → pass" loop replaces classic TDD — the value cannot be known before the implementation exists.)

- [ ] **Step 5: Run the full suite** — `dart test` → PASS.

- [ ] **Step 6: Commit** — `dart format . && git add -A && git commit -m "feat: add Simulation and cross-platform state digest with golden test"`

---

### Task 13: Random-walk invariant properties

**Files:**
- Create: `packages/sokode_core/test/helpers/random_level.dart`
- Test: `packages/sokode_core/test/invariants_test.dart`

- [ ] **Step 1: Write the helper**

`test/helpers/random_level.dart`:

```dart
import 'dart:math';

import 'package:sokode_core/sokode_core.dart';

bool _blockedForEntities(Tile t) =>
    t == Tile.wall || t == Tile.gateAClosed || t == Tile.gateBClosed;

/// Generates a structurally plausible 8x8 level from a seeded [random].
/// Same seed => same level, always (property tests must be reproducible).
Level randomLevel(Random random) {
  const width = 8;
  const height = 8;
  final tiles = List<Tile>.generate(width * height, (_) {
    final roll = random.nextInt(12);
    if (roll == 0) return Tile.wall;
    if (roll == 1) return Tile.target;
    if (roll == 2) return Tile.values[3 + random.nextInt(4)]; // one-ways
    if (roll == 3) return random.nextBool() ? Tile.switchA : Tile.switchB;
    if (roll == 4) return Tile.values[9 + random.nextInt(4)]; // gates
    return Tile.floor;
  });
  final free = <int>[
    for (var i = 0; i < tiles.length; i++)
      if (!_blockedForEntities(tiles[i])) i,
  ]..shuffle(random);
  final player = free.removeLast();
  final crates = <int>[
    for (var i = 0; i < 3 && free.isNotEmpty; i++) free.removeLast(),
  ];
  return Level(
    width: width,
    height: height,
    tiles: tiles,
    playerIndex: player,
    crateIndexes: crates,
  );
}
```

- [ ] **Step 2: Write the test**

`test/invariants_test.dart`:

```dart
import 'dart:math';

import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/random_level.dart';

void main() {
  const rules = SokobanPlus();

  void checkInvariants(Level level, GridState state) {
    expect(state.crateIndexes.length, level.crateIndexes.length,
        reason: 'crate count conserved');
    expect(state.crateIndexes.toSet().length, state.crateIndexes.length,
        reason: 'no two crates share a cell');
    for (final e in [state.playerIndex, ...state.crateIndexes]) {
      expect(e, inInclusiveRange(0, level.cellCount - 1),
          reason: 'entities stay on the board');
      expect(level.tiles[e], isNot(Tile.wall),
          reason: 'entities never stand on walls');
      if (level.tiles[e].isGate) {
        expect(state.isGateOpenAt(e), isTrue,
            reason: 'entities never stand on a CLOSED gate — this is the '
                'invariant the occupied-gate rule exists to protect');
      }
    }
    expect(state.crateIndexes, isNot(contains(state.playerIndex)),
        reason: 'player and crate never overlap');
  }

  test('invariants hold across 200 random levels x 100 random moves', () {
    final random = Random(42); // fixed seed: failures are reproducible
    for (var trial = 0; trial < 200; trial++) {
      final level = randomLevel(random);
      var state = GridState.initial(level);
      checkInvariants(level, state);
      for (var move = 0; move < 100; move++) {
        final dir = Direction.values[random.nextInt(4)];
        final result = rules.step(state, dir);
        if (result is Moved) state = result.state;
        checkInvariants(level, state);
      }
    }
  });

  test('legalActions agrees with step outcomes on random states', () {
    final random = Random(7);
    for (var trial = 0; trial < 50; trial++) {
      final level = randomLevel(random);
      var state = GridState.initial(level);
      for (var move = 0; move < 30; move++) {
        final legal = rules.legalActions(state);
        for (final d in Direction.values) {
          expect(legal.contains(d), rules.step(state, d) is Moved,
              reason: 'legalActions must mirror step for $d');
        }
        if (legal.isEmpty) break;
        state =
            (rules.step(state, legal[random.nextInt(legal.length)]) as Moved)
                .state;
      }
    }
  });
}
```

- [ ] **Step 3: Run** — `dart test test/invariants_test.dart` → expected PASS. **If the closed-gate invariant fails**, the bug is in `_fireSwitch` occupancy ordering — verify toggles run against post-move positions and that crate-fire precedes player-fire.

- [ ] **Step 4: Run the full suite** — `dart test` → PASS.

- [ ] **Step 5: Commit** — `dart format . && git add -A && git commit -m "test: add seeded random-walk invariant properties"`

---

### Task 14: Import boundary test, ARCHITECTURE.md, PR

**Files:**
- Create: `packages/sokode_core/test/import_boundary_test.dart`, `ARCHITECTURE.md`

- [ ] **Step 1: Write the boundary test**

```dart
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('sokode_core has zero Flutter imports (spec §2.1 — CI-enforced)', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('package:flutter') ||
          source.contains('dart:ui')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'core must stay engine-independent: $offenders');
  });

  test('pubspec declares no flutter dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('sdk: flutter'), isFalse);
  });
}
```

- [ ] **Step 2: Run** — `dart test test/import_boundary_test.dart` → PASS.

- [ ] **Step 3: Write ARCHITECTURE.md** (repo root):

```markdown
# Sokode Architecture

Spec of record: `docs/superpowers/specs/2026-07-06-sokode-v1-design.md`.

## Core / shell split

All game logic lives in `packages/sokode_core` — pure Dart, zero Flutter
imports, enforced by `test/import_boundary_test.dart` in CI. The Flutter
shell (Plan 03) depends on the core; the core never depends on the shell.

## Determinism contract

- Integer-only logic. No floating point anywhere in the core.
- No ambient randomness; anything random takes an injected seeded PRNG.
- No reliance on hash-map iteration order; canonical lists are sorted
  ascending (`GridState.crateIndexes`, `GridState.openGateIndexes`).
- One transition path: play, replay verification, and the import gate all
  call `Simulation.apply` → `RuleSet.step`. Never fork a verify-only copy.
- `stateDigest` is the cross-platform fingerprint (all arithmetic < 2^53,
  exact under JS numbers). `hashCode` is in-process only.

## RuleSet extension point

`RuleSet` (step / isSolved / legalActions / validateStructure) is the seam
for future rulesets (Baba-style, nonogram). v1's only implementer is
`SokobanPlus`. Deliberately a small fat interface, not capability
composition — one implementer doesn't justify the machinery.

## Pinned SokobanPlus semantics

Spec §2.3, plus one addendum introduced by Plan 01:

- One-way tiles constrain **entry only**, for player and crates alike.
- Switches toggle on **enter** (player or crate arrival).
- A toggle never closes an **occupied** gate — it stays open. Gate state is
  therefore per-cell, not per-channel parity.
- Initial placement fires nothing.
- **Addendum:** when one push lands the crate and the player on switches in
  the same step, the crate's toggle resolves before the player's, both
  evaluated against post-move occupancy. (`SokobanPlus.step`)
- Undo/reset are shell concerns; replays contain final action sequences
  only (2-bit alphabet: up=0, right=1, down=2, left=3).
```

- [ ] **Step 4: Full local gate, push, open PR**

```bash
cd packages/sokode_core && dart format --output=none --set-exit-if-changed . && dart analyze --fatal-infos && dart test && cd ../..
git add -A
git commit -m "test: enforce core import boundary; add ARCHITECTURE.md"
git push
gh pr create --repo stevenfackley/sokode --base main \
  --title "feat: sokode_core engine (Plan 01 — spec phases 0-1)" \
  --body "Pure deterministic Sokoban+ core per docs/superpowers/specs/2026-07-06-sokode-v1-design.md §2. Direction/Tile/Level/GridState, RuleSet + SokobanPlus (all §2.3 semantics pinned by tests), Simulation, stateDigest golden, seeded random-walk invariants, import-boundary enforcement."
gh pr checks --repo stevenfackley/sokode --watch
```

Expected: CI green on the PR. **Note:** `main` has no commits yet (the repo was born on `docs/design-spec`); if `gh pr create` complains about the base, first seed main: `git push origin docs/design-spec:main`, then create the PR with `--base main`.

- [ ] **Step 5: Phase-gate report** — post the playbook-format report (built / decisions+trade-offs / assumptions / test results+coverage via `dart test --coverage=coverage` / defer-descope) as a PR comment. Do not merge without it.

---

## Self-Review (completed at authoring time)

- **Spec coverage:** §2.1 packages/interface → Tasks 1, 6; §2.2 determinism → Tasks 12, 13; §2.3 semantics → Tasks 5 (initial fires nothing), 8 (one-ways), 9 (switches/gates/occupied/double-fire), 10 (win), 7 (push rules); §4 validator subset → Task 11; CI + import boundary → Tasks 1, 14. Codec/verifier are Plan 02 by design.
- **Placeholder scan:** none — every step has literal code/commands. The two intentional deferred stubs (`isSolved`/`legalActions`/`validateStructure` in Task 6) are declared as landing in Tasks 10–11 in the same plan.
- **Type consistency:** `StepResult`/`Moved`/`Blocked`, `RuleSet` method names, `GridState` field names, and `stateDigest` are used identically across Tasks 6–14; `Tile` getters used in Tasks 8–13 are all defined in Task 3.
