# Sokode

**Sokoban + code.** A deterministic grid-puzzle maker and player: solve levels, build your own, and share them as self-verifying codes — no server, no accounts, no feed.

Every share code embeds the author's solution replay. The recipient's device re-verifies that proof through the exact simulation used for play before the level becomes playable, so an impossible or corrupted level can't get in. Codes travel as plain text or as `sokode.com/#<code>` links.

## Status

| Milestone | State |
|---|---|
| Core engine (`sokode_core`) — grid, Sokoban+ rules, simulation | ✅ merged (Plan 01) |
| Share-code codec + import gate | ✅ merged (Plan 02) |
| Flutter player + maker shells | ✅ merged (Plan 03) |
| Seed levels + onboarding | ✅ 23 sample levels across 4 packs (Plan 04) |
| Web deploy | ⚙️ workflow ready, waiting on a Cloudflare project |
| sokode.com / sokode.app | ⛔ domains not registered yet |

## Layout

```
packages/sokode_core/   pure Dart engine — zero Flutter imports (CI-enforced)
  tool/                 offline content build: sample levels -> share codes
app/                    Flutter shell (player, maker, level store, samples)
docs/superpowers/       design spec + implementation plans
```

## Build & test

Core — requires Dart SDK ≥ 3.5:

```sh
cd packages/sokode_core
dart pub get
dart format --output=none --set-exit-if-changed .   # format gate (CI step 1)
dart analyze --fatal-infos
dart test
```

App — requires Flutter stable:

```sh
cd app
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
```

CI (`.github/workflows/ci.yml`) runs exactly those commands on every PR.

## Sample levels

The bundled levels are generated, never hand-edited. Author them as ASCII
maps in `packages/sokode_core/tool/seed_catalog.dart`, then:

```sh
cd packages/sokode_core
dart run tool/generate_seed_levels.dart
dart format ../../app/lib/content/seed_levels.dart
```

The generator solves every board breadth-first through the real simulation
and writes proof-carrying share codes. It refuses to write if any level is
unsolvable, structurally invalid, duplicated, fails its own import gate, or
collides with another level's derived title.

## Deploying the web player

`.github/workflows/deploy-web.yml` builds, tests, and direct-uploads to
Cloudflare Pages. It stays skipped until the account is wired up:

```sh
gh variable set CLOUDFLARE_PAGES_PROJECT --body sokode
gh secret set CLOUDFLARE_API_TOKEN      # scope: Cloudflare Pages:Edit
gh secret set CLOUDFLARE_ACCOUNT_ID
```

Attaching `sokode.com` is a manual Cloudflare step and is blocked until the
domain is registered; until then the build lands on `<project>.pages.dev`,
where the `#<code>` share flow behaves identically.

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
