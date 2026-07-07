import 'dart:convert';
import 'dart:typed_data';

import 'crc32.dart';
import 'direction.dart';
import 'level.dart';

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
