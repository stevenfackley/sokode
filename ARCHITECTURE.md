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
  evaluated against post-move occupancy. (`SokobanPlus.step`) (observationally
  inert today — toggles never move entities — kept fixed as insurance)
- Undo/reset are shell concerns; replays contain final action sequences
  only (2-bit alphabet: up=0, right=1, down=2, left=3).

## Share-code codec and the import gate (Plan 02)

`ENCODING.md` is the wire-format spec of record. `decode` is total —
13-entry `DecodeError` taxonomy, checks in the documented order, no
allocation sized from unvalidated data (dimension caps precede the tile
read; `Level` is built with exactly width*height tiles, so its length
invariant holds by construction in release builds).

The import pipeline (`LevelImporter`) IS the publish gate: decode →
`validateStructure` → `ReplayVerifier.verify(embedded solution)`, all
through the same `Simulation` as play. Codes are proof-carrying; a forged
impossible level fails at verify. CRC32 is integrity-only by design —
tamper-resistance without a server would be theater (SECURITY.md).

## Shell (Plan 03)

The Flutter app holds zero game rules. `PlayerSession` and `EditorState` are presentation state over core calls; `BoardPainter`/`BoardView` render a `GridState`; `LevelRepository` (interface + JSON-file and in-memory impls) is the future-backend seam.

Publishing is gated twice — the Publish button is disabled until a test-solve is captured, AND publish re-runs the level through the same `LevelImporter` (validate + verify) before saving. Any edit after a test-solve clears the captured solution, so a stale proof can never ship with a changed board.

Levels persist as their own share codes (published and imported), since a code is already canonical and proof-carrying. Maker drafts persist as raw JSON because a v1 code requires an embedded solution, which a draft does not yet have.

Web builds read a `sokode.com/#<code>` fragment client-side (it never reaches the server) and use the in-memory repository — the `dart:io` file repository sits behind a conditional import (`repository_factory_io.dart` vs `_web.dart`) so it never enters the `flutter build web` graph.
