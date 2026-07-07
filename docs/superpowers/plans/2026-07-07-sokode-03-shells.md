# Sokode Plan 03 — Player + Maker Shells Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Flutter shell (spec phases 4–5): play a decoded level to a win, author a level, test-solve it, publish a proof-carrying share code — full author → verify → encode → decode → play → win roundtrip on device.

**Architecture:** Thin shell over `sokode_core`. All game logic stays in the core; the app holds only presentation state (`ChangeNotifier` controllers), rendering (one `CustomPainter` board + animated entity widgets), input mapping, and a JSON-file `LevelRepository` behind an interface (the future-backend seam). No state-management or DI packages — plain Flutter (YAGNI; the shell is deliberately swappable).

**Tech Stack:** Flutter 3.x stable (Dart ≥3.5), `sokode_core` via path dependency, `path_provider`, `share_plus`. Dev: `flutter_lints`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-07-06-sokode-v1-design.md` §5. **Prerequisites:** Plans 01 and 02 merged.

**Branch:** `feat/03-shells` from `main`. Work from `C:\Users\steve\projects\sokode`; use the PowerShell tool (Bash PATH is broken in this environment). Dart-only commands run from `packages/sokode_core`; flutter commands from `app/`.

**Formatting rule:** same as Plan 02 — `dart format` follows each package's language version; run `dart format .` then the gate `dart format --output=none --set-exit-if-changed .` (exit 0) in the package you touched before every commit.

**Code-discipline note (deliberate change from Plans 01–02):** logic (controllers, repository, title generator, publish/import flows) and ALL tests are literal — transcribe verbatim. Pure widget LAYOUT (padding, colors, exact widget nesting) is **bounded executor freedom**: match the described structure and make the literal widget tests pass; do not add packages, screens, or features beyond the task text. Rationale: untested literal widget trees would be this plan's likeliest bug source; the tests are the contract.

**Spec addendum this plan introduces:** draft (unsolved) maker levels persist locally as raw JSON — they cannot be share codes because v1 codes REQUIRE an embedded solution (`flags` bit0). Only published levels and imported levels are stored as codes. Record in ARCHITECTURE.md (Task 12).

---

## File Structure

```
packages/sokode_core/
  lib/src/title_generator.dart     # Task 1 — closes a Plan 01 gap (spec §5)
  test/title_generator_test.dart
app/                               # Flutter app (Task 2 scaffold)
  pubspec.yaml                     # path dep on sokode_core
  analysis_options.yaml            # flutter_lints + strict analyzer
  lib/main.dart                    # MaterialApp, routes, web-fragment import hook
  lib/render/board_painter.dart    # static tiles (walls/targets/one-ways/switches/gates)
  lib/render/board_view.dart       # CustomPaint + animated entity layer
  lib/render/tile_palette_colors.dart
  lib/play/player_session.dart     # ChangeNotifier: state stack, moves, undo/reset, win
  lib/play/player_screen.dart      # input (swipe+keys), HUD, win dialog
  lib/make/editor_state.dart       # ChangeNotifier: grid, brush, entity placement, validate
  lib/make/maker_screen.dart       # palette + canvas + test-play + publish flow
  lib/store/stored_level.dart      # PublishedLevel/ImportedLevel (code) + DraftLevel (json)
  lib/store/level_repository.dart  # interface + JsonFileLevelRepository
  lib/screens/level_list_screen.dart  # tabs Mine/Imported/Samples + paste-import
  lib/import/import_strings.dart   # typed error -> human string mapping
  test/…                           # one test file per unit (literal)
.github/workflows/ci.yml           # + flutter job (Task 2)
```

## Task summary

| # | Task | Package |
|---|---|---|
| 1 | `title_generator` (deterministic word-pair from level digest) + tests | core |
| 2 | Flutter app scaffold, path dep, strict lints, CI `app` job | app |
| 3 | `TilePaletteColors` + `BoardPainter` (static tiles, gate state aware) + painter test | app |
| 4 | `BoardView` (CustomPaint + `AnimatedPositioned` entities, tween-on-move) + widget test | app |
| 5 | `PlayerSession` controller (state stack, undo/reset, move recording, win) + unit tests | app |
| 6 | `PlayerScreen` (swipe + arrow keys, haptic-on-move, HUD, win dialog) + widget tests | app |
| 7 | `StoredLevel` models + `LevelRepository` interface + JSON impl + tests | app |
| 8 | `ImportStrings` (every DecodeError/ValidationError/VerifyFailure → human text) + tests | app |
| 9 | `LevelListScreen` (tabs, paste-import via LevelImporter, delete) + widget tests | app |
| 10 | `EditorState` + maker canvas/palette painting + structural validation surfacing | app |
| 11 | Test-play recording + publish flow (validate → verify → encode → share/clipboard) | app |
| 12 | Web fragment import (`Uri.base.fragment`, kIsWeb) + E2E roundtrip widget test + ARCHITECTURE.md append + PR | app |

Acceptance (spec phases 4–5): Task 12's E2E widget test drives author → test-solve → publish → re-import on a fresh repository → play → win, entirely through public widget/controller APIs.

---

### Task 1: title_generator (core)

**Files:**
- Create: `packages/sokode_core/lib/src/title_generator.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/title_generator_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  Level level() => levelFromAscii([
        '######',
        r'#@$ .#',
        '#    #',
        '######',
      ]);

  test('deterministic: same level always yields the same title', () {
    expect(titleForLevel(level()), titleForLevel(level()));
  });

  test('format is "Adjective Noun" from the fixed word lists', () {
    final parts = titleForLevel(level()).split(' ');
    expect(parts, hasLength(2));
    expect(titleAdjectives, contains(parts[0]));
    expect(titleNouns, contains(parts[1]));
  });

  test('word lists are fixed-size and non-empty (moderation surface)', () {
    expect(titleAdjectives, hasLength(32));
    expect(titleNouns, hasLength(32));
  });

  test('different levels usually get different titles', () {
    final other = levelFromAscii([
      '######',
      r'#@ $.#',
      '#    #',
      '######',
    ]);
    expect(titleForLevel(other), isNot(titleForLevel(level())));
  });
}
```

- [ ] **Step 2: Run to verify it fails** — from `packages/sokode_core`: `dart test test/title_generator_test.dart` → FAIL.

- [ ] **Step 3: Implement**

`lib/src/title_generator.dart`:

```dart
import 'grid_state.dart';
import 'level.dart';
import 'state_digest.dart';

/// Fixed word lists (spec §5: titles are generated, never user text —
/// moderation by construction). 32×32 = 1024 combinations. Append-only:
/// reordering or removing words changes existing levels' titles.
const List<String> titleAdjectives = [
  'Amber', 'Bold', 'Brave', 'Calm', 'Clever', 'Copper', 'Crimson', 'Daring',
  'Dusty', 'Eager', 'Foggy', 'Gentle', 'Golden', 'Hidden', 'Iron', 'Ivory',
  'Jade', 'Keen', 'Lucky', 'Mellow', 'Nimble', 'Oaken', 'Pale', 'Quiet',
  'Rapid', 'Rustic', 'Silent', 'Slate', 'Steady', 'Stormy', 'Swift', 'Tidy',
];

const List<String> titleNouns = [
  'Anchor', 'Beacon', 'Cellar', 'Cipher', 'Corner', 'Crate', 'Depot',
  'Dock', 'Garden', 'Gate', 'Harbor', 'Hollow', 'Lantern', 'Ledger',
  'Maze', 'Meadow', 'Mill', 'Orchard', 'Passage', 'Path', 'Plaza',
  'Quarry', 'Relay', 'Ridge', 'Signal', 'Spiral', 'Station', 'Switch',
  'Tunnel', 'Vault', 'Wharf', 'Yard',
];

/// Deterministic "Adjective Noun" title derived from the level's initial
/// state digest — same level, same title, on every platform.
String titleForLevel(Level level) {
  final digest = stateDigest(GridState.initial(level));
  final adjective = titleAdjectives[digest % titleAdjectives.length];
  final noun =
      titleNouns[(digest ~/ titleAdjectives.length) % titleNouns.length];
  return '$adjective $noun';
}
```

Append to `lib/sokode_core.dart`: `export 'src/title_generator.dart';`

- [ ] **Step 4: Run to verify it passes**, then full `dart test` (core suite stays green).

- [ ] **Step 5: Format-gate and commit** — `feat: add deterministic level title generator`

---

### Task 2: Flutter app scaffold + CI

**Files:**
- Create: `app/` (via `flutter create`), `app/analysis_options.yaml`, modify `app/pubspec.yaml`, `.github/workflows/ci.yml`

- [ ] **Step 1: Scaffold**

```powershell
Set-Location C:\Users\steve\projects\sokode
flutter create --org com.sokode --project-name sokode_app --platforms android,ios,web app
```

(Bundle id `com.sokode.sokode_app` — pre-store, changeable until Plan 04's release prep. If `flutter` is not on PATH, STOP and report BLOCKED.)

- [ ] **Step 2: Wire the core dependency and lints**

In `app/pubspec.yaml`, under `dependencies:` add (keeping what `flutter create` generated):

```yaml
  sokode_core:
    path: ../packages/sokode_core
  path_provider: ^2.1.0
  share_plus: ^10.0.0
```

Replace `app/analysis_options.yaml` with:

```yaml
include: package:flutter_lints/flutter.yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

- [ ] **Step 3: Smoke test** — replace `app/test/widget_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  test('app can see the core package', () {
    expect(Direction.values, hasLength(4));
  });
}
```

Run from `app/`: `flutter pub get`, `flutter analyze` (clean), `flutter test` (passes). Delete `flutter create`'s default counter code in `lib/main.dart` and replace with a minimal `MaterialApp` shell:

```dart
import 'package:flutter/material.dart';

void main() => runApp(const SokodeApp());

class SokodeApp extends StatelessWidget {
  const SokodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sokode',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const Placeholder(), // LevelListScreen arrives in Task 9
    );
  }
}
```

- [ ] **Step 4: Add the CI job** — append to `.github/workflows/ci.yml` jobs:

```yaml
  app:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed lib test
      - run: flutter analyze
      - run: flutter test
      - run: flutter build web --release
```

- [ ] **Step 5: Format-gate (app dir: `dart format lib test`), commit** — `chore: scaffold Flutter app with core dependency and CI job`

---

### Task 3: Tile colors + BoardPainter

**Files:**
- Create: `app/lib/render/tile_palette_colors.dart`, `app/lib/render/board_painter.dart`
- Test: `app/test/board_painter_test.dart`

**Structure (bounded freedom on exact colors/glyph shapes):**
- `TilePaletteColors`: a const class mapping every `Tile` kind + board background to a `Color`. One color per tile kind, distinct hues for switch/gate channels A vs B; closed gates visibly darker than open.
- `BoardPainter extends CustomPainter`: constructor takes `Level level`, `GridState state`, `TilePaletteColors colors`. Paints, per cell: background, then tile — wall (filled square), target (ring), one-way (triangle pointing its `onewayDirection`), switch (small diamond), gate (filled square, open vs closed color chosen from `state.isGateOpenAt(i)`, NOT from the static tile). Does NOT paint player or crates (entity layer, Task 4). `shouldRepaint` compares `state` (value equality — core provides it).
- Cell geometry helper (literal, used by tests and Task 4):

```dart
/// Square cell size fitting a [cols]x[rows] board into [size].
double cellSizeFor(Size size, int cols, int rows) {
  final byWidth = size.width / cols;
  final byHeight = size.height / rows;
  return byWidth < byHeight ? byWidth : byHeight;
}
```

- [ ] **Step 1: Write the literal test** (`app/test/board_painter_test.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/render/board_painter.dart';
import 'package:sokode_app/render/tile_palette_colors.dart';
import 'package:sokode_core/sokode_core.dart';

Level _level() => Level(
      width: 4,
      height: 4,
      tiles: [
        ...List.filled(4, Tile.wall),
        Tile.wall, Tile.floor, Tile.gateAOpen, Tile.wall,
        Tile.wall, Tile.target, Tile.switchA, Tile.wall,
        ...List.filled(4, Tile.wall),
      ],
      playerIndex: 5,
      crateIndexes: const [9],
    );

void main() {
  test('cellSizeFor fits the limiting axis', () {
    expect(cellSizeFor(const Size(400, 200), 4, 4), 50);
    expect(cellSizeFor(const Size(200, 400), 4, 4), 50);
  });

  test('shouldRepaint only when state changes', () {
    final level = _level();
    const colors = TilePaletteColors();
    final a = BoardPainter(
        level: level, state: GridState.initial(level), colors: colors);
    final b = BoardPainter(
        level: level, state: GridState.initial(level), colors: colors);
    expect(a.shouldRepaint(b), isFalse);
    final moved = GridState(
      level: level,
      playerIndex: 6,
      crateIndexes: level.crateIndexes,
      openGateIndexes: const [6],
    );
    final c = BoardPainter(level: level, state: moved, colors: colors);
    expect(a.shouldRepaint(c), isTrue);
  });

  testWidgets('paints without throwing for every tile kind', (tester) async {
    // A level containing all 13 tile kinds; smoke-renders the painter.
    final tiles = List<Tile>.filled(16, Tile.floor)
      ..setRange(0, 13, Tile.values);
    final level = Level(
        width: 4, height: 4, tiles: tiles, playerIndex: 14, crateIndexes: const [15]);
    await tester.pumpWidget(MaterialApp(
      home: CustomPaint(
        size: const Size(200, 200),
        painter: BoardPainter(
            level: level,
            state: GridState.initial(level),
            colors: const TilePaletteColors()),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**, **Step 3: implement** per the structure above (layout freedom within it), **Step 4: tests pass + `flutter analyze` clean**, **Step 5: format-gate, commit** — `feat: render static board tiles with gate-state awareness`

---

### Task 4: BoardView with animated entities

**Files:**
- Create: `app/lib/render/board_view.dart`
- Test: `app/test/board_view_test.dart`

**Structure:** `BoardView` is a `StatelessWidget` taking `level`, `state`, and `Duration moveDuration` (default 120 ms). Inside a `LayoutBuilder` it computes `cellSizeFor`, renders a `Stack`: bottom layer `CustomPaint(BoardPainter…)`, above it one `AnimatedPositioned` per crate (`key: ValueKey('crate-$i')` where `i` is the crate's list position is WRONG — crates are anonymous; use the sorted cell index at first build? No: crates have no identity across moves) — **use this rule (literal):** entities are keyed by role and rendered from `state`: the player gets `key: const ValueKey('player')`; crates get `ValueKey('crate-${'index in state.crateIndexes list order'}')`. Because `crateIndexes` is sorted by cell, a push can re-order keys mid-animation for multi-crate boards; that produces a visual swap in rare cases and is ACCEPTED for v1 (tween-on-move is a nicety, not a contract — note it in a code comment). Player widget: filled circle; crate: rounded square (crate-on-target may tint differently — freedom).

- [ ] **Step 1: literal test** (`app/test/board_view_test.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/render/board_view.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  testWidgets('renders player and crates at their state positions',
      (tester) async {
    final level = Level(
      width: 4,
      height: 4,
      tiles: List.filled(16, Tile.floor),
      playerIndex: 5,
      crateIndexes: const [6, 9],
    );
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 200,
        height: 200,
        child: BoardView(level: level, state: GridState.initial(level)),
      ),
    ));
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
        openGateIndexes: const []);
    Widget build(GridState s) => MaterialApp(
        home: SizedBox(
            width: 400,
            height: 100,
            child: BoardView(level: level, state: s)));
    await tester.pumpWidget(build(initial));
    final before = tester.getTopLeft(find.byKey(const ValueKey('player')));
    await tester.pumpWidget(build(moved));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.byKey(const ValueKey('player')));
    expect(after.dx, greaterThan(before.dx));
  });
}
```

- [ ] Steps 2–5 as usual. Commit — `feat: add BoardView with tween-on-move entity layer`

---

### Task 5: PlayerSession controller

**Files:**
- Create: `app/lib/play/player_session.dart`
- Test: `app/test/player_session_test.dart`

- [ ] **Step 1: literal test:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/play/player_session.dart';
import 'package:sokode_core/sokode_core.dart';

Level _pushOnce() => Level(
      width: 5,
      height: 3,
      tiles: [
        ...List.filled(5, Tile.wall),
        Tile.wall, Tile.floor, Tile.floor, Tile.target, Tile.wall,
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

  test('win: crate onto target sets isSolved; further moves are ignored',
      () {
    final session = PlayerSession(_pushOnce())
      ..tryMove(Direction.right)
      ..tryMove(Direction.right);
    expect(session.isSolved, isTrue);
    expect(session.tryMove(Direction.left), isFalse,
        reason: 'input after win must not corrupt the recorded solution');
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
```

- [ ] **Step 3: literal implementation** (`app/lib/play/player_session.dart`):

```dart
import 'package:flutter/foundation.dart';
import 'package:sokode_core/sokode_core.dart';

/// Presentation-side play state: a stack of core GridStates plus the
/// recorded action sequence. All rules live in the core; this class only
/// orchestrates. The recording is the FINAL action sequence — undo pops
/// moves, so undone moves never appear in a published solution (spec §2.3).
class PlayerSession extends ChangeNotifier {
  PlayerSession(this.level) : _states = [GridState.initial(level)];

  final Level level;

  static const SokobanPlus _rules = SokobanPlus();
  static const Simulation _simulation = Simulation(_rules);

  final List<GridState> _states;
  final List<Direction> _moves = [];

  GridState get state => _states.last;

  /// The recorded solution-so-far. Unmodifiable snapshot.
  List<Direction> get moves => List.unmodifiable(_moves);

  int get moveCount => _moves.length;

  bool get isSolved => _rules.isSolved(state);

  bool get canUndo => _moves.isNotEmpty;

  /// Applies [direction] if legal. Returns false (and records nothing) on
  /// Blocked, and ignores input entirely once solved so the recorded
  /// solution stays exactly the sequence that won.
  bool tryMove(Direction direction) {
    if (isSolved) return false;
    switch (_simulation.apply(state, direction)) {
      case Moved(:final state):
        _states.add(state);
        _moves.add(direction);
        notifyListeners();
        return true;
      case Blocked():
        return false;
    }
  }

  void undo() {
    if (_moves.isEmpty) return;
    _states.removeLast();
    _moves.removeLast();
    notifyListeners();
  }

  void reset() {
    _states
      ..clear()
      ..add(GridState.initial(level));
    _moves.clear();
    notifyListeners();
  }
}
```

- [ ] Steps 2/4/5 as usual. Commit — `feat: add PlayerSession with undo-safe solution recording`

---

### Task 6: PlayerScreen

**Files:**
- Create: `app/lib/play/player_screen.dart`
- Test: `app/test/player_screen_test.dart`

**Structure (freedom within):** `PlayerScreen` takes `Level level`, optional `String? title`, optional `VoidCallback? onSolved`. Owns a `PlayerSession` (`ListenableBuilder` for rebuilds). AppBar: title (or `titleForLevel(level)`), move counter, undo (disabled when `!canUndo`) and reset `IconButton`s with `tooltip: 'Undo'` / `'Reset'`. Body: `BoardView` inside a `GestureDetector` (`onPanEnd`: dominant-axis swipe → `Direction`; ignore sub-40-logical-px flings) wrapped in a `Focus`/`KeyboardListener` mapping arrow keys. On each successful move: `HapticFeedback.selectionClick()` (wrap in `if (!kIsWeb)`). When `isSolved` flips true: show a non-dismissable `AlertDialog` (key `ValueKey('win-dialog')`) with move count and actions "Replay" (reset) and "Done" (pop + `onSolved?.call()`).

Swipe mapping (literal — used verbatim so tests and future maintainers agree):

```dart
Direction? directionFromPanVelocity(Offset velocity) {
  const minVelocity = 100.0;
  if (velocity.distance < minVelocity) return null;
  if (velocity.dx.abs() >= velocity.dy.abs()) {
    return velocity.dx > 0 ? Direction.right : Direction.left;
  }
  return velocity.dy > 0 ? Direction.down : Direction.up;
}
```

- [ ] **Step 1: literal test:**

```dart
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
        Tile.wall, Tile.floor, Tile.floor, Tile.target, Tile.wall,
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

  testWidgets('arrow keys move the player; win dialog appears on solve',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(level: _pushOnce())));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('win-dialog')), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets); // move count shown
  });

  testWidgets('undo button reverts a move', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PlayerScreen(level: _pushOnce())));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsWidgets); // move counter back to zero
  });
}
```

- [ ] Steps 2–5 as usual. Commit — `feat: add player screen with swipe/key input and win flow`

---

### Task 7: StoredLevel models + LevelRepository

**Files:**
- Create: `app/lib/store/stored_level.dart`, `app/lib/store/level_repository.dart`
- Test: `app/test/level_repository_test.dart`

- [ ] **Step 1: literal models** (`stored_level.dart`):

```dart
import 'dart:convert';

import 'package:sokode_core/sokode_core.dart';

/// A level saved as its share code — used for published ("mine") and
/// imported levels. The code IS the source of truth: canonical,
/// proof-carrying, and re-verified on load through LevelImporter.
class StoredCode {
  const StoredCode({required this.code, required this.title, required this.kind});

  final String code;
  final String title;

  /// 'mine' or 'imported'.
  final String kind;

  Map<String, Object?> toJson() => {'code': code, 'title': title, 'kind': kind};

  static StoredCode fromJson(Map<String, Object?> json) => StoredCode(
        code: json['code']! as String,
        title: json['title']! as String,
        kind: json['kind']! as String,
      );
}

/// A maker draft — no solution yet, so it CANNOT be a share code (v1 codes
/// require an embedded solution). Raw JSON persistence instead.
class DraftLevel {
  const DraftLevel({required this.name, required this.level});

  final String name; // generated word-pair; still no free text
  final Level level;

  Map<String, Object?> toJson() => {
        'name': name,
        'width': level.width,
        'height': level.height,
        'tiles': [for (final t in level.tiles) t.nibble],
        'player': level.playerIndex,
        'crates': level.crateIndexes,
      };

  /// Total: returns null instead of throwing on malformed/hostile JSON —
  /// drafts only ever come from our own writes, but disk is still input.
  static DraftLevel? fromJson(Map<String, Object?> json) {
    try {
      final tiles = <Tile>[];
      for (final n in json['tiles']! as List) {
        final tile = Tile.fromNibble(n as int);
        if (tile == null) return null;
        tiles.add(tile);
      }
      final width = json['width']! as int;
      final height = json['height']! as int;
      if (tiles.length != width * height) return null;
      return DraftLevel(
        name: json['name']! as String,
        level: Level(
          width: width,
          height: height,
          tiles: tiles,
          playerIndex: json['player']! as int,
          crateIndexes: [for (final c in json['crates']! as List) c as int],
        ),
      );
    } on Object {
      return null;
    }
  }
}

String encodeStoreFile(List<StoredCode> codes, List<DraftLevel> drafts) =>
    jsonEncode({
      'version': 1,
      'codes': [for (final c in codes) c.toJson()],
      'drafts': [for (final d in drafts) d.toJson()],
    });
```

- [ ] **Step 2: literal repository** (`level_repository.dart`):

```dart
import 'dart:convert';
import 'dart:io';

import 'stored_level.dart';

/// Local persistence seam (spec §8): a future backend implements this same
/// interface without touching game logic or UI.
abstract interface class LevelRepository {
  Future<List<StoredCode>> loadCodes();
  Future<List<DraftLevel>> loadDrafts();
  Future<void> saveCode(StoredCode code);
  Future<void> saveDraft(DraftLevel draft);
  Future<void> deleteCode(String code);
  Future<void> deleteDraft(String name);
}

/// Single-JSON-file implementation. Levels number in the dozens; one file
/// read/written whole is simpler and atomic-enough (write temp + rename).
class JsonFileLevelRepository implements LevelRepository {
  JsonFileLevelRepository(this._file);

  final File _file;

  Future<(List<StoredCode>, List<DraftLevel>)> _read() async {
    if (!await _file.exists()) return (<StoredCode>[], <DraftLevel>[]);
    try {
      final root = jsonDecode(await _file.readAsString());
      if (root is! Map<String, Object?>) return (<StoredCode>[], <DraftLevel>[]);
      final codes = <StoredCode>[
        for (final c in (root['codes'] as List? ?? []))
          StoredCode.fromJson((c as Map).cast<String, Object?>()),
      ];
      final drafts = <DraftLevel>[
        for (final d in (root['drafts'] as List? ?? []))
          if (DraftLevel.fromJson((d as Map).cast<String, Object?>())
              case final draft?)
            draft,
      ];
      return (codes, drafts);
    } on Object {
      // Corrupt store: fail open with an empty library rather than crash.
      return (<StoredCode>[], <DraftLevel>[]);
    }
  }

  Future<void> _write(List<StoredCode> codes, List<DraftLevel> drafts) async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(encodeStoreFile(codes, drafts), flush: true);
    await tmp.rename(_file.path);
  }

  @override
  Future<List<StoredCode>> loadCodes() async => (await _read()).$1;

  @override
  Future<List<DraftLevel>> loadDrafts() async => (await _read()).$2;

  @override
  Future<void> saveCode(StoredCode code) async {
    final (codes, drafts) = await _read();
    codes
      ..removeWhere((c) => c.code == code.code)
      ..add(code);
    await _write(codes, drafts);
  }

  @override
  Future<void> saveDraft(DraftLevel draft) async {
    final (codes, drafts) = await _read();
    drafts
      ..removeWhere((d) => d.name == draft.name)
      ..add(draft);
    await _write(codes, drafts);
  }

  @override
  Future<void> deleteCode(String code) async {
    final (codes, drafts) = await _read();
    codes.removeWhere((c) => c.code == code);
    await _write(codes, drafts);
  }

  @override
  Future<void> deleteDraft(String name) async {
    final (codes, drafts) = await _read();
    drafts.removeWhere((d) => d.name == name);
    await _write(codes, drafts);
  }
}
```

(Note: `dart:io` file storage doesn't exist on web — Task 12 wires a
`MemoryLevelRepository` fallback for `kIsWeb`; the interface is why that's a
two-line swap. Include `MemoryLevelRepository` here: same interface, backed
by in-memory lists — literal implementation is trivial and it doubles as
the test double.)

Also add to `level_repository.dart`:

```dart
/// In-memory implementation: web fallback (no dart:io) and test double.
class MemoryLevelRepository implements LevelRepository {
  final List<StoredCode> _codes = [];
  final List<DraftLevel> _drafts = [];

  @override
  Future<List<StoredCode>> loadCodes() async => List.of(_codes);

  @override
  Future<List<DraftLevel>> loadDrafts() async => List.of(_drafts);

  @override
  Future<void> saveCode(StoredCode code) async {
    _codes
      ..removeWhere((c) => c.code == code.code)
      ..add(code);
  }

  @override
  Future<void> saveDraft(DraftLevel draft) async {
    _drafts
      ..removeWhere((d) => d.name == draft.name)
      ..add(draft);
  }

  @override
  Future<void> deleteCode(String code) async =>
      _codes.removeWhere((c) => c.code == code);

  @override
  Future<void> deleteDraft(String name) async =>
      _drafts.removeWhere((d) => d.name == name);
}
```

- [ ] **Step 3: literal test** (`level_repository_test.dart`) — exercises JsonFileLevelRepository against a temp dir (`Directory.systemTemp.createTemp`), covering: empty load, save/load roundtrip for codes and drafts, upsert-by-key, delete, corrupt-file fail-open (write garbage bytes, expect empty lists, no throw), and DraftLevel.fromJson rejecting a bad nibble and a tiles/dims mismatch. Write the cases from this description — each is 3–6 lines with the models above.

- [ ] Steps 4–5 as usual. Commit — `feat: add level repository with JSON-file and memory implementations`

---

### Task 8: Import error strings

**Files:**
- Create: `app/lib/import/import_strings.dart`
- Test: `app/test/import_strings_test.dart`

- [ ] **Step 1: literal implementation:**

```dart
import 'package:sokode_core/sokode_core.dart';

/// Human-readable, non-technical strings for every import failure. UI
/// copy only — the typed values remain the source of truth.
String describeImportFailure(ImportOutcome outcome) => switch (outcome) {
      ImportSuccess() => 'Level imported.',
      ImportDecodeFailure(:final error) => switch (error) {
          DecodeError.badCharset ||
          DecodeError.badMagic ||
          DecodeError.truncated ||
          DecodeError.badChecksum ||
          DecodeError.payloadLengthMismatch ||
          DecodeError.invalidTile ||
          DecodeError.entityOutOfBounds =>
            'That code is damaged or incomplete — check you copied all of it.',
          DecodeError.unsupportedVersion ||
          DecodeError.unsupportedRuleset ||
          DecodeError.reservedFlagBits =>
            'That code was made with a newer version of Sokode. Update the app.',
          DecodeError.dimensionOutOfBounds ||
          DecodeError.solutionTooLong =>
            'That code describes a level outside Sokode\'s limits.',
          DecodeError.missingSolution =>
            'That code has no solution proof, so it can\'t be trusted.',
        },
      ImportValidationFailure() =>
        'That level is not structurally valid, so it can\'t be played.',
      ImportVerifyFailure() =>
        'That level\'s solution proof doesn\'t check out — it may be fake.',
    };
```

- [ ] **Step 2: literal test:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/import/import_strings.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  test('every DecodeError has a non-empty, non-technical description', () {
    for (final error in DecodeError.values) {
      final text = describeImportFailure(ImportDecodeFailure(error));
      expect(text, isNotEmpty, reason: '$error');
      expect(text.contains('DecodeError'), isFalse, reason: '$error');
    }
  });

  test('validation and verify failures have descriptions', () {
    expect(describeImportFailure(const ImportValidationFailure([])),
        isNotEmpty);
    expect(describeImportFailure(const ImportVerifyFailure(VerifyNotSolved())),
        isNotEmpty);
  });
}
```

(The exhaustive `switch` means adding a 14th `DecodeError` in the future
fails compilation here — that's intentional.)

- [ ] Steps 3–5 as usual. Commit — `feat: map every import failure to human copy`

---

### Task 9: LevelListScreen

**Files:**
- Create: `app/lib/screens/level_list_screen.dart`
- Modify: `app/lib/main.dart` (home becomes `LevelListScreen`)
- Test: `app/test/level_list_screen_test.dart`

**Structure (freedom within):** takes a `LevelRepository` and a `LevelImporter` (default `const LevelImporter(SokobanPlus())`). Three tabs: **Mine** (kind=='mine'), **Imported**, **Drafts**. FAB `ValueKey('new-level')` → MakerScreen (Task 10). AppBar action `ValueKey('import-button')` opens a dialog with a `TextField` (`ValueKey('import-field')`) — pasting a code is NOT free text (it's validated input; rejected codes never persist): on submit run `importer.import(text.trim())`; on `ImportSuccess` save `StoredCode(code: trimmed, title: titleForLevel(level), kind: 'imported')` and show the new tile; otherwise show `describeImportFailure(...)` in a `SnackBar` (`ValueKey('import-error')` on its content Text). Tapping a code tile decodes (already-proven code) and pushes `PlayerScreen`. Long-press → delete confirm.

- [ ] **Step 1: literal test:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/screens/level_list_screen.dart';
import 'package:sokode_app/store/level_repository.dart';
import 'package:sokode_core/sokode_core.dart';

Level _solvable() => Level(
      width: 5,
      height: 3,
      tiles: [
        ...List.filled(5, Tile.wall),
        Tile.wall, Tile.floor, Tile.floor, Tile.target, Tile.wall,
        ...List.filled(5, Tile.wall),
      ],
      playerIndex: 6,
      crateIndexes: const [7],
    );

void main() {
  testWidgets('importing a genuine code adds it to Imported', (tester) async {
    final repo = MemoryLevelRepository();
    final code =
        encode(_solvable(), const [Direction.right, Direction.right]);
    await tester.pumpWidget(
        MaterialApp(home: LevelListScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('import-field')), code);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await repo.loadCodes()).single.kind, 'imported');
  });

  testWidgets('a forged code is rejected with human copy and NOT saved',
      (tester) async {
    final repo = MemoryLevelRepository();
    await tester.pumpWidget(
        MaterialApp(home: LevelListScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('import-field')), 'not-a-real-code');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-error')), findsOneWidget);
    expect(await repo.loadCodes(), isEmpty);
  });
}
```

- [ ] Steps 2–5 as usual. Commit — `feat: add level list with gated paste-import`

---

### Task 10: EditorState + maker canvas

**Files:**
- Create: `app/lib/make/editor_state.dart`, `app/lib/make/maker_screen.dart` (canvas + palette; test-play/publish arrive in Task 11)
- Test: `app/test/editor_state_test.dart`

- [ ] **Step 1: literal EditorState:**

```dart
import 'package:flutter/foundation.dart';
import 'package:sokode_core/sokode_core.dart';

/// What the maker's brush can paint. Tiles paint the tile layer; player
/// and crate place entities; erase resets a cell to floor and removes any
/// entity on it.
enum Brush {
  floor, wall, target, onewayUp, onewayRight, onewayDown, onewayLeft,
  switchA, switchB, gateAOpen, gateAClosed, gateBOpen, gateBClosed,
  player, crate, erase,
}

/// Mutable authoring state. Converts to an immutable core Level on demand;
/// all validation is the core's validateStructure — the editor never
/// duplicates rules.
class EditorState extends ChangeNotifier {
  EditorState({this.width = 8, this.height = 8})
      : _tiles = List.filled(width * height, Tile.floor) {
    _borderWalls();
  }

  final int width;
  final int height;
  final List<Tile> _tiles;
  int? _playerIndex;
  final Set<int> _crateIndexes = {};
  Brush brush = Brush.wall;

  void _borderWalls() {
    for (var x = 0; x < width; x++) {
      _tiles[x] = Tile.wall;
      _tiles[(height - 1) * width + x] = Tile.wall;
    }
    for (var y = 0; y < height; y++) {
      _tiles[y * width] = Tile.wall;
      _tiles[y * width + width - 1] = Tile.wall;
    }
  }

  Tile tileAt(int index) => _tiles[index];
  int? get playerIndex => _playerIndex;
  Set<int> get crateIndexes => Set.unmodifiable(_crateIndexes);

  static const Map<Brush, Tile> _tileBrushes = {
    Brush.floor: Tile.floor,
    Brush.wall: Tile.wall,
    Brush.target: Tile.target,
    Brush.onewayUp: Tile.onewayUp,
    Brush.onewayRight: Tile.onewayRight,
    Brush.onewayDown: Tile.onewayDown,
    Brush.onewayLeft: Tile.onewayLeft,
    Brush.switchA: Tile.switchA,
    Brush.switchB: Tile.switchB,
    Brush.gateAOpen: Tile.gateAOpen,
    Brush.gateAClosed: Tile.gateAClosed,
    Brush.gateBOpen: Tile.gateBOpen,
    Brush.gateBClosed: Tile.gateBClosed,
  };

  /// Applies the current brush to [index]. Blocked-tile painting under an
  /// entity evicts the entity (a crate can't live on a wall). Placing the
  /// player moves the single player marker.
  void paint(int index) {
    final tile = _tileBrushes[brush];
    if (tile != null) {
      _tiles[index] = tile;
      final blocked = tile == Tile.wall ||
          tile == Tile.gateAClosed ||
          tile == Tile.gateBClosed;
      if (blocked) {
        _crateIndexes.remove(index);
        if (_playerIndex == index) _playerIndex = null;
      }
    } else if (brush == Brush.player) {
      if (_blockedAt(index) || _crateIndexes.contains(index)) return;
      _playerIndex = index;
    } else if (brush == Brush.crate) {
      if (_blockedAt(index) || _playerIndex == index) return;
      _crateIndexes.add(index);
    } else if (brush == Brush.erase) {
      _tiles[index] = Tile.floor;
      _crateIndexes.remove(index);
      if (_playerIndex == index) _playerIndex = null;
    }
    notifyListeners();
  }

  bool _blockedAt(int index) {
    final t = _tiles[index];
    return t == Tile.wall || t == Tile.gateAClosed || t == Tile.gateBClosed;
  }

  /// Immutable core Level, or null while no player is placed.
  Level? toLevel() {
    final player = _playerIndex;
    if (player == null) return null;
    return Level(
      width: width,
      height: height,
      tiles: List.of(_tiles),
      playerIndex: player,
      crateIndexes: _crateIndexes.toList(),
    );
  }

  /// Core-rule validation; noTargets etc. surface through this, plus a
  /// pseudo-check for the missing player (which toLevel can't represent).
  List<String> validationProblems() {
    final level = toLevel();
    if (level == null) return const ['Place the player.'];
    final result = const SokobanPlus().validateStructure(level);
    return [
      for (final error in result.errors)
        switch (error) {
          ValidationError.dimensionOutOfBounds => 'Board size out of range.',
          ValidationError.noTargets => 'Add at least one target.',
          ValidationError.fewerCratesThanTargets =>
            'Add crates: at least one per target.',
          ValidationError.entityOutOfBounds => 'An entity is off the board.',
          ValidationError.entityOnBlockedTile =>
            'An entity is on a wall or closed gate.',
          ValidationError.duplicateCrate => 'Two crates share a cell.',
          ValidationError.playerOnCrate => 'Player and crate overlap.',
        },
    ];
  }

  void loadDraft(DraftLevel draft) {
    _tiles.setAll(0, draft.level.tiles);
    _playerIndex = draft.level.playerIndex;
    _crateIndexes
      ..clear()
      ..addAll(draft.level.crateIndexes);
    notifyListeners();
  }
}
```

(Import for `DraftLevel` comes from `../store/stored_level.dart` — adjust the import line accordingly; if EditorState dims differ from a loaded draft's, constructor-match them at the call site: `EditorState(width: draft.level.width, height: draft.level.height)..loadDraft(draft)`.)

**MakerScreen structure (freedom within):** palette = horizontal scrollable row of brush chips (key `ValueKey('brush-<name>')` using the enum name); canvas = `BoardView`-style grid rendering EditorState (crates/player markers painted; reuse `BoardPainter` by building a preview `Level`/`GridState` when a player exists, else a simplified painter — executor's choice); tap/drag on cells → `paint(index)`; a validation banner listing `validationProblems()` when non-empty; "Save draft" button (key `ValueKey('save-draft')`) persisting via repository with a `titleForLevel`-style generated name (for player-less drafts use 'Untitled Draft <n>').

- [ ] **Step 1 (test): literal test** (`editor_state_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/make/editor_state.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  test('starts with border walls and floor interior', () {
    final editor = EditorState(width: 6, height: 4);
    expect(editor.tileAt(0), Tile.wall);
    expect(editor.tileAt(7), Tile.floor);
  });

  test('painting tiles, placing entities, eviction rules', () {
    final editor = EditorState(width: 6, height: 4);
    editor.brush = Brush.target;
    editor.paint(8);
    expect(editor.tileAt(8), Tile.target);
    editor.brush = Brush.player;
    editor.paint(7);
    expect(editor.playerIndex, 7);
    editor.brush = Brush.crate;
    editor.paint(8);
    expect(editor.crateIndexes, {8});
    // crate refuses player's cell; player brush moves the marker
    editor.paint(7);
    expect(editor.crateIndexes, {8});
    editor.brush = Brush.wall;
    editor.paint(8); // wall under crate evicts it
    expect(editor.crateIndexes, isEmpty);
  });

  test('toLevel is null until a player exists; validation maps core errors',
      () {
    final editor = EditorState(width: 6, height: 4);
    expect(editor.toLevel(), isNull);
    expect(editor.validationProblems(), ['Place the player.']);
    editor.brush = Brush.player;
    editor.paint(7);
    expect(editor.toLevel(), isNotNull);
    expect(editor.validationProblems(), contains('Add at least one target.'));
  });
}
```

- [ ] Steps 2–5 as usual. Commit — `feat: add maker editor state and authoring canvas`

---

### Task 11: Test-play recording + publish flow

**Files:**
- Modify: `app/lib/make/maker_screen.dart`
- Test: `app/test/publish_flow_test.dart`

**Flow (structure is normative; widget layout free):**
1. "Test" button (key `ValueKey('test-play')`), enabled only when `validationProblems().isEmpty`. Pushes `PlayerScreen(level: editor.toLevel()!, onSolved: ...)` — the SAME player screen; no forked logic.
2. When the test-play session wins, MakerScreen receives the recorded `moves` (add an optional `void Function(List<Direction> moves)? onSolvedWithMoves` to PlayerScreen that fires alongside `onSolved`; passing the session's `moves` — extend Task 6's PlayerScreen minimally and keep its tests green).
3. Back on MakerScreen with a captured solution: "Publish" button (key `ValueKey('publish')`) becomes enabled. Publish runs, in order: `validateStructure` (again — the board may have changed since testing: **any edit after a successful test-play clears the captured solution**; that rule is normative), `ReplayVerifier.verify(level, moves)` — must be `VerifySuccess` — then `encode(level, moves)`, saves `StoredCode(kind: 'mine', title: titleForLevel(level))`, and shows the code in a dialog (key `ValueKey('publish-dialog')`) with "Copy" (Clipboard.setData) and "Share" (share_plus; skip on web/test via `kIsWeb`-guard + injectable share callback for tests).
4. Publishing without a verified solve is impossible by construction: the button's enablement + the verify call are both gates.

- [ ] **Step 1: literal test:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/make/maker_screen.dart';
import 'package:sokode_app/store/level_repository.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  testWidgets(
      'publish is gated on a verified solve and emits an importable code',
      (tester) async {
    final repo = MemoryLevelRepository();
    await tester.pumpWidget(MaterialApp(
        home: MakerScreen(repository: repo)));
    await tester.pumpAndSettle();

    // Author a minimal solvable level via the state object (driving every
    // paint gesture through the canvas is Task 10's coverage, not this
    // test's): expose the screen's EditorState for tests via a key'd
    // provider or constructor-injected EditorState.
    final editor = MakerScreen.editorOf(tester); // static test hook
    editor.brush = Brush.player;
    editor.paint(9);
    editor.brush = Brush.crate;
    editor.paint(10);
    editor.brush = Brush.target;
    editor.paint(11);
    await tester.pumpAndSettle();

    expect(tester
        .widget<ElevatedButton>(find.byKey(const ValueKey('publish')))
        .enabled, isFalse, reason: 'no solve captured yet');

    // Test-play and solve it.
    await tester.tap(find.byKey(const ValueKey('test-play')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(tester
        .widget<ElevatedButton>(find.byKey(const ValueKey('publish')))
        .enabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('publish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('publish-dialog')), findsOneWidget);

    // The saved code must survive the full import gate.
    final saved = (await repo.loadCodes()).single;
    expect(saved.kind, 'mine');
    expect(const LevelImporter(SokobanPlus()).import(saved.code),
        isA<ImportSuccess>());
  });
}
```

(Implementation detail forced by this test: `MakerScreen` needs a
constructor-injectable `EditorState` and a `static EditorState editorOf(WidgetTester tester)`
test hook — or equivalent constructor injection the test can reach. Keep it
test-only and documented. The level: an 8×8 default board, player at 9,
crate at 10, target at 11 — one `arrowRight` push solves it. Keyboard
import: `package:flutter/services.dart` for `LogicalKeyboardKey`.)

- [ ] Steps 2–5 as usual. Commit — `feat: gate publishing behind a verified test-solve`

---

### Task 12: Web fragment import, E2E roundtrip, docs, PR

**Files:**
- Modify: `app/lib/main.dart`, `ARCHITECTURE.md`
- Test: `app/test/e2e_roundtrip_test.dart`

- [ ] **Step 1: main.dart wiring (literal):**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/level_list_screen.dart';
import 'store/level_repository.dart';

void main() => runApp(const SokodeApp());

class SokodeApp extends StatelessWidget {
  const SokodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sokode',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: LevelListScreen(
        repository: defaultRepository(),
        // Web: sokode.com/#<code> — the fragment stays client-side (never
        // in server logs); hand it to the list screen's import flow.
        initialImportCode:
            kIsWeb && Uri.base.fragment.isNotEmpty ? Uri.base.fragment : null,
      ),
    );
  }
}
```

Plus `defaultRepository()` in `level_repository.dart` (literal):

```dart
/// kIsWeb has no dart:io; the memory repository is the v1 web fallback
/// (web persistence lands with Plan 04's deploy work if needed).
LevelRepository defaultRepository() => kIsWeb
    ? MemoryLevelRepository()
    : JsonFileLevelRepository(_documentsFile());
```

with `_documentsFile()` using `path_provider`'s `getApplicationDocumentsDirectory()` — since that's async and the ctor isn't, use a `LazyJsonFileLevelRepository` wrapper or resolve the path at first use inside `_read`/`_write` (executor's choice; keep the interface unchanged; conditional-import `dart:io` behind a stub so `flutter build web` compiles — the standard `_io.dart`/`_web.dart` conditional-import pattern). `LevelListScreen` gains an optional `String? initialImportCode` that, when non-null, runs the Task 9 import flow once on first build (literal contract: same save/error paths as manual paste).

- [ ] **Step 2: E2E roundtrip test (literal):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/make/maker_screen.dart';
import 'package:sokode_app/screens/level_list_screen.dart';
import 'package:sokode_app/store/level_repository.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  testWidgets('FULL ROUNDTRIP: author -> verify -> code -> fresh import -> play -> win',
      (tester) async {
    // --- Author + publish (Maker) ---
    final authorRepo = MemoryLevelRepository();
    await tester.pumpWidget(MaterialApp(home: MakerScreen(repository: authorRepo)));
    await tester.pumpAndSettle();
    final editor = MakerScreen.editorOf(tester);
    editor.brush = Brush.player;
    editor.paint(9);
    editor.brush = Brush.crate;
    editor.paint(10);
    editor.brush = Brush.target;
    editor.paint(11);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('test-play')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('publish')));
    await tester.pumpAndSettle();
    final code = (await authorRepo.loadCodes()).single.code;

    // --- Fresh instance imports via the web-fragment path ---
    final playerRepo = MemoryLevelRepository();
    await tester.pumpWidget(MaterialApp(
        home: LevelListScreen(
            repository: playerRepo, initialImportCode: code)));
    await tester.pumpAndSettle();
    expect((await playerRepo.loadCodes()).single.kind, 'imported');

    // --- Play it to the win ---
    await tester.tap(find.text(titleForLevel(
        (decode(code) as DecodeSuccess).level)));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('win-dialog')), findsOneWidget);
  });
}
```

- [ ] **Step 3: append to ARCHITECTURE.md:**

```markdown

## Shell (Plan 03)

The Flutter app holds zero game rules: `PlayerSession`/`EditorState` are
presentation state over core calls; `BoardPainter`/`BoardView` render;
`LevelRepository` (interface + JSON-file/memory impls) is the future-backend
seam. Publishing is gated twice — UI enablement AND `ReplayVerifier` — and
any edit after a test-solve clears the captured solution. Drafts persist as
raw JSON because v1 share codes require an embedded solution proof; only
published/imported levels are stored as codes. Web builds read
`sokode.com/#<code>` fragments client-side and use the memory repository
(no dart:io).
```

- [ ] **Step 4: full gates, push, PR** — core gates from `packages/sokode_core`, app gates from `app/` (`dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, `flutter build web --release`); then push `feat/03-shells` and `gh pr create --base main` titled `feat: player + maker shells (Plan 03 — spec phases 4-5)`; watch CI. Phase-gate comment is the coordinator's.

---

## Self-Review (completed at authoring time)

- **Spec coverage:** phase 4 (decode → render → play, input, haptics, win) → Tasks 3–6, 9; phase 5 (author, record solve, gate, emit code) → Tasks 10–11; §5 titles → Task 1 (closing the Plan 01 gap); §5 repository seam → Task 7; §8 no-free-text → titles generated, import field is validated-code-only, draft names generated; web fragment (§5 web) → Task 12; E2E acceptance → Task 12's roundtrip test.
- **Placeholder scan:** widget-layout freedom is explicitly bounded and contracted by literal tests (deliberate, documented in the header) — no TBDs.
- **Type consistency:** `PlayerSession.moves`/`onSolvedWithMoves`, `MakerScreen.editorOf`, `MemoryLevelRepository`, `StoredCode.kind` values ('mine'/'imported'), and widget `ValueKey` names are used identically across Tasks 5–12.
- **Known risks for executors:** Task 11/12's `editorOf` test hook needs constructor injection — flagged in-task; `path_provider` needs the conditional-import stub for web — flagged in-task; PlayerScreen keyboard tests need `flutter/services.dart` — imported in the literal test code.
