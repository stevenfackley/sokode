# Sokode Threat Model (v1)

v1 has **no server, no accounts, and no network features**. The entire
attack surface is a string of text: the share code. This document says what
the design defends against, how, and — just as deliberately — what it does
not.

## Assets and trust boundaries

- The only untrusted input is a **share code** (pasted text or a
  `sokode.com/#<code>` URL fragment). Everything after `decode()` is
  derived from it.
- The mobile/web client binary is **not** a trust boundary: anyone can read
  or modify it. Nothing in the design depends on the client keeping a
  secret, and **no secrets ship in the client, ever** — a rule that also
  binds future ad/analytics/backend work (privileged keys live server-side
  or nowhere).

## Defended threats

### 1. Malicious codes as denial-of-service
A code claiming a 10⁶×10⁶ grid or a million-move replay must not crash the
app or exhaust memory/CPU.

- `decode` is **total**: every malformed input maps to a typed
  `DecodeError`; it never throws (fuzz-tested with random strings,
  per-byte corruptions, and every-length truncations).
- **Caps precede allocation** (ENCODING.md check order): dimensions are
  bounds-checked (4..=32) before any tile list exists; payload length must
  match the computed expectation exactly.
- The solution replay is capped at **4096 moves**, rejected before
  simulation — verification cost is bounded at ≤4096 steps on ≤1024 cells.

### 2. Troll levels (impossible / broken puzzles)
Share codes are **proof-carrying**: every code embeds its author's solution
replay, and the *importing* device re-verifies it through the same
`Simulation` used for play (`decode → validateStructure → verify`). A level
without a passing proof never becomes playable. Hand-crafting a valid code
for an unsolvable level is therefore impossible — the forgery fails at the
verify stage on the victim's own device. There is no honor-system gap:
verification at publish time alone would not survive hand-crafted codes.

### 3. Text abuse
There is **no free-text input anywhere** in v1. Level titles are generated
from a fixed word list keyed by the level hash — moderation by
construction; no user text means no text-abuse surface.

### 4. Leaking shared levels to infrastructure
Web links carry the code in the **URL fragment** (`#…`), which browsers do
not send to the server — shared levels don't appear in hosting access logs.

## Accepted residual risks (deliberate non-goals)

- **Codes are unauthenticated.** Anyone can mint a valid code; the CRC32 is
  an integrity check, not a signature. Tamper-resistance without a server
  key is impossible, and pretending otherwise (e.g., an unkeyed SHA-256)
  would be security theater. If v2 adds a backend, signing happens there.
- **Solutions are extractable.** The proof inside a code *is* the solution;
  a determined recipient can decode it and spoil themselves. Acceptable for
  a casual puzzle game.
- **A modified client can cheat locally.** It can skip verification or
  fake wins — affecting only the cheater's own device, since there are no
  leaderboards or shared state in v1.

## Standing rules for future work

1. No secrets in the client. Ad/analytics/feature-flag keys that grant
   privilege belong server-side; the config seam carries this warning.
2. Any new share-code field goes through ENCODING.md first, with typed
   error mapping and cap-before-allocation discipline.
3. Every new mechanic added to a ruleset widens the verification and
   validation surface — the extension budget is a design decision, not a
   code change.
