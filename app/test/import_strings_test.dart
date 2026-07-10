import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/import/import_strings.dart';
import 'package:sokode_core/sokode_core.dart';

void main() {
  test('every DecodeError has a non-empty, non-technical description', () {
    for (final error in DecodeError.values) {
      final text = describeImportFailure(ImportDecodeFailure(error));
      expect(text, isNotEmpty, reason: '$error');
      expect(text.contains('DecodeError'), isFalse, reason: '$error');
    }
  });

  test('validation and verify failures have descriptions', () {
    expect(
      describeImportFailure(const ImportValidationFailure([])),
      isNotEmpty,
    );
    expect(
      describeImportFailure(const ImportVerifyFailure(VerifyNotSolved())),
      isNotEmpty,
    );
  });
}
