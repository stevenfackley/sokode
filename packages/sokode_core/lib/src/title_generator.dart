import 'grid_state.dart';
import 'level.dart';
import 'state_digest.dart';

/// Fixed word lists (spec §5: titles are generated, never user text —
/// moderation by construction). 32×32 = 1024 combinations. Append-only:
/// reordering or removing words changes existing levels' titles.
const List<String> titleAdjectives = [
  'Amber',
  'Bold',
  'Brave',
  'Calm',
  'Clever',
  'Copper',
  'Crimson',
  'Daring',
  'Dusty',
  'Eager',
  'Foggy',
  'Gentle',
  'Golden',
  'Hidden',
  'Iron',
  'Ivory',
  'Jade',
  'Keen',
  'Lucky',
  'Mellow',
  'Nimble',
  'Oaken',
  'Pale',
  'Quiet',
  'Rapid',
  'Rustic',
  'Silent',
  'Slate',
  'Steady',
  'Stormy',
  'Swift',
  'Tidy',
];

const List<String> titleNouns = [
  'Anchor',
  'Beacon',
  'Cellar',
  'Cipher',
  'Corner',
  'Crate',
  'Depot',
  'Dock',
  'Garden',
  'Gate',
  'Harbor',
  'Hollow',
  'Lantern',
  'Ledger',
  'Maze',
  'Meadow',
  'Mill',
  'Orchard',
  'Passage',
  'Path',
  'Plaza',
  'Quarry',
  'Relay',
  'Ridge',
  'Signal',
  'Spiral',
  'Station',
  'Switch',
  'Tunnel',
  'Vault',
  'Wharf',
  'Yard',
];

/// Deterministic "Adjective Noun" title derived from the whole level —
/// same level, same title, on every platform.
String titleForLevel(Level level) {
  final digest = _levelFingerprint(level);
  final adjective = titleAdjectives[digest % titleAdjectives.length];
  final noun =
      titleNouns[(digest ~/ titleAdjectives.length) % titleNouns.length];
  return '$adjective $noun';
}

/// Fingerprint covering dimensions, tiles AND initial entity placement.
///
/// [stateDigest] alone is not enough: it fingerprints the *mutable* state
/// (player, crates, open gates) and is deliberately blind to the tile grid,
/// so two levels that merely start their entities in the same cells collide
/// however different their walls, targets, one-ways and gates are. That
/// blindness is correct for the determinism golden test — and wrong for a
/// title, which names a level, not a position.
///
/// Same arithmetic discipline as [stateDigest]: every intermediate stays
/// under 2^53 so the Dart VM and JS agree.
int _levelFingerprint(Level level) {
  const modulus = 1000000007;
  var h = stateDigest(GridState.initial(level));
  void mix(int v) {
    h = (h * 31 + v + 2) % modulus;
  }

  mix(level.width);
  mix(level.height);
  for (final tile in level.tiles) {
    mix(tile.nibble);
  }
  return h;
}
