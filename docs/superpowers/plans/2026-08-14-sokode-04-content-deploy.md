# Sokode Plan 04 — Content, Web Deploy & Self-Review

**Goal:** Spec phases 6, 6.5 and 7 — a fresh install that is playable offline out of the box, a web deploy path, and an honest accounting of what v1 does and does not do.

**Spec:** `docs/superpowers/specs/2026-07-06-sokode-v1-design.md` §5–§7. **Prerequisites:** Plans 01–03 merged.

**Branch:** `feat/04-content-deploy`.

**Standing constraints:** pure core / thin shell, determinism contract, Conventional Commits, no AI attribution, format + analyze + test gates in both packages before every push.

---

## Scope split

Phase 6.5 has a hard external dependency: **`sokode.com` and `sokode.app` are not registered** (spec §10 action item, still open). Everything that does not require a purchased domain or a Cloudflare account ships here; the rest is listed under "Blocked" and is a human action, not a coding task.

| # | Task | State |
|---|---|---|
| 1 | Sample level catalog + offline solver/generator | ✅ shipped |
| 2 | Samples tab in the level list | ✅ shipped |
| 3 | First-run onboarding + sticky flag persistence | ✅ shipped |
| 4 | Web app-shell metadata, PWA manifest, response headers | ✅ shipped |
| 5 | Cloudflare Pages deploy workflow (gated, skips until wired) | ✅ shipped |
| 6 | Docs: ARCHITECTURE / SECURITY / README | ✅ shipped |
| 7 | Cloudflare project + secrets, custom domain | ⛔ blocked (human) |
| 8 | Store release prep (bundle id, icons, listings) | ⏭ deferred to a release plan |

---

## Task 1 — Sample levels

**Decision: generate codes, do not hand-write levels.** `packages/sokode_core/tool/seed_catalog.dart` holds 23 levels as ASCII maps; `tool/generate_seed_levels.dart` solves each breadth-first through the production `Simulation` and emits `app/lib/content/seed_levels.dart`.

Trade-offs taken:

- **Codes, not `Level` objects.** A sample and a stranger's paste must be the same kind of thing. `loadSeedLibrary` runs every seed through `LevelImporter` at startup and drops failures, so there is no trusted-content branch that could drift from the path a player's code travels. Cost: one replay per level at launch (23 levels, tens of steps each — unmeasurable).
- **Breadth-first, not a fast Sokoban solver.** Shortest-solution proofs come free, and the solver can only find solutions the real game accepts. Cost: it needs small boards. Every catalog level solves in well under a second; the ceiling is 1.2M states.
- **`tool/` never ships.** It is content authoring, analyzed and formatted by CI but excluded from `lib/`.

The generator is the content gate — it refuses to write on an unsolvable board, a structurally invalid board, a code failing its own import gate, a duplicate level, or two levels whose derived titles collide. `app/test/seed_levels_test.dart` re-runs the import gate on every shipped code in CI.

Packs, easy to hard: **First Steps** (6), **One-Way Streets** (6), **Switches & Gates** (6), **Mixed Bag** (5).

## Task 2 — Samples tab

Level list goes to four scrollable tabs: Samples / Mine / Imported / Drafts. Samples are grouped by pack, numbered within the pack, titled by `titleForLevel`, and annotated with par. Playing a sample does not add it to the library — shipped content is not user content.

## Task 3 — Onboarding

`AppBootstrap` sits above `LevelListScreen` and decides between the walkthrough and the library. Putting the decision above the list screen keeps the list screen free of a first-run branch and keeps every existing widget test constructing it directly. The help button reopens the walkthrough without touching the flag. Any pending web-fragment import waits for the library and then runs through the normal gate.

"Seen" persists via a new opaque `Set<String>` flag store on `LevelRepository` — one method pair rather than a field per feature, and a future backend can return an empty set forever without breaking play.

## Tasks 4–5 — Web

`index.html` / `manifest.json` still carried `flutter create` placeholders. Replaced with real metadata, a cutout-aware viewport, and share-preview tags. `app/web/_headers` ships nosniff / no-referrer / SAMEORIGIN / empty permissions policy and marks the app shell `no-cache`. **No CSP**: the Flutter bootstrap needs wasm compilation and inline module loading, and a policy written without a browser test behind it breaks the renderer unevenly across browsers. Tracked as an open item, not an oversight.

`deploy-web.yml` builds, tests and direct-uploads to Cloudflare Pages, gated on the `CLOUDFLARE_PAGES_PROJECT` repository variable so it skips cleanly rather than failing red before the account exists.

---

## Defect found and fixed en route

`titleForLevel` hashed `stateDigest(GridState.initial(level))`, which fingerprints the **mutable** state only — player cell, crate cells, open gates — and is deliberately blind to the tile grid. Two levels whose entities merely start in the same cells got the same title however different their walls, targets, one-ways and gates were. Four sample levels came out "Ivory Path".

Fixed in `title_generator.dart` by mixing dimensions and every tile nibble on top of the state digest, keeping the same under-2^53 arithmetic so the VM and JS agree. `stateDigest` is untouched: its blindness is correct for the determinism golden test and only wrong for naming a level. Two regression tests pin it.

Two catalog levels also had decorative mechanics — the solver found routes ignoring the gate — and were rewritten until the mechanic was load-bearing. That is the generator earning its keep.

---

## Phase 7 — Self-review

**Complexity hotspots.** `SokobanPlus.step` (branchy but flat, every branch tested) and `decode` (long by necessity — an ordered check list is the point). The shell's largest unit is `LevelListScreen`, now four tabs; if a fifth arrives, split the tab bodies into widgets before adding it.

**Coverage.** Core: 104 tests over semantics, codec roundtrip, fuzz, determinism, import boundary, titles. App: 54 tests over painter, board view, session, player screen, repository, import strings, editor, publish gate, seeds, onboarding, samples, and the full author → publish → re-import → win roundtrip. The untested surface is deliberate: exact widget layout (padding, colors), platform plugin paths (`path_provider`, clipboard), and the generator's rendering.

**Residual risks**, all documented rather than hidden:

1. Codes are unauthenticated and solutions are extractable (SECURITY.md; inherent to a serverless design).
2. No CSP on the web build.
3. Web persistence is in-memory — a browser refresh loses imported and published levels. Acceptable for a share-code-first app where the code is the artifact, but it will surprise someone.
4. Multi-crate tween-on-move can visually swap crates in rare cases (Plan 03, accepted).
5. No progress tracking: solved samples are not marked.

---

## Blocked (human action)

1. **Register `sokode.com` + `sokode.app`.** Availability was verified 2026-07-06 and is perishable. Everything else in phase 6.5 is ready.
2. **Create the Cloudflare Pages project** (direct upload — this workflow should be the only deployer), then set `CLOUDFLARE_PAGES_PROJECT`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.
3. **Verify the acceptance criterion on real hardware**: open a shared `#<code>` URL in a clean browser and play it to a win. It passes as a widget test; the spec asks for the real thing.

## Deferred

- Store release prep: bundle id is still `com.sokode.sokode_app`, icons are `flutter create` defaults.
- `flutter build apk` smoke in CI (spec §6 lists it; only `build web` runs today).
- Progress tracking for samples, and web persistence beyond the in-memory store.
