# Sokode v1 — Plan Roadmap

Spec of record: `docs/superpowers/specs/2026-07-06-sokode-v1-design.md`. Four plans, each independently shippable and testable. Execute in order; each later plan is written only after the previous one merges (its details depend on the real code shapes, not guesses).

| Plan | Spec phases | Scope | Done when |
|---|---|---|---|
| **01 — Core engine** (`2026-07-06-sokode-01-core-engine.md`) | 0, 1 | GitHub repo + CI; pure `sokode_core` package: Direction/Tile/Level/GridState, RuleSet + SokobanPlus (pinned semantics), Simulation, stateDigest; property + golden + import-boundary tests | CI green; all §2.3 semantics covered by tests |
| **02 — Codec + import gate** | 2, 3 | `ENCODING.md` finalized; LevelCodec (binary + base64url, caps-before-allocation, typed DecodeError incl. `missingSolution`); ReplayVerifier + LevelValidator wired into the decode→validate→verify pipeline | Roundtrip property test; fuzz suite (random/truncated/oversized/wrong-version bytes) asserts typed errors, never throws; determinism hash test |
| **03 — Shells** | 4, 5 | Flutter app: player screen (CustomPainter, swipe/keys, undo/reset, haptics), maker screen (palette paint → test-play records solution → publish emits code), LevelRepository (JSON) | Author → verify → encode → decode on fresh instance → play → win, end to end on device |
| **04 — Content + web + review** | 6, 6.5, 7 | 20–30 seeded levels, onboarding, word-list titles; Cloudflare Pages deploy at sokode.com with `#<code>` fragment import; SECURITY.md/README finalized; self-review (complexity, coverage, residual risks) | Fresh install plays offline; a real shared URL opens and verifies in a clean browser |

Standing constraints (all plans): pure core / thin shell, determinism contract (ints only, no ambient randomness, one Simulation code path), feature branches + PR + squash, Conventional Commits, no AI attribution trailers, phase-gate report at each plan's end.
