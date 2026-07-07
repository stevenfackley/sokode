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
