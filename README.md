# Sokode

**Sokoban + code.** A deterministic grid-puzzle maker and player: solve levels, build your own, and share them as self-verifying codes — no server, no accounts, no feed.

Every share code embeds the author's solution replay. The recipient's device re-verifies that proof through the exact simulation used for play before the level becomes playable, so an impossible or corrupted level can't get in. Codes travel as plain text or as `sokode.com/#<code>` links.

## Status

| Milestone | State |
|---|---|
| Core engine (`sokode_core`) — grid, Sokoban+ rules, simulation | ✅ merged (PR #1, 52 tests) |
| Share-code codec + import gate | 📋 planned (`docs/superpowers/plans/…02-codec-gate.md`) |
| Flutter player + maker shells | 📋 planned |
| Seed levels, web player at sokode.com | 📋 planned |

## Layout

```
packages/sokode_core/   pure Dart engine — zero Flutter imports (CI-enforced)
app/                    Flutter shell (player, maker, level store) — Plan 03
docs/superpowers/       design spec + implementation plans
```

## Build & test (core)

Requires Dart SDK ≥ 3.5.

```sh
cd packages/sokode_core
dart pub get
dart format --output=none --set-exit-if-changed .   # format gate (CI step 1)
dart analyze --fatal-infos
dart test
```

CI (`.github/workflows/ci.yml`) runs exactly those four commands on every PR.

## Documents

| Doc | What it is |
|---|---|
| `docs/superpowers/specs/2026-07-06-sokode-v1-design.md` | Approved v1 design — the source of truth |
| `ARCHITECTURE.md` | Core/shell split, determinism contract, pinned Sokoban+ semantics |
| `ENCODING.md` | Share-code wire format (normative) |
| `SECURITY.md` | Threat model and what the design does/doesn't defend against |
| `docs/superpowers/plans/` | Roadmap + per-phase implementation plans |

## Game rules (v1: Sokoban+)

Push crates onto every target to win. Movement is 4-directional; one crate pushed at a time; nothing pulls. The "+" is exactly two mechanics: **one-way tiles** (enterable only along the arrow — applies to the player *and* pushed crates) and **switch/gate channels** (stepping on a switch — player or crate — toggles its channel's gates; a toggle never closes an occupied gate).
