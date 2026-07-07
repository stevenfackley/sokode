import 'package:sokode_core/sokode_core.dart';
import 'package:test/test.dart';

import 'helpers/ascii_level.dart';

void main() {
  const rules = SokobanPlus();

  Level valid() => levelFromAscii([
        '######',
        r'#@$ .#',
        '#    #',
        '#    #',
        '######',
      ]);

  test('a well-formed level validates clean', () {
    final result = rules.validateStructure(valid());
    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
  });

  test('dimension caps 4..=32 (spec §4)', () {
    Level sized(int w, int h) => Level(
          width: w,
          height: h,
          tiles: List.filled(w * h, Tile.floor)..[1] = Tile.target,
          playerIndex: 0,
          crateIndexes: const [1],
        );
    expect(rules.validateStructure(sized(3, 8)).errors,
        contains(ValidationError.dimensionOutOfBounds));
    expect(rules.validateStructure(sized(8, 33)).errors,
        contains(ValidationError.dimensionOutOfBounds));
    expect(rules.validateStructure(sized(4, 4)).errors,
        isNot(contains(ValidationError.dimensionOutOfBounds)));
    expect(rules.validateStructure(sized(32, 32)).errors,
        isNot(contains(ValidationError.dimensionOutOfBounds)));
  });

  test('requires at least one target', () {
    final level = levelFromAscii(['#####', r'#@$ #', '#####', '#####']);
    expect(rules.validateStructure(level).errors,
        contains(ValidationError.noTargets));
  });

  test('requires crates >= targets', () {
    // 3 targets, 1 crate
    final level = levelFromAscii(['#####', r'#@$.#', '#.. #', '#####']);
    expect(rules.validateStructure(level).errors,
        contains(ValidationError.fewerCratesThanTargets));
  });

  test('rejects entities on walls or closed gates', () {
    final base = valid();
    final onWall = Level(
      width: base.width,
      height: base.height,
      tiles: base.tiles,
      playerIndex: 0, // a wall cell
      crateIndexes: base.crateIndexes,
    );
    expect(rules.validateStructure(onWall).errors,
        contains(ValidationError.entityOnBlockedTile));
  });

  test('rejects out-of-bounds entities, duplicate crates, player-on-crate', () {
    final base = valid();
    Level withCrates(List<int> crates, {int? player}) => Level(
          width: base.width,
          height: base.height,
          tiles: base.tiles,
          playerIndex: player ?? base.playerIndex,
          crateIndexes: crates,
        );
    expect(rules.validateStructure(withCrates(const [999])).errors,
        contains(ValidationError.entityOutOfBounds));
    expect(rules.validateStructure(withCrates(const [8, 8])).errors,
        contains(ValidationError.duplicateCrate));
    expect(rules.validateStructure(withCrates(const [7], player: 7)).errors,
        contains(ValidationError.playerOnCrate));
  });
}
