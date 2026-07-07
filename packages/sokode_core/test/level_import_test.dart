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

  test('a structurally invalid level is rejected by the validator stage', () {
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
