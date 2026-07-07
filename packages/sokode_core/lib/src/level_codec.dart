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
