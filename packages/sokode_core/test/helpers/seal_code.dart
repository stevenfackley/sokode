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
