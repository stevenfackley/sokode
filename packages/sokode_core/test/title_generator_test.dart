import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  Level level() => levelFromAscii([
        '######',
        r'#@$ .#',
        '#    #',
        '######',
      ]);

  test('deterministic: same level always yields the same title', () {
    expect(titleForLevel(level()), titleForLevel(level()));
  });

  test('format is "Adjective Noun" from the fixed word lists', () {
    final parts = titleForLevel(level()).split(' ');
    expect(parts, hasLength(2));
    expect(titleAdjectives, contains(parts[0]));
    expect(titleNouns, contains(parts[1]));
  });

  test('word lists are fixed-size and non-empty (moderation surface)', () {
    expect(titleAdjectives, hasLength(32));
    expect(titleNouns, hasLength(32));
  });

  test('different levels usually get different titles', () {
    final other = levelFromAscii([
      '######',
      r'#@ $.#',
      '#    #',
      '######',
    ]);
    expect(titleForLevel(other), isNot(titleForLevel(level())));
  });
}
