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
