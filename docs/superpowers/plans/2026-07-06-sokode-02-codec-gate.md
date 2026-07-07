# Sokode Plan 02 — Codec + Import Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the share-code codec and the proof-verifying import pipeline (spec phases 2–3): `ENCODING.md`, `LevelCodec`, `ReplayVerifier`, `LevelImporter` — all pure Dart in `sokode_core`.

**Architecture:** Binary payload → base64url (no padding). `decode` is total: every hostile input maps to a typed `DecodeError`, never an exception, and no allocation is sized from unvalidated data. The import pipeline `decode → validateStructure → verify(embedded solution)` is the publish gate (spec §4) — same `Simulation` as play.

**Tech Stack:** Dart 3 stable, `package:test`, zero new dependencies (CRC32 implemented in-package; base64 via `dart:convert`).

**Spec:** `docs/superpowers/specs/2026-07-06-sokode-v1-design.md` §3–§4. **Prerequisite:** Plan 01 merged (Direction/Tile/Level/GridState/SokobanPlus/Simulation exist with the exact APIs Plan 01 defined).

**Branch:** create `feat/02-codec` from `main` (after the Plan 01 PR merges). Work from `C:\Users\steve\projects\sokode`; run dart commands from `packages/sokode_core`. Use the PowerShell tool (the Bash tool has a broken PATH in this environment).

**Formatting rule (lesson from Plan 01 execution):** this plan's code blocks may not match the Dart ≥3.7 "tall" formatter exactly. **The formatter always wins.** Every commit step runs `dart format .` and then verifies the exact CI gate: `dart format --output=none --set-exit-if-changed .` must exit 0 before `git commit`. Never hand-match the plan's whitespace against the formatter.

**Two spec addenda this plan introduces** (record in ENCODING.md; they refine spec §3 without contradicting it):
1. `DecodeError.reservedFlagBits` — flags bits 1–7 must be 0; a nonzero reserved bit is its own typed error (not `unsupportedVersion`).
2. Canonical padding — the unused low nibble of an odd-cell-count tile section must be 0 (else `invalidTile`); unused 2-bit slots in the final solution byte must be 0 (else `payloadLengthMismatch`).

---

## File Structure

```
packages/sokode_core/
  lib/src/crc32.dart                 # CRC-32 IEEE, table-driven, web-safe
  lib/src/decode_error.dart          # DecodeError enum + DecodeOutcome sealed types
  lib/src/level_codec.dart           # encode()/decode() + protocol constants
  lib/src/replay_verifier.dart       # VerifyResult sealed types + ReplayVerifier
  lib/src/level_import.dart          # ImportOutcome sealed types + LevelImporter
  test/crc32_test.dart
  test/codec_encode_test.dart
  test/codec_decode_test.dart
  test/codec_errors_test.dart
  test/codec_property_test.dart      # roundtrip + fuzz
  test/replay_verifier_test.dart
  test/level_import_test.dart
  test/helpers/seal_code.dart        # test-only: raw byte vectors -> code string
  test/helpers/random_valid_level.dart
ENCODING.md                          # normative wire-format spec (repo root)
ARCHITECTURE.md                      # append codec section (Task 9)
```

---

### Task 1: ENCODING.md (the spec of record — write before any code)

**Files:**
- Create: `ENCODING.md` (repo root)

- [ ] **Step 1: Write the document**

```markdown
# Sokode Share-Code Format (v1)

Normative spec for `sokode_core`'s `level_codec.dart`. A share code is a
binary payload encoded as **base64url without padding** (RFC 4648 §5,
alphabet `A-Z a-z 0-9 - _`, no `=`). All multi-byte integers are
**big-endian**. Decoders MUST treat input as hostile: every failure maps to
a typed `DecodeError`; decoding never throws and never allocates from
unvalidated sizes.

## Byte layout

| Offset | Size | Field | Rules |
|---|---|---|---|
| 0 | 2 | magic | `0x53 0x4B` ("SK") |
| 2 | 1 | version | `1`. Unknown value → `unsupportedVersion`. |
| 3 | 1 | ruleset | `1` = Sokoban+. Unknown → `unsupportedRuleset`. |
| 4 | 1 | flags | bit0 `hasSolution` MUST be 1 (else `missingSolution`). Bits 1–7 reserved, MUST be 0 (else `reservedFlagBits`). |
| 5 | 1 | width | 4..=32 (else `dimensionOutOfBounds`) |
| 6 | 1 | height | 4..=32 (else `dimensionOutOfBounds`) |
| 7 | ⌈w·h/2⌉ | tiles | 4 bits/cell, row-major. Even cell index = HIGH nibble. Nibble values are `Tile.nibble` (0–12); 13–15 → `invalidTile`. If w·h is odd, the final LOW nibble is padding and MUST be 0 (else `invalidTile`). |
| — | 2 | player | cell index, < w·h (else `entityOutOfBounds`) |
| — | 1 | crateCount | 0–255 (structural minimums are the validator's job, not the codec's) |
| — | 2·n | crateIndexes | each < w·h (else `entityOutOfBounds`). Encoders MUST emit ascending order; decoders accept any order (Level canonicalizes) — duplicates are caught by the validator, not the codec. |
| — | 2 | moveCount | 0 → `missingSolution`; > 4096 → `solutionTooLong` |
| — | ⌈m/4⌉ | moves | 2 bits/move, `Direction.encoding`, move j in bits `6−2·(j mod 4)` of byte ⌊j/4⌋ (high-to-low). Unused trailing 2-bit slots MUST be 0 (else `payloadLengthMismatch`). |
| — | 4 | crc32 | CRC-32/ISO-HDLC (IEEE 802.3, reflected poly `0xEDB88320`, init & xorout `0xFFFFFFFF`) over ALL preceding bytes. Mismatch → `badChecksum`. |

After the moves section, exactly the 4 CRC bytes must remain; any surplus →
`payloadLengthMismatch`.

## Decode check order (normative)

1. Charset: string non-empty, only base64url chars → else `badCharset`
2. base64url decode (re-pad internally) → failure = `badCharset`
3. Total length ≥ 11 (7-byte header + 4-byte CRC) → else `truncated`
4. Magic → `badMagic`
5. CRC over `bytes[0..len−5]` vs trailer → `badChecksum`
6. version → `unsupportedVersion`; ruleset → `unsupportedRuleset`
7. flags: bit0 → `missingSolution`; bits 1–7 → `reservedFlagBits`
8. width/height caps → `dimensionOutOfBounds`
9. Sequential parse (tiles → player → crates → moves); any read past the
   pre-CRC end → `truncated`; per-field rules per the table above
10. Zero leftover bytes → else `payloadLengthMismatch`

Dimensions are validated at step 8, BEFORE the ⌈w·h/2⌉ tile allocation —
a code claiming 10⁶×10⁶ dies at a byte compare, not at allocation. The
decoder builds `Level` with a tile list of exactly w·h entries, so
`Level`'s length invariant holds by construction in release builds.

## Canonical encoding

`encode` is deterministic: fixed field order, crate indexes ascending
(guaranteed by `Level`), zero padding nibbles/bits, no base64 `=` padding.
Same (level, solution) → same code string, always. Makers SHOULD trim the
solution at the first winning move before encoding (the verifier accepts
early wins either way).

## Compatibility policy

- A v1 decoder rejects any other version with `unsupportedVersion` — it
  never guesses.
- Future format versions MUST keep decoding v1 codes byte-for-byte as
  specified here.
- New mechanics that need new tile kinds use nibbles 13–15 and/or a version
  bump; v1 decoders will reject them typed, not crash.

## DecodeError (closed set, v1)

`badCharset, truncated, badMagic, unsupportedVersion, unsupportedRuleset,
reservedFlagBits, missingSolution, dimensionOutOfBounds,
payloadLengthMismatch, badChecksum, invalidTile, entityOutOfBounds,
solutionTooLong`

## What the codec does NOT check

Structural validity (≥1 target, crates ≥ targets, entities on legal tiles,
duplicates, player-on-crate) is `RuleSet.validateStructure`'s job, and
solvability proof is `ReplayVerifier`'s — both run in the import pipeline
(`LevelImporter`) after a successful decode. The CRC is integrity only;
without a server there is no tamper-resistance, by design (see SECURITY.md).
```

- [ ] **Step 2: Commit**

```bash
git add ENCODING.md
git commit -m "docs: add share-code wire format spec (ENCODING.md)"
```

---

### Task 2: CRC32

**Files:**
- Create: `packages/sokode_core/lib/src/crc32.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/crc32_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';

import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

void main() {
  test('standard check vector: "123456789" -> 0xCBF43926', () {
    expect(crc32(utf8.encode('123456789')), 0xCBF43926);
  });

  test('empty input -> 0', () {
    expect(crc32(const []), 0);
  });

  test('classic pangram vector', () {
    expect(
      crc32(utf8.encode('The quick brown fox jumps over the lazy dog')),
      0x414FA339,
    );
  });

  test('result is a 32-bit unsigned value', () {
    final value = crc32(List<int>.filled(1000, 0xFF));
    expect(value, inInclusiveRange(0, 0xFFFFFFFF));
  });
}
```

- [ ] **Step 2: Run to verify it fails** — from `packages/sokode_core`: `dart test test/crc32_test.dart` → FAIL (crc32 undefined).

- [ ] **Step 3: Implement**

`lib/src/crc32.dart`:

```dart
/// CRC-32/ISO-HDLC (IEEE 802.3): reflected polynomial 0xEDB88320,
/// init 0xFFFFFFFF, final xor 0xFFFFFFFF. Table-driven.
///
/// Deliberately dependency-free and web-safe: every intermediate stays
/// within 32 bits (no multiplications), so results are identical on the
/// Dart VM and compiled to JS. Integrity check only — NOT tamper-proof
/// (see SECURITY.md).
final List<int> _crcTable = _buildCrcTable();

List<int> _buildCrcTable() {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c;
  }
  return table;
}

/// CRC-32 of [bytes]. Each element is masked to 8 bits.
int crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
```

Append to `lib/sokode_core.dart`: `export 'src/crc32.dart';`

- [ ] **Step 4: Run to verify it passes** — `dart test test/crc32_test.dart` → PASS.

- [ ] **Step 5: Format-gate and commit**

```bash
dart format .
dart format --output=none --set-exit-if-changed .   # must exit 0
git add -A
git commit -m "feat: add web-safe CRC-32"
```

---

### Task 3: Decode types + protocol constants

**Files:**
- Create: `packages/sokode_core/lib/src/decode_error.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/codec_decode_test.dart` (started here, grown in Tasks 5–6)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

void main() {
  test('DecodeError is the closed 13-error set from ENCODING.md', () {
    expect(DecodeError.values, const [
      DecodeError.badCharset,
      DecodeError.truncated,
      DecodeError.badMagic,
      DecodeError.unsupportedVersion,
      DecodeError.unsupportedRuleset,
      DecodeError.reservedFlagBits,
      DecodeError.missingSolution,
      DecodeError.dimensionOutOfBounds,
      DecodeError.payloadLengthMismatch,
      DecodeError.badChecksum,
      DecodeError.invalidTile,
      DecodeError.entityOutOfBounds,
      DecodeError.solutionTooLong,
    ]);
  });

  test('outcome types carry their payloads', () {
    const failure = DecodeFailure(DecodeError.badMagic);
    expect(failure.error, DecodeError.badMagic);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/codec_decode_test.dart` → FAIL.

- [ ] **Step 3: Implement**

`lib/src/decode_error.dart`:

```dart
import 'direction.dart';
import 'level.dart';

/// Every way an untrusted share code can fail to decode. Closed set —
/// ENCODING.md is the normative mapping. `decode` is total: hostile input
/// yields exactly one of these; it never throws.
enum DecodeError {
  badCharset,
  truncated,
  badMagic,
  unsupportedVersion,
  unsupportedRuleset,
  reservedFlagBits,
  missingSolution,
  dimensionOutOfBounds,
  payloadLengthMismatch,
  badChecksum,
  invalidTile,
  entityOutOfBounds,
  solutionTooLong,
}

/// Result of decoding a share code. Sealed: switches are exhaustive.
sealed class DecodeOutcome {
  const DecodeOutcome();
}

/// Structurally well-formed code. NOT yet validated or solvability-proven —
/// that is LevelImporter's job (decode -> validateStructure -> verify).
class DecodeSuccess extends DecodeOutcome {
  const DecodeSuccess(this.level, this.solution);

  final Level level;

  /// The author's embedded solution replay (1..=4096 moves).
  final List<Direction> solution;
}

/// The code is rejected; [error] says exactly why (ENCODING.md mapping).
class DecodeFailure extends DecodeOutcome {
  const DecodeFailure(this.error);

  final DecodeError error;
}
```

Append to `lib/sokode_core.dart`: `export 'src/decode_error.dart';`

- [ ] **Step 4: Run to verify it passes** — `dart test test/codec_decode_test.dart` → PASS.

- [ ] **Step 5: Format-gate and commit**

```bash
dart format .
dart format --output=none --set-exit-if-changed .
git add -A
git commit -m "feat: add DecodeError taxonomy and decode outcome types"
```

---

### Task 4: Encoder

**Files:**
- Create: `packages/sokode_core/lib/src/level_codec.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/codec_encode_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';

import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

Level goldenLevel() => levelFromAscii([
      '######',
      r'#@$ .#',
      '#    #',
      '######',
    ]);

const goldenSolution = [Direction.right, Direction.right];

void main() {
  test('encode is deterministic (canonical)', () {
    expect(encode(goldenLevel(), goldenSolution),
        encode(goldenLevel(), goldenSolution));
  });

  test('output is base64url without padding', () {
    final code = encode(goldenLevel(), goldenSolution);
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code), isTrue);
    expect(code.contains('='), isFalse);
  });

  test('byte structure: header fields and trailing CRC are correct', () {
    final code = encode(goldenLevel(), goldenSolution);
    final bytes =
        base64Url.decode(code.padRight((code.length + 3) & ~3, '='));
    expect(bytes[0], 0x53); // 'S'
    expect(bytes[1], 0x4B); // 'K'
    expect(bytes[2], 1); // version
    expect(bytes[3], 1); // ruleset
    expect(bytes[4], 1); // flags: hasSolution only
    expect(bytes[5], 6); // width
    expect(bytes[6], 4); // height
    final body = bytes.sublist(0, bytes.length - 4);
    final stored = (bytes[bytes.length - 4] << 24) |
        (bytes[bytes.length - 3] << 16) |
        (bytes[bytes.length - 2] << 8) |
        bytes[bytes.length - 1];
    expect(crc32(body), stored);
    // 7 header + 12 tiles (24 cells) + 2 player + 1 count + 2 crate
    // + 2 moveCount + 1 moves (2 moves) + 4 crc = 31
    expect(bytes.length, 31);
  });

  test('GOLDEN: pinned code string', () {
    // GOLDEN-PIN PROCEDURE: literal starts as '' and the test FAILS,
    // printing the actual code. Pin it, rerun, commit. A future change to
    // this string is a wire-format break — never re-pin casually.
    final actual = encode(goldenLevel(), goldenSolution);
    printOnFailure('actual code: $actual');
    expect(actual, '');
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/codec_encode_test.dart` → FAIL (encode undefined).

- [ ] **Step 3: Implement**

`lib/src/level_codec.dart` (decode lands in Task 5 — this task is encode + constants only):

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'crc32.dart';
import 'decode_error.dart';
import 'direction.dart';
import 'level.dart';
import 'tile.dart';

/// Protocol constants — wire format, never tune at runtime (ENCODING.md).
const int codecVersion = 1;
const int codecRulesetSokobanPlus = 1;
const int codecMinDimension = 4;
const int codecMaxDimension = 32;
const int codecMaxSolutionMoves = 4096;

/// Encodes a level + its solution replay into a canonical share code.
///
/// Canonical: same input always yields the same string (fixed field order,
/// Level's sorted crates, zero padding, no base64 `=`).
///
/// Total for in-contract input; asserts (debug-only) the bounds it owns:
/// dimensions within caps, entity indexes in range, solution length
/// 1..=4096. Structural validity and solvability are the import pipeline's
/// concern, not the codec's (ENCODING.md "What the codec does NOT check").
String encode(Level level, List<Direction> solution) {
  assert(level.width >= codecMinDimension &&
      level.width <= codecMaxDimension &&
      level.height >= codecMinDimension &&
      level.height <= codecMaxDimension);
  assert(solution.isNotEmpty && solution.length <= codecMaxSolutionMoves);
  assert(level.playerIndex >= 0 && level.playerIndex < level.cellCount);
  assert(level.crateIndexes.every((c) => c >= 0 && c < level.cellCount));
  assert(level.crateIndexes.length <= 255);

  final bytes = BytesBuilder();
  bytes.add(const [0x53, 0x4B, codecVersion, codecRulesetSokobanPlus, 0x01]);
  bytes.addByte(level.width);
  bytes.addByte(level.height);
  for (var i = 0; i < level.cellCount; i += 2) {
    final high = level.tiles[i].nibble;
    final low = i + 1 < level.cellCount ? level.tiles[i + 1].nibble : 0;
    bytes.addByte((high << 4) | low);
  }
  _addU16(bytes, level.playerIndex);
  bytes.addByte(level.crateIndexes.length);
  for (final crate in level.crateIndexes) {
    _addU16(bytes, crate);
  }
  _addU16(bytes, solution.length);
  for (var j = 0; j < solution.length; j += 4) {
    var packed = 0;
    for (var k = 0; k < 4 && j + k < solution.length; k++) {
      packed |= solution[j + k].encoding << (6 - 2 * k);
    }
    bytes.addByte(packed);
  }
  final body = bytes.toBytes();
  final builder = BytesBuilder()..add(body);
  _addU32(builder, crc32(body));
  return base64Url.encode(builder.toBytes()).replaceAll('=', '');
}

void _addU16(BytesBuilder bytes, int value) {
  bytes.addByte((value >> 8) & 0xFF);
  bytes.addByte(value & 0xFF);
}

void _addU32(BytesBuilder bytes, int value) {
  bytes.addByte((value >>> 24) & 0xFF);
  bytes.addByte((value >>> 16) & 0xFF);
  bytes.addByte((value >>> 8) & 0xFF);
  bytes.addByte(value & 0xFF);
}
```

(The `decode_error.dart`, `Uint8List` imports are used by Task 5's decode — if the analyzer flags them as unused in this task, keep only what compiles clean now and add the rest in Task 5; `--fatal-infos` must stay green at every commit.)

Append to `lib/sokode_core.dart`: `export 'src/level_codec.dart';`

- [ ] **Step 4: Pin the golden value** — run the test; the golden test fails printing the actual code. Replace `''` with it. Rerun → PASS.

- [ ] **Step 5: Format-gate and commit**

```bash
dart format .
dart format --output=none --set-exit-if-changed .
git add -A
git commit -m "feat: implement canonical share-code encoder"
```

---

### Task 5: Decoder (happy path)

**Files:**
- Modify: `packages/sokode_core/lib/src/level_codec.dart`
- Create: `packages/sokode_core/test/helpers/seal_code.dart`
- Test: `packages/sokode_core/test/codec_decode_test.dart` (extend Task 3's file)

- [ ] **Step 1: Write the sealing helper** (test-only; used heavily by Task 6's error vectors)

`test/helpers/seal_code.dart`:

```dart
import 'dart:convert';

import 'package:sokode_core/sokode_core.dart';

/// Appends a CRC32 trailer to [body] (optionally corrupted by [crcDelta])
/// and base64url-encodes without padding — for hand-crafting hostile
/// decode vectors.
String sealCode(List<int> body, {int crcDelta = 0}) {
  final crc = (crc32(body) + crcDelta) & 0xFFFFFFFF;
  final bytes = [
    ...body,
    (crc >>> 24) & 0xFF,
    (crc >>> 16) & 0xFF,
    (crc >>> 8) & 0xFF,
    crc & 0xFF,
  ];
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Big-endian u16 as two bytes — vector-building convenience.
List<int> u16(int value) => [(value >> 8) & 0xFF, value & 0xFF];

/// Decodes a share-code string back to raw bytes (for mutation tests).
List<int> rawBytes(String code) =>
    base64Url.decode(code.padRight((code.length + 3) & ~3, '='));
```

- [ ] **Step 2: Extend the test file with failing happy-path tests** (append to `test/codec_decode_test.dart`; add imports `'helpers/ascii_level.dart'` — and reuse `goldenLevel`/`goldenSolution` by copying those two declarations from `codec_encode_test.dart` into this file's top level):

```dart
  test('decode(encode(x)) reproduces level and solution exactly', () {
    final level = goldenLevel();
    final outcome = decode(encode(level, goldenSolution));
    final success = outcome as DecodeSuccess;
    expect(success.level.width, level.width);
    expect(success.level.height, level.height);
    expect(success.level.tiles, level.tiles);
    expect(success.level.playerIndex, level.playerIndex);
    expect(success.level.crateIndexes, level.crateIndexes);
    expect(success.solution, goldenSolution);
  });

  test('decode accepts non-canonical crate order (Level re-sorts)', () {
    // Encode a 2-crate level, swap the two crate index fields in the raw
    // bytes, re-seal, decode: same level, canonical order restored.
    final level = levelFromAscii([
      '######',
      r'#@$$.#',
      '#   .#',
      '######',
    ]);
    final code = encode(level, const [Direction.right]);
    final bytes = rawBytes(code);
    final body = bytes.sublist(0, bytes.length - 4);
    // tiles: 24 cells -> 12 bytes; crateCount at 7+12+2=21; crates at 22..25
    final tmp1 = body[22], tmp2 = body[23];
    body[22] = body[24];
    body[23] = body[25];
    body[24] = tmp1;
    body[25] = tmp2;
    final swapped = sealCode(body);
    final success = decode(swapped) as DecodeSuccess;
    expect(success.level.crateIndexes, level.crateIndexes);
  });
```

- [ ] **Step 3: Run to verify it fails** — `dart test test/codec_decode_test.dart` → FAIL (decode undefined).

- [ ] **Step 4: Implement** — append to `lib/src/level_codec.dart`:

```dart
/// Decodes an untrusted share code (ENCODING.md check order). Total:
/// returns DecodeFailure for every malformed input, never throws, and
/// never allocates from unvalidated sizes — dimensions are cap-checked
/// before the tile list exists, and the Level is built with exactly
/// width*height tiles (its length invariant holds by construction).
DecodeOutcome decode(String code) {
  if (code.isEmpty || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code)) {
    return const DecodeFailure(DecodeError.badCharset);
  }
  final Uint8List data;
  try {
    data = base64Url.decode(code.padRight((code.length + 3) & ~3, '='));
  } on FormatException {
    return const DecodeFailure(DecodeError.badCharset);
  }
  if (data.length < 11) return const DecodeFailure(DecodeError.truncated);
  if (data[0] != 0x53 || data[1] != 0x4B) {
    return const DecodeFailure(DecodeError.badMagic);
  }
  final body = Uint8List.sublistView(data, 0, data.length - 4);
  final storedCrc = (data[data.length - 4] << 24) |
      (data[data.length - 3] << 16) |
      (data[data.length - 2] << 8) |
      data[data.length - 1];
  if (crc32(body) != storedCrc) {
    return const DecodeFailure(DecodeError.badChecksum);
  }
  if (data[2] != codecVersion) {
    return const DecodeFailure(DecodeError.unsupportedVersion);
  }
  if (data[3] != codecRulesetSokobanPlus) {
    return const DecodeFailure(DecodeError.unsupportedRuleset);
  }
  final flags = data[4];
  if (flags & 0x01 == 0) {
    return const DecodeFailure(DecodeError.missingSolution);
  }
  if (flags & 0xFE != 0) {
    return const DecodeFailure(DecodeError.reservedFlagBits);
  }
  final width = data[5];
  final height = data[6];
  if (width < codecMinDimension ||
      width > codecMaxDimension ||
      height < codecMinDimension ||
      height > codecMaxDimension) {
    return const DecodeFailure(DecodeError.dimensionOutOfBounds);
  }
  final reader = _ByteReader(body, 7);
  final cellCount = width * height;
  final tileBytes = reader.readBytes((cellCount + 1) >> 1);
  if (tileBytes == null) return const DecodeFailure(DecodeError.truncated);
  final tiles = <Tile>[];
  for (var i = 0; i < cellCount; i++) {
    final byte = tileBytes[i >> 1];
    final nibble = i.isEven ? byte >> 4 : byte & 0x0F;
    final tile = Tile.fromNibble(nibble);
    if (tile == null) return const DecodeFailure(DecodeError.invalidTile);
    tiles.add(tile);
  }
  if (cellCount.isOdd && (tileBytes[tileBytes.length - 1] & 0x0F) != 0) {
    return const DecodeFailure(DecodeError.invalidTile);
  }
  final playerIndex = reader.readU16();
  if (playerIndex == null) return const DecodeFailure(DecodeError.truncated);
  if (playerIndex >= cellCount) {
    return const DecodeFailure(DecodeError.entityOutOfBounds);
  }
  final crateCount = reader.readU8();
  if (crateCount == null) return const DecodeFailure(DecodeError.truncated);
  final crates = <int>[];
  for (var i = 0; i < crateCount; i++) {
    final crate = reader.readU16();
    if (crate == null) return const DecodeFailure(DecodeError.truncated);
    if (crate >= cellCount) {
      return const DecodeFailure(DecodeError.entityOutOfBounds);
    }
    crates.add(crate);
  }
  final moveCount = reader.readU16();
  if (moveCount == null) return const DecodeFailure(DecodeError.truncated);
  if (moveCount == 0) {
    return const DecodeFailure(DecodeError.missingSolution);
  }
  if (moveCount > codecMaxSolutionMoves) {
    return const DecodeFailure(DecodeError.solutionTooLong);
  }
  final moveBytes = reader.readBytes((moveCount + 3) >> 2);
  if (moveBytes == null) return const DecodeFailure(DecodeError.truncated);
  final solution = <Direction>[];
  for (var j = 0; j < moveCount; j++) {
    final bits = (moveBytes[j >> 2] >> (6 - 2 * (j & 3))) & 0x03;
    solution.add(Direction.fromEncoding(bits));
  }
  final usedSlots = moveCount & 3;
  if (usedSlots != 0) {
    final padMask = (1 << (8 - 2 * usedSlots)) - 1;
    if ((moveBytes[moveBytes.length - 1] & padMask) != 0) {
      return const DecodeFailure(DecodeError.payloadLengthMismatch);
    }
  }
  if (!reader.atEnd) {
    return const DecodeFailure(DecodeError.payloadLengthMismatch);
  }
  return DecodeSuccess(
    Level(
      width: width,
      height: height,
      tiles: tiles,
      playerIndex: playerIndex,
      crateIndexes: crates,
    ),
    solution,
  );
}

/// Bounds-checked sequential reader; every read returns null past the end.
class _ByteReader {
  _ByteReader(this._data, this._offset);

  final Uint8List _data;
  int _offset;

  bool get atEnd => _offset == _data.length;

  int? readU8() => _offset + 1 <= _data.length ? _data[_offset++] : null;

  int? readU16() {
    if (_offset + 2 > _data.length) return null;
    final value = (_data[_offset] << 8) | _data[_offset + 1];
    _offset += 2;
    return value;
  }

  Uint8List? readBytes(int count) {
    if (_offset + count > _data.length) return null;
    final view = Uint8List.sublistView(_data, _offset, _offset + count);
    _offset += count;
    return view;
  }
}
```

- [ ] **Step 5: Run to verify it passes** — `dart test test/codec_decode_test.dart` then the full `dart test` → all PASS.

- [ ] **Step 6: Format-gate and commit**

```bash
dart format .
dart format --output=none --set-exit-if-changed .
git add -A
git commit -m "feat: implement total defensive share-code decoder"
```

---

### Task 6: Decoder error taxonomy — one vector per DecodeError

**Files:**
- Test: `packages/sokode_core/test/codec_errors_test.dart`

- [ ] **Step 1: Write the test** (implementation exists; this pins every error path with a hand-crafted vector)

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';
import 'helpers/seal_code.dart';

void main() {
  Level level() => levelFromAscii([
        '######',
        r'#@$ .#',
        '#    #',
        '######',
      ]);
  String valid() => encode(level(), const [Direction.right, Direction.right]);

  DecodeError errorOf(String code) => (decode(code) as DecodeFailure).error;

  /// Rebuilds the valid code's body with one byte replaced, re-sealed with
  /// a correct CRC (so the mutation itself is what the decoder sees).
  String mutated(int index, int value) {
    final body = rawBytes(valid());
    final withoutCrc = body.sublist(0, body.length - 4);
    withoutCrc[index] = value;
    return sealCode(withoutCrc);
  }

  test('badCharset: illegal characters, empty string, invalid base64', () {
    expect(errorOf('not base64url!!!'), DecodeError.badCharset);
    expect(errorOf(''), DecodeError.badCharset);
    expect(errorOf('A'), DecodeError.badCharset); // 1 char is invalid b64
  });

  test('truncated: fewer than header+crc bytes', () {
    expect(errorOf(sealCode(const [0x53, 0x4B, 1])), DecodeError.truncated);
  });

  test('badMagic', () {
    expect(errorOf(mutated(0, 0x58)), DecodeError.badMagic);
  });

  test('badChecksum: any bit flip without resealing', () {
    final bytes = rawBytes(valid());
    bytes[8] ^= 0xFF; // corrupt a tile byte, keep stale CRC
    final code = sealCode(bytes.sublist(0, bytes.length - 4), crcDelta: 1);
    expect(errorOf(code), DecodeError.badChecksum);
  });

  test('unsupportedVersion', () {
    expect(errorOf(mutated(2, 9)), DecodeError.unsupportedVersion);
  });

  test('unsupportedRuleset', () {
    expect(errorOf(mutated(3, 7)), DecodeError.unsupportedRuleset);
  });

  test('missingSolution: flags bit0 = 0', () {
    expect(errorOf(mutated(4, 0x00)), DecodeError.missingSolution);
  });

  test('reservedFlagBits: any of bits 1-7 set', () {
    expect(errorOf(mutated(4, 0x03)), DecodeError.reservedFlagBits);
  });

  test('dimensionOutOfBounds: 3, 33, 255, 0', () {
    expect(errorOf(mutated(5, 3)), DecodeError.dimensionOutOfBounds);
    expect(errorOf(mutated(5, 33)), DecodeError.dimensionOutOfBounds);
    expect(errorOf(mutated(6, 255)), DecodeError.dimensionOutOfBounds);
    expect(errorOf(mutated(6, 0)), DecodeError.dimensionOutOfBounds);
  });

  test('a code claiming huge dims dies before any tile allocation', () {
    // 32x32 is the max; 200x200 must be rejected at the header compare.
    final body = [0x53, 0x4B, 1, 1, 1, 200, 200];
    expect(errorOf(sealCode(body)), DecodeError.dimensionOutOfBounds);
  });

  test('truncated: valid header, tile section cut short', () {
    final body = [0x53, 0x4B, 1, 1, 1, 6, 4, 0x00, 0x00]; // 2 of 12 bytes
    expect(errorOf(sealCode(body)), DecodeError.truncated);
  });

  test('invalidTile: reserved nibble 13-15', () {
    expect(errorOf(mutated(7, 0xDD)), DecodeError.invalidTile); // 13,13
  });

  test('entityOutOfBounds: player index >= cellCount', () {
    // player u16 sits right after 12 tile bytes: offsets 19..20
    final body = rawBytes(valid()).sublist(0, rawBytes(valid()).length - 4);
    body[19] = 0xFF;
    body[20] = 0xFF;
    expect(errorOf(sealCode(body)), DecodeError.entityOutOfBounds);
  });

  test('solutionTooLong: moveCount > 4096', () {
    // moveCount u16 at offset 24..25 (header 7 + tiles 12 + player 2 +
    // count 1 + one crate 2). Also extend body so length checks pass first?
    // No: solutionTooLong is checked immediately after reading the count,
    // BEFORE reading move bytes — so mutating the count alone suffices.
    final body = rawBytes(valid()).sublist(0, rawBytes(valid()).length - 4);
    body[24] = 0xFF;
    body[25] = 0xFF; // 65535 > 4096
    expect(errorOf(sealCode(body)), DecodeError.solutionTooLong);
  });

  test('missingSolution: moveCount == 0', () {
    final body = rawBytes(valid()).sublist(0, rawBytes(valid()).length - 4);
    body[24] = 0;
    body[25] = 0;
    expect(errorOf(sealCode(body)), DecodeError.missingSolution);
  });

  test('payloadLengthMismatch: trailing surplus bytes', () {
    final body = rawBytes(valid()).sublist(0, rawBytes(valid()).length - 4);
    expect(errorOf(sealCode([...body, 0x00])),
        DecodeError.payloadLengthMismatch);
  });

  test('payloadLengthMismatch: nonzero padding bits in final move byte', () {
    // 2 moves used -> low 4 bits of the single move byte must be 0.
    final body = rawBytes(valid()).sublist(0, rawBytes(valid()).length - 4);
    body[body.length - 1] |= 0x01; // last body byte is the move byte
    expect(errorOf(sealCode(body)), DecodeError.payloadLengthMismatch);
  });
}
```

**Offset sanity note for the implementer:** the valid golden code's body is 27 bytes: header 7 (offsets 0–6), tiles 12 (7–18), player 2 (19–20), crateCount 1 (21), one crate 2 (22–23), moveCount 2 (24–25), moves 1 (26). If a vector fails on offsets, recompute from this table before suspecting the decoder.

- [ ] **Step 2: Run** — `dart test test/codec_errors_test.dart` → expected PASS (decoder shipped in Task 5). Any failure is a real decoder bug or a wrong offset: fix the decoder only if the ENCODING.md check order says the vector's expectation is right.

- [ ] **Step 3: Format-gate and commit**

```bash
dart format .
dart format --output=none --set-exit-if-changed .
git add -A
git commit -m "test: pin one decode vector per DecodeError"
```

---

### Task 7: Roundtrip property + fuzz suite

**Files:**
- Create: `packages/sokode_core/test/helpers/random_valid_level.dart`
- Test: `packages/sokode_core/test/codec_property_test.dart`

- [ ] **Step 1: Write the generator helper**

`test/helpers/random_valid_level.dart`:

```dart
import 'dart:math';

import 'package:sokode_core/sokode_core.dart';

/// Generates a level that passes SokobanPlus.validateStructure, from a
/// seeded [random] (same seed => same level). Construction places targets,
/// crates, and the player on plain floor AFTER sprinkling obstacles, so
/// validity holds by construction; a final check guards generator bugs.
Level randomValidLevel(Random random) {
  final width = codecMinDimension + random.nextInt(9); // 4..12
  final height = codecMinDimension + random.nextInt(9);
  final tiles = List<Tile>.generate(width * height, (_) {
    final roll = random.nextInt(10);
    if (roll == 0) return Tile.wall;
    if (roll == 1) return Tile.values[3 + random.nextInt(4)]; // one-ways
    if (roll == 2) return random.nextBool() ? Tile.switchA : Tile.switchB;
    if (roll == 3) return Tile.values[9 + random.nextInt(4)]; // gates
    return Tile.floor;
  });
  final floorCells = <int>[
    for (var i = 0; i < tiles.length; i++)
      if (tiles[i] == Tile.floor) i,
  ]..shuffle(random);
  final targetCount = 1 + random.nextInt(3);
  // Need: targets + crates (>= targets) + player, all on distinct cells.
  final crateCount = targetCount + random.nextInt(2);
  if (floorCells.length < targetCount + crateCount + 1) {
    return randomValidLevel(random); // sparse board — reroll
  }
  for (var t = 0; t < targetCount; t++) {
    tiles[floorCells.removeLast()] = Tile.target;
  }
  final crates = <int>[
    for (var c = 0; c < crateCount; c++) floorCells.removeLast(),
  ];
  final level = Level(
    width: width,
    height: height,
    tiles: tiles,
    playerIndex: floorCells.removeLast(),
    crateIndexes: crates,
  );
  final validation = const SokobanPlus().validateStructure(level);
  if (!validation.isValid) {
    throw StateError('generator bug: ${validation.errors}');
  }
  return level;
}

/// Random 1..50-move sequence (need not solve anything — the codec
/// roundtrip does not require solvability, only the import gate does).
List<Direction> randomMoves(Random random) => [
      for (var i = 0, n = 1 + random.nextInt(50); i < n; i++)
        Direction.values[random.nextInt(4)],
    ];
```

- [ ] **Step 2: Write the test**

`test/codec_property_test.dart`:

```dart
import 'dart:math';

import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/random_valid_level.dart';
import 'helpers/seal_code.dart';

void main() {
  test('PROPERTY: decode(encode(x)) == x over 300 random levels', () {
    final random = Random(2026);
    for (var trial = 0; trial < 300; trial++) {
      final level = randomValidLevel(random);
      final moves = randomMoves(random);
      final outcome = decode(encode(level, moves));
      expect(outcome, isA<DecodeSuccess>(),
          reason: 'trial $trial must roundtrip');
      final success = outcome as DecodeSuccess;
      expect(success.level.width, level.width);
      expect(success.level.height, level.height);
      expect(success.level.tiles, level.tiles);
      expect(success.level.playerIndex, level.playerIndex);
      expect(success.level.crateIndexes, level.crateIndexes);
      expect(success.solution, moves);
    }
  });

  test('FUZZ: random base64url strings never throw', () {
    final random = Random(7);
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    for (var trial = 0; trial < 2000; trial++) {
      final length = random.nextInt(200);
      final code = String.fromCharCodes([
        for (var i = 0; i < length; i++)
          alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ]);
      // Must return an outcome — an uncaught throw fails the test.
      expect(decode(code), isA<DecodeOutcome>());
    }
  });

  test('FUZZ: random sealed byte bodies never throw', () {
    final random = Random(13);
    for (var trial = 0; trial < 500; trial++) {
      final body = [
        for (var i = 0, n = random.nextInt(120); i < n; i++)
          random.nextInt(256),
      ];
      expect(decode(sealCode(body)), isA<DecodeOutcome>());
    }
  });

  test('FUZZ: every truncation of a valid code fails typed, never throws',
      () {
    final random = Random(99);
    final code = encode(randomValidLevel(random), randomMoves(random));
    for (var cut = 0; cut < code.length; cut++) {
      final outcome = decode(code.substring(0, cut));
      expect(outcome, isA<DecodeFailure>(),
          reason: 'prefix of length $cut must be rejected');
    }
  });

  test('FUZZ: every single-byte corruption is rejected (stale CRC)', () {
    final random = Random(41);
    final code = encode(randomValidLevel(random), randomMoves(random));
    final bytes = rawBytes(code);
    for (var i = 0; i < bytes.length; i++) {
      final copy = [...bytes];
      copy[i] = copy[i] ^ 0x55;
      final corrupted =
          sealCode(copy.sublist(0, copy.length - 4), crcDelta: 0);
      // Re-sealing recomputes the CRC over the corrupted body, so header
      // mutations surface as their own typed errors; direct stale-CRC
      // corruption (no re-seal) must be badChecksum:
      final stale = base64UrlNoPad(copy);
      expect(decode(corrupted), isA<DecodeOutcome>());
      expect(decode(stale), isA<DecodeFailure>(),
          reason: 'byte $i corrupted with stale CRC must fail');
    }
  });
}
```

Add to `test/helpers/seal_code.dart` (needed by the last fuzz case):

```dart
/// Base64url without padding over arbitrary raw bytes (no CRC handling).
String base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
```

- [ ] **Step 3: Run** — `dart test test/codec_property_test.dart` → expected PASS. A roundtrip failure means encoder and decoder disagree — fix against ENCODING.md (the document wins over both).

- [ ] **Step 4: Format-gate and commit**

```bash
dart format .
dart format --output=none --set-exit-if-changed .
git add -A
git commit -m "test: add codec roundtrip property and fuzz suite"
```

---

### Task 8: ReplayVerifier

**Files:**
- Create: `packages/sokode_core/lib/src/replay_verifier.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`
- Test: `packages/sokode_core/test/replay_verifier_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const verifier = ReplayVerifier(Simulation(SokobanPlus()));

  Level pushTwice() => levelFromAscii([
        '######',
        r'#@$ .#',
        '#    #',
        '######',
      ]);

  test('a correct solution verifies', () {
    final result =
        verifier.verify(pushTwice(), const [Direction.right, Direction.right]);
    final success = result as VerifySuccess;
    expect(success.solvedAtMove, 2);
  });

  test('early win: trailing moves after the solve are ignored', () {
    final result = verifier.verify(pushTwice(),
        const [Direction.right, Direction.right, Direction.down]);
    expect((result as VerifySuccess).solvedAtMove, 2);
  });

  test('empty replay is rejected', () {
    expect(verifier.verify(pushTwice(), const []), isA<VerifyEmptyReplay>());
  });

  test('replay over the 4096 cap is rejected before simulation', () {
    final tooLong = List.filled(4097, Direction.up);
    expect(verifier.verify(pushTwice(), tooLong), isA<VerifyTooLong>());
  });

  test('an illegal move fails with its index (strict verification)', () {
    // Move 0: up into the wall — illegal.
    final result =
        verifier.verify(pushTwice(), const [Direction.up, Direction.right]);
    expect((result as VerifyIllegalMove).moveIndex, 0);
  });

  test('legal moves that do not solve are rejected', () {
    final result = verifier.verify(pushTwice(), const [Direction.down]);
    expect(result, isA<VerifyNotSolved>());
  });

  test('a pre-solved level verifies at move 0', () {
    final level = levelFromAscii([
      '#####',
      '#@* #',
      '#   #',
      '#####',
    ]);
    final result = verifier.verify(level, const [Direction.down]);
    expect((result as VerifySuccess).solvedAtMove, 0);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/replay_verifier_test.dart` → FAIL.

- [ ] **Step 3: Implement**

`lib/src/replay_verifier.dart`:

```dart
import 'direction.dart';
import 'grid_state.dart';
import 'level.dart';
import 'level_codec.dart';
import 'simulation.dart';
import 'step_result.dart';

/// Result of verifying a solution replay. Sealed for exhaustive handling.
sealed class VerifyResult {
  const VerifyResult();
}

/// The replay solves the level. [solvedAtMove] is how many moves were
/// consumed (0 for a pre-solved level); trailing moves are ignored.
class VerifySuccess extends VerifyResult {
  const VerifySuccess(this.finalState, this.solvedAtMove);

  final GridState finalState;
  final int solvedAtMove;
}

sealed class VerifyFailure extends VerifyResult {
  const VerifyFailure();
}

class VerifyEmptyReplay extends VerifyFailure {
  const VerifyEmptyReplay();
}

/// Replay exceeds the 4096-move ceiling — rejected before any simulation
/// so an oversized replay cannot be used as a CPU DoS (spec §4).
class VerifyTooLong extends VerifyFailure {
  const VerifyTooLong();
}

/// Move [moveIndex] was Blocked. Verification is strict: a proof
/// containing illegal moves is not a proof.
class VerifyIllegalMove extends VerifyFailure {
  const VerifyIllegalMove(this.moveIndex);

  final int moveIndex;
}

class VerifyNotSolved extends VerifyFailure {
  const VerifyNotSolved();
}

/// Replays a recorded solution through the SAME Simulation used for play —
/// the publish/import gate's proof checker (spec §4). Never forks its own
/// transition logic.
class ReplayVerifier {
  const ReplayVerifier(this.simulation);

  final Simulation simulation;

  VerifyResult verify(Level level, List<Direction> moves) {
    if (moves.isEmpty) return const VerifyEmptyReplay();
    if (moves.length > codecMaxSolutionMoves) return const VerifyTooLong();
    var state = simulation.initialState(level);
    if (simulation.ruleSet.isSolved(state)) return VerifySuccess(state, 0);
    for (var i = 0; i < moves.length; i++) {
      switch (simulation.apply(state, moves[i])) {
        case Blocked():
          return VerifyIllegalMove(i);
        case Moved(state: final next):
          state = next;
          if (simulation.ruleSet.isSolved(state)) {
            return VerifySuccess(state, i + 1);
          }
      }
    }
    return const VerifyNotSolved();
  }
}
```

Append to `lib/sokode_core.dart`: `export 'src/replay_verifier.dart';`

- [ ] **Step 4: Run the full suite** — `dart test` → PASS.

- [ ] **Step 5: Format-gate and commit**

```bash
dart format .
dart format --output=none --set-exit-if-changed .
git add -A
git commit -m "feat: implement strict replay verifier"
```

---

### Task 9: LevelImporter pipeline + docs + PR

**Files:**
- Create: `packages/sokode_core/lib/src/level_import.dart`
- Modify: `packages/sokode_core/lib/sokode_core.dart`, `ARCHITECTURE.md`
- Test: `packages/sokode_core/test/level_import_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const importer = LevelImporter(SokobanPlus());

  Level solvable() => levelFromAscii([
        '######',
        r'#@$ .#',
        '#    #',
        '######',
      ]);

  test('a genuine authored code imports successfully', () {
    final code = encode(solvable(), const [Direction.right, Direction.right]);
    final outcome = importer.import(code);
    expect(outcome, isA<ImportSuccess>());
  });

  test('garbage input surfaces the DecodeError', () {
    final outcome = importer.import('!!!') as ImportDecodeFailure;
    expect(outcome.error, DecodeError.badCharset);
  });

  test('a structurally invalid level is rejected by the validator stage',
      () {
    // No targets: decodes fine, fails validateStructure.
    final level = levelFromAscii([
      '#####',
      r'#@$ #',
      '#   #',
      '#####',
    ]);
    final code = encode(level, const [Direction.right]);
    final outcome = importer.import(code) as ImportValidationFailure;
    expect(outcome.errors, contains(ValidationError.noTargets));
  });

  test('THE GATE: a forged impossible level cannot get in', () {
    // Crate walled into a corner, target unreachable — with a bogus
    // "solution" attached. decode passes, validate passes, verify MUST fail.
    final forged = levelFromAscii([
      '######',
      r'#@ #$#',
      '# .# #',
      '######',
    ]);
    final code = encode(forged, const [Direction.right, Direction.down]);
    final outcome = importer.import(code) as ImportVerifyFailure;
    expect(outcome.failure, isA<VerifyFailure>());
  });

  test('a solution that stops short of solving is rejected', () {
    final code = encode(solvable(), const [Direction.right]); // one push short
    final outcome = importer.import(code) as ImportVerifyFailure;
    expect(outcome.failure, isA<VerifyNotSolved>());
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `dart test test/level_import_test.dart` → FAIL.

- [ ] **Step 3: Implement**

`lib/src/level_import.dart`:

```dart
import 'decode_error.dart';
import 'direction.dart';
import 'level.dart';
import 'level_codec.dart';
import 'replay_verifier.dart';
import 'ruleset.dart';
import 'simulation.dart';
import 'validation.dart';

/// Outcome of importing an untrusted share code. Sealed.
sealed class ImportOutcome {
  const ImportOutcome();
}

/// The code decoded, validated, AND proved solvable by its embedded
/// replay. Only levels wrapped in this type may become playable.
class ImportSuccess extends ImportOutcome {
  const ImportSuccess(this.level, this.solution);

  final Level level;
  final List<Direction> solution;
}

class ImportDecodeFailure extends ImportOutcome {
  const ImportDecodeFailure(this.error);

  final DecodeError error;
}

class ImportValidationFailure extends ImportOutcome {
  const ImportValidationFailure(this.errors);

  final List<ValidationError> errors;
}

class ImportVerifyFailure extends ImportOutcome {
  const ImportVerifyFailure(this.failure);

  final VerifyFailure failure;
}

/// The publish gate, enforced at IMPORT time (spec §4): decode ->
/// validateStructure -> verify embedded solution, all mandatory, all
/// through the same RuleSet/Simulation used for play. A hand-crafted code
/// for an impossible level dies at the verify stage — the code carries its
/// own proof or it does not get in.
class LevelImporter {
  const LevelImporter(this.ruleSet);

  final RuleSet ruleSet;

  ImportOutcome import(String code) {
    switch (decode(code)) {
      case DecodeFailure(:final error):
        return ImportDecodeFailure(error);
      case DecodeSuccess(:final level, :final solution):
        final validation = ruleSet.validateStructure(level);
        if (!validation.isValid) {
          return ImportValidationFailure(validation.errors);
        }
        final verifier = ReplayVerifier(Simulation(ruleSet));
        return switch (verifier.verify(level, solution)) {
          VerifySuccess() => ImportSuccess(level, solution),
          final VerifyFailure failure => ImportVerifyFailure(failure),
        };
    }
  }
}
```

Append to `lib/sokode_core.dart`: `export 'src/level_import.dart';`

- [ ] **Step 4: Run the full suite** — `dart test` → PASS.

- [ ] **Step 5: Append a codec section to ARCHITECTURE.md**

```markdown

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
```

- [ ] **Step 6: Format-gate, commit, push, PR**

```bash
dart format .
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
git add -A
git commit -m "feat: add import pipeline enforcing the publish gate"
git push -u origin feat/02-codec
gh pr create --repo stevenfackley/sokode --base main \
  --title "feat: share-code codec + import gate (Plan 02 — spec phases 2-3)" \
  --body "ENCODING.md wire spec; total defensive decoder (13-error taxonomy, caps-before-allocation, fuzz suite incl. per-byte corruption and every-prefix truncation); canonical encoder with golden pin; strict ReplayVerifier (4096-move DoS cap, early-win); LevelImporter = decode -> validate -> verify publish gate. Roundtrip property over 300 generated levels."
gh pr checks --repo stevenfackley/sokode --watch
```

- [ ] **Step 7: Phase-gate report** — post the playbook-format report (built / decisions+trade-offs / assumptions / test results / defer-descope) as a PR comment before merge.

---

## Self-Review (completed at authoring time)

- **Spec coverage:** spec §3 layout/versioning/caps/canonicalization → Tasks 1, 4, 5; every `DecodeError` incl. the two addenda → Tasks 3, 6; fuzz + roundtrip acceptance (phase 2) → Task 7; `ReplayVerifier` + move ceiling + `LevelValidator` wiring (phase 3, spec §4) → Tasks 8, 9; determinism (one Simulation path) → ReplayVerifier delegates to `Simulation.apply`, asserted structurally by Task 8's tests.
- **Placeholder scan:** golden-pin literals (`''`) follow the documented pin procedure from Plan 01 — intentional, not placeholders. No TBDs.
- **Type consistency:** `DecodeOutcome`/`DecodeSuccess.solution`, `VerifySuccess.solvedAtMove`, `LevelImporter.import`, and helper names (`sealCode`, `u16`, `rawBytes`, `base64UrlNoPad`, `randomValidLevel`, `randomMoves`) are used identically across Tasks 3–9. Byte-offset table in Task 6 matches the layout in Task 1 and the encoder in Task 4 (header 7, tiles ⌈w·h/2⌉, golden body = 27 bytes).
