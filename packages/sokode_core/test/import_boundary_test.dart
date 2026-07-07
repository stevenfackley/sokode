import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('sokode_core has zero Flutter imports (spec §2.1 — CI-enforced)', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('package:flutter') || source.contains('dart:ui')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'core must stay engine-independent: $offenders');
  });

  test('pubspec declares no flutter dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('sdk: flutter'), isFalse);
  });
}
