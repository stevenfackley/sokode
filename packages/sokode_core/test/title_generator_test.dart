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

  test('tiles are part of the identity, not just entity placement', () {
    // Same player cell, same crate cell, same (empty) open-gate set — only
    // the tile grid differs. Titles that ignored the grid collided here and
    // shipped four identically-named sample levels.
    final plain = levelFromAscii([
      '######',
      r'#@$ .#',
      '#    #',
      '######',
    ]);
    final gated = levelFromAscii([
      '######',
      r'#@$].#',
      '#   a#',
      '######',
    ]);
    expect(titleForLevel(gated), isNot(titleForLevel(plain)));
  });

  test('dimensions are part of the identity', () {
    final wide = levelFromAscii([
      '#######',
      r'#@$ . #',
      '#     #',
      '#######',
    ]);
    final narrow = levelFromAscii([
      '######',
      r'#@$ .#',
      '#    #',
      '######',
    ]);
    expect(titleForLevel(wide), isNot(titleForLevel(narrow)));
  });
}
