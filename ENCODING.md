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

> Implementation status: this document is the spec of record, written ahead
> of the code per the v1 design. The codec lands with Plan 02
> (`docs/superpowers/plans/2026-07-06-sokode-02-codec-gate.md`).
