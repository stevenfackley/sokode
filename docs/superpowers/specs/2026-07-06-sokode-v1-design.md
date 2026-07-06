# Sokode v1 — Design Spec

**Date:** 2026-07-06
**Status:** Approved (brainstorming red-team pass complete)
**Product:** Sokode — a deterministic grid puzzle maker + player (Sokoban+), sharing levels as self-verifying codes. No server in v1.
**Stack:** Flutter + Dart (iOS, Android, Web). Repo: `stevenfackley/sokode`.

This spec is the source document derived from the "Fable Implementation Playbook — Deterministic Grid Puzzle Maker (v1)". Where this spec and the playbook differ, **this spec wins**. The playbook's operating contract (SOLID, typed errors, docstrings, phase gates, trade-offs stated) carries over unchanged.

---

## 1. Red-team deltas from the playbook

Four decisions changed or pinned during design review:

1. **Proof-carrying share codes.** The playbook verified solutions only at publish time on the author's device — a hand-crafted code could still encode an impossible level. v1 instead **embeds the author's solution replay in the share code** and **re-verifies it on import** through the same `Simulation`. A code without a passing embedded solution is rejected. Cost: longer codes (~2 bits/move), solutions extractable (accepted spoiler risk).
2. **Stack: Flutter + Dart** (over Godot 4 + C# and .NET MAUI). Pure Dart core package with zero Flutter imports; web export is load-bearing (see 3).
3. **Name: Sokode** (Sokoban + code). Verified available 2026-07-06: `sokode.com` and `sokode.app` domains free, no App Store / Play Store / GitHub collisions. **Action item: register sokode.com + sokode.app promptly — availability is perishable.**
4. **Web player ships in v1** (playbook justified Flutter via a web landing page but never scheduled it). Static Flutter web build on Cloudflare Pages at sokode.com; codes are shareable as `sokode.com/#<code>`.

---

## 2. Architecture

### 2.1 Packages

```
sokode/
  packages/sokode_core/    # pure Dart, ZERO Flutter imports (CI-enforced)
    lib/src/
      grid_state.dart      # immutable, integer-only board
      ruleset.dart         # RuleSet interface
      sokoban_plus.dart    # v1 implementation
      simulation.dart      # single source of truth for applying actions
      level_codec.dart     # encode / decode (Result<Level, DecodeError>)
      replay_verifier.dart # (level, moves) -> VerifyResult
      level_validator.dart # bounds / structural checks
      title_generator.dart # deterministic word-pair title from level hash
  app/                     # Flutter shell
    lib/
      render/              # CustomPainter grid; no game rules
      input/               # swipe + arrow keys -> actions
      screens/             # player, maker, level list
      store/               # LevelRepository interface + JSON-file impl
```

- The shell depends on the core; the core never depends on the shell. A core test scans `sokode_core`'s imports and fails on any `package:flutter` reference.
- `RuleSet` interface: `step(state, action) -> StepResult`, `isSolved(state)`, `legalActions(state)`, `validateStructure(level)`. Trade-off: a small "fat" interface over capability composition — one implementer in v1 makes composition machinery without a customer. Revisit when a second ruleset (Baba-style / nonogram) arrives.

### 2.2 Determinism contract

Unchanged from playbook §3.2 and binding: integer-only logic, no floats, no ambient randomness (injected seeded PRNG only), no hash-map iteration order affecting state, and **one** `Simulation` code path shared by play, import verification, and publish. A test hashes end-of-replay state and asserts stability.

### 2.3 Sokoban+ semantics (pinned)

The playbook left these ambiguous; they are now normative:

- **Actions:** U/D/L/R only (2 bits each). **Undo/reset are shell concerns** — the recorded replay is the final action sequence; undone moves never appear in it. Undo is not in the replay alphabet.
- **Core move:** player moves 4-directionally; pushes exactly one crate into floor/target (never into wall, crate, closed gate, or off-board). Win when every target is covered by a crate.
- **One-way tiles constrain entry only**, applying equally to the player and to pushed crates (a crate may only enter a one-way tile if the push direction matches the arrow). Exit in any direction is legal.
- **Switches toggle on enter:** a player or crate *arriving* on a switch fires the toggle for its channel (A or B). No continuous-pressure state.
- **Gates:** closed gate = wall; open gate = floor. **A toggle never closes an occupied gate** — that gate stays open; there is no queued/pending close. Trade-off: slightly less puzzle expressiveness for zero deferred state.
- **Initial placement fires nothing:** a player or crate that *starts* on a switch does not trigger a toggle; toggles fire only on enter-during-play.
- Extension budget is exactly these two mechanics (one-ways + switch/gate channels A and B). Anything more is a phase-gate discussion.

---

## 3. Share-code format (normative summary for ENCODING.md)

Binary payload, then **base64url without padding**. Layout:

```
magic "SK" (2 bytes)
version   u8   (= 1)
ruleset   u8   (= 1, Sokoban+)
flags     u8   (bit0: hasSolution — required for shared/published codes)
width     u8   (4..=32)
height    u8   (4..=32)
tiles     4 bits/cell, row-major, 13-entry palette (3 nibble values reserved):
          floor, wall, target, oneway-N/E/S/W, switch-A, switch-B,
          gate-A-open, gate-A-closed, gate-B-open, gate-B-closed
player    u16 cell index
crates    u8 count, then u16 indexes, sorted ascending (canonicalization)
solution  u16 move count (cap 4096), then 2 bits/move packed
checksum  CRC32 over everything above
```

Rules:

- **Caps before allocation.** Read width/height → bounds-check → compute expected payload length → reject on any mismatch. No allocation is sized from untrusted data before validation.
- **Canonical encode:** fixed field order + sorted crate indexes ⇒ same level always yields the same code (golden tests depend on this).
- **CRC32, not a cryptographic hash — deliberately.** It detects corruption. Tamper-resistance without a server key is impossible; a SHA-256 here would be security theater. Stated plainly in SECURITY.md.
- **Typed `DecodeError`** (sealed): `badCharset, truncated, badMagic, unsupportedVersion, unsupportedRuleset, dimensionOutOfBounds, payloadLengthMismatch, badChecksum, invalidTile, entityOutOfBounds, solutionTooLong, missingSolution`. `decode` is total: it never throws on hostile input.
- **`flags` bit0 (`hasSolution`) MUST be 1 in v1.** A code without an embedded solution decodes to `missingSolution` — there is no legal proof-free code in v1. Bit0=0 is reserved for a possible future draft-sharing mode; the other flag bits are reserved and must be 0.
- **Versioning:** unknown/newer version ⇒ `unsupportedVersion`, never a guess. Future versions must keep decoding v1 codes.
- **No compression in v1.** Realistic 16×16 level + 200-move solution ≈ 260 chars — paste-able, fine as a URL. RLE is a v2 flag if needed. Trade-off: bigger codes now, smaller fuzz surface.

---

## 4. Publish gate & threat model (normative summary for SECURITY.md)

Import pipeline — all stages mandatory, same `Simulation` as play:

```
decode(code) → LevelValidator.validateStructure → ReplayVerifier.verify(embedded solution) → playable
```

- Publishing without a passing verification is impossible by construction (maker records the solve; encode requires it).
- **Importing** an impossible or forged level is also impossible: no valid embedded proof ⇒ typed rejection. This closes the playbook's gap.
- Replay ceiling 4096 moves caps verification cost. Verification of a max-size level is trivial CPU (≤4096 steps on a ≤1024-cell grid).
- `validateStructure` (Sokoban+) requires: exactly one player (guaranteed by format), targets ≥ 1, crates ≥ targets, all entity indexes in bounds, and no entity on a wall or closed gate.
- Accepted residual risks (documented, not hidden): solutions extractable from codes (spoilers); a modified client can bypass anything locally (affects only the cheater); codes are unauthenticated (anyone can mint valid codes — by design, there is no server).
- No secrets in the client, ever. Future ad/analytics/backend keys are server-side; the config seam carries a comment saying so.

---

## 5. Shell & UX

- **Player:** paste/open code → decode+verify → render grid (CustomPainter) → swipe or arrow keys → tween-on-move + haptic → win state. Undo + reset buttons.
- **Maker:** paint tiles from a palette, place player/crates/targets → test-play records the solution → publish runs the gate → emits code + OS share sheet.
- **Level list:** seeded packs (~20–30 authored levels, playable offline on fresh install), imported levels, my levels. Backed by a `LevelRepository` interface over JSON files (path_provider) — the repository interface is the future-backend seam. Trade-off: JSON over sqlite — level counts are tiny; the interface hides the choice.
- **Titles:** deterministic word-pair from the level hash ("Brave Crate") off fixed word lists. No free-text input anywhere in the app (moderation-by-construction).
- **Web:** the same Flutter app built for web, deployed to Cloudflare Pages, domain sokode.com. Codes travel as `sokode.com/#<code>` — the URL **fragment** never reaches the server, so shared levels don't appear in access logs (privacy by construction). App builds read the code from the fragment on launch.

Non-goals unchanged from playbook §1: no backend, no accounts, no discovery/feed, no ads/analytics/IAP (seams only), no animation framework.

---

## 6. CI & repo conventions

- Repo-local GitHub Actions (the reusable `gh-actions` platform has no Flutter workflow yet; promote to `ci-flutter` only if a second Flutter repo appears): `dart analyze` (strict lints), core tests with coverage, shell tests, core-import-boundary check, `flutter build web` + `flutter build apk` smoke.
- Workspace rules: feature branches + PR + squash merge; Conventional Commits; **no AI attribution trailers**.
- Property-based testing via `glados` or equivalent; fuzz corpus for the codec lives in the repo.

---

## 7. Phases

Playbook phases 0–7 carry over with two amendments:

| Phase | Delta |
|---|---|
| 0 — Scaffold | Stack already decided (Flutter). Acceptance unchanged: CI green on empty test; core-import lint in place. |
| 1 — Core sim | Includes pinned semantics of §2.3; property + golden tests. |
| 2 — Codec | **Includes the solution section** (§3); roundtrip property test, fuzz suite asserting typed errors, size caps. |
| 3 — Verifier + Validator | Import pipeline of §4; determinism hash test. |
| 4 — Player shell | Unchanged. |
| 5 — Maker shell | Unchanged; end-to-end author → verify → encode → decode → play → win. |
| 6 — Seed content | ~20–30 authored levels; first-run onboarding; word-list titles. |
| **6.5 — Web deploy** | **New.** Cloudflare Pages, sokode.com, fragment-code import verified end-to-end from a real shared URL. |
| 7 — Self-review | Unchanged (complexity hotspots, coverage of core, doc completeness, residual risks). |

Each phase ends with the playbook's PHASE GATE report: built / decisions+trade-offs / assumptions / test results / defer-descope.

## 8. Documentation deliverables

Unchanged from playbook §7: `ARCHITECTURE.md`, `ENCODING.md` (write before Phase 2; §3 above is its skeleton), `SECURITY.md` (§4 skeleton), `README.md`. Docstrings on every public API: params, return, errors, invariants.

## 9. Definition of done (v1)

Playbook §9, plus: the shared-URL flow works end to end — author a level on device A, share `sokode.com/#<code>`, open on a browser with no prior state, level verifies and plays to a win.

## 10. Open action items

- [ ] Register **sokode.com** and **sokode.app** (user action — availability verified 2026-07-06, perishable).
- [ ] Create GitHub repo `stevenfackley/sokode` at Phase 0; push this branch; PR per workspace rules.
