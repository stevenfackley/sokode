/// Authored source of the shipped sample levels (spec phase 6).
///
/// This is CONTENT, not library code: it lives in `tool/` so it never ships
/// inside `sokode_core`. `generate_seed_levels.dart` solves each entry with
/// a breadth-first search and emits the resulting proof-carrying share codes
/// into `app/lib/content/seed_levels.dart`.
///
/// ASCII legend (same as the core test helper):
///   `#` wall   ` ` floor   `.` target
///   `@` player-on-floor    `+` player-on-target
///   `$` crate-on-floor     `*` crate-on-target
///   `^ > v <` one-way (permitted ENTRY direction)
///   `a` switch A   `b` switch B
///   `[` gate A open   `]` gate A closed
///   `{` gate B open   `}` gate B closed
///
/// Constraints every entry must satisfy (checked by the generator, not
/// assumed): 4..=32 in both dimensions, at least one target, crates >=
/// targets, and a breadth-first-reachable solution.
library;

/// One authored level: its pack and its ASCII rows.
class SeedSpec {
  const SeedSpec(this.pack, this.rows);

  final String pack;
  final List<String> rows;
}

/// Pack order is display order; within a pack, catalog order is difficulty
/// order. Titles are NOT authored — they are derived from each level's state
/// digest at display time (spec §5: no free text anywhere).
const List<SeedSpec> seedCatalog = <SeedSpec>[
  // ---------------------------------------------------------------- basics
  SeedSpec('First Steps', [
    '######',
    r'#@$ .#',
    '#    #',
    '######',
  ]),
  SeedSpec('First Steps', [
    '#######',
    r'#@$  .#',
    '#     #',
    r'# $  .#',
    '#######',
  ]),
  SeedSpec('First Steps', [
    '######',
    '#   .#',
    r'# $  #',
    '#  # #',
    '#@   #',
    '######',
  ]),
  SeedSpec('First Steps', [
    '######',
    '#..  #',
    '#    #',
    r'# $$ #',
    '# @  #',
    '######',
  ]),
  SeedSpec('First Steps', [
    '#######',
    '#  #  #',
    r'#@$#. #',
    '#     #',
    '#     #',
    '#######',
  ]),
  SeedSpec('First Steps', [
    '########',
    r'#@$  ..#',
    '#      #',
    r'#  $   #',
    '#      #',
    '########',
  ]),

  // ------------------------------------------------------------- one-ways
  SeedSpec('One-Way Streets', [
    '#######',
    r'#@$>>.#',
    '#     #',
    '#     #',
    '#######',
  ]),
  SeedSpec('One-Way Streets', [
    '######',
    '#   .#',
    '# v  #',
    r'# $  #',
    '#@   #',
    '######',
  ]),
  SeedSpec('One-Way Streets', [
    '#######',
    '#  .  #',
    '#  ^  #',
    r'#  $  #',
    '#@    #',
    '#######',
  ]),
  SeedSpec('One-Way Streets', [
    '########',
    '#      #',
    r'#@$ < .#',
    '#      #',
    '#      #',
    '########',
  ]),
  SeedSpec('One-Way Streets', [
    '########',
    r'#@$>  .#',
    '#      #',
    r'#  $>  #',
    '#     .#',
    '########',
  ]),
  SeedSpec('One-Way Streets', [
    '########',
    r'#@$   .#',
    '#      #',
    '#  >>  #',
    r'# $   .#',
    '#      #',
    '########',
  ]),

  // -------------------------------------------------------- switches/gates
  SeedSpec('Switches & Gates', [
    '########',
    '#@ a   #',
    r'## $] .#',
    '#      #',
    '########',
  ]),
  SeedSpec('Switches & Gates', [
    '########',
    '#@ b   #',
    r'## $} .#',
    '#      #',
    '########',
  ]),
  SeedSpec('Switches & Gates', [
    '########',
    '#@ a   #',
    '##  ]  #',
    r'##  $  #',
    '##  .  #',
    '########',
  ]),
  SeedSpec('Switches & Gates', [
    '##########',
    r'#@$a $] .#',
    '#        #',
    '#        #',
    '#        #',
    '##########',
  ]),
  SeedSpec('Switches & Gates', [
    '#########',
    '#@ a a  #',
    r'## $] . #',
    '#       #',
    '#########',
  ]),
  // Both gates load-bearing: A is the only way down to the crate, B is the
  // only way right to the target.
  SeedSpec('Switches & Gates', [
    '##########',
    '#@ a  b  #',
    '####]#####',
    r'#  $ }  .#',
    '#        #',
    '##########',
  ]),

  // ---------------------------------------------------------------- mixed
  SeedSpec('Mixed Bag', [
    '#########',
    '#@ a    #',
    r'## $]>>.#',
    '#       #',
    '#       #',
    '#########',
  ]),
  SeedSpec('Mixed Bag', [
    '##########',
    r'#@$a $]}.#',
    '#     b  #',
    '#        #',
    '#        #',
    '##########',
  ]),
  SeedSpec('Mixed Bag', [
    '#########',
    r'#@$   . #',
    '#       #',
    r'# $   . #',
    '#       #',
    '#########',
  ]),
  // Row 3 is walled off on the left, so the crate can only travel row 2 —
  // through the gate — and the one-way refuses a rightward entry, forcing
  // the down-then-right finish.
  SeedSpec('Mixed Bag', [
    '#########',
    '#@  a   #',
    r'#  $]  v#',
    '#####  .#',
    '#########',
  ]),
  SeedSpec('Mixed Bag', [
    '##########',
    r'#@ a $>>.#',
    r'## $]    #',
    '#     .  #',
    '#        #',
    '##########',
  ]),
];
