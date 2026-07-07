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

/// Deterministic "Adjective Noun" title derived from the level's initial
/// state digest — same level, same title, on every platform.
String titleForLevel(Level level) {
  final digest = stateDigest(GridState.initial(level));
  final adjective = titleAdjectives[digest % titleAdjectives.length];
  final noun =
      titleNouns[(digest ~/ titleAdjectives.length) % titleNouns.length];
  return '$adjective $noun';
}
