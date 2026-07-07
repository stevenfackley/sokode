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
