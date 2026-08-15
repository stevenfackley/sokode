// GENERATED FILE — do not edit by hand.
//
// Source:     packages/sokode_core/tool/seed_catalog.dart
// Regenerate: dart run tool/generate_seed_levels.dart
//             (from packages/sokode_core, then dart format)

/// One shipped sample level.
///
/// [code] is an ordinary share code — the same kind a player
/// pastes in — so samples carry their own solution proof and
/// earn no special trust from the import gate.
class SeedLevel {
  const SeedLevel({
    required this.pack,
    required this.code,
    required this.parMoves,
  });

  /// Display grouping; see [seedPacks] for display order.
  final String pack;

  /// Proof-carrying share code.
  final String code;

  /// Length of the shortest solution known at generation
  /// time — the embedded proof. Shown as "par".
  final int parMoves;
}

/// Pack display order.
const List<String> seedPacks = <String>[
  'First Steps',
  'One-Way Streets',
  'Switches & Gates',
  'Mixed Bag',
];

/// The shipped sample levels, in difficulty order per pack.
const List<SeedLevel> seedLevels = <SeedLevel>[
  // Brave Spiral
  SeedLevel(
    pack: 'First Steps',
    code: 'U0sBAQEGBBERERAAIRAAAREREQAHAQAIAAJQPH0FDA',
    parMoves: 2,
  ),
  // Jade Yard
  SeedLevel(
    pack: 'First Steps',
    code: 'U0sBAQEHBREREREAACEQAAARAAAhEREREAAIAgAJABcAC1b-VPUTz98',
    parMoves: 11,
  ),
  // Eager Spiral
  SeedLevel(
    pack: 'First Steps',
    code: 'U0sBAQEGBhERERAAIRAAARABARAAAREREQAZAQAOAAcTFHgt750',
    parMoves: 7,
  ),
  // Silent Spiral
  SeedLevel(
    pack: 'First Steps',
    code: 'U0sBAQEGBhERERIgARAAARAAARAAAREREQAaAgAUABUACwW-wAhUyLE',
    parMoves: 11,
  ),
  // Foggy Wharf
  SeedLevel(
    pack: 'First Steps',
    code: 'U0sBAQEHBhEREREAEAEQASARAAABEAAAEREREQAPAQAQAAoblkDxNJuN',
    parMoves: 10,
  ),
  // Pale Gate
  SeedLevel(
    pack: 'First Steps',
    code: 'U0sBAQEIBhEREREQAAIhEAAAARAAAAEQAAABEREREQAJAgAKABsADlb5WQBqmo5s',
    parMoves: 14,
  ),
  // Steady Ridge
  SeedLevel(
    pack: 'One-Way Streets',
    code: 'U0sBAQEHBREREREARCEQAAARAAABEREREAAIAQAJAANUuTkJVg',
    parMoves: 3,
  ),
  // Rustic Garden
  SeedLevel(
    pack: 'One-Way Streets',
    code: 'U0sBAQEGBhERERAAIRBQARAAARAAAREREQAZAQAUAAcWQBGUwWY',
    parMoves: 7,
  ),
  // Gentle Quarry
  SeedLevel(
    pack: 'One-Way Streets',
    code: 'U0sBAQEHBhEREREAIAEQAwARAAABEAAAEREREQAdAQAYAARQ_DgtXA',
    parMoves: 4,
  ),
  // Dusty Cellar
  SeedLevel(
    pack: 'One-Way Streets',
    code: 'U0sBAQEIBhEREREQAAABEABgIRAAAAEQAAABEREREQARAQASAAwblWQc6TLk',
    parMoves: 12,
  ),
  // Copper Anchor
  SeedLevel(
    pack: 'One-Way Streets',
    code: 'U0sBAQEIBhEREREQBAAhEAAAARAAQAEQAAAhEREREQAJAgAKABsADVW-5UBAPwq7',
    parMoves: 13,
  ),
  // Clever Cipher
  SeedLevel(
    pack: 'One-Way Streets',
    code:
        'U0sBAQEIBxEREREQAAAhEAAAARAEQAEQAAAhEAAAAREREREACQIACgAiAA9Vv7lU2H1WVg',
    parMoves: 15,
  ),
  // Iron Depot
  SeedLevel(
    pack: 'Switches & Gates',
    code: 'U0sBAQEIBREREREQBwABEQCgIRAAAAERERERAAkBABMAB15UBu1idw',
    parMoves: 7,
  ),
  // Copper Orchard
  SeedLevel(
    pack: 'Switches & Gates',
    code: 'U0sBAQEIBREREREQCAABEQDAIRAAAAERERERAAkBABMAB15UjnTzgg',
    parMoves: 7,
  ),
  // Rapid Meadow
  SeedLevel(
    pack: 'Switches & Gates',
    code: 'U0sBAQEIBhEREREQBwABEQCgAREAAAERACABEREREQAJAQAcAAVWgAp2IE0',
    parMoves: 5,
  ),
  // Stormy Garden
  SeedLevel(
    pack: 'Switches & Gates',
    code:
        'U0sBAQEKBhEREREREAcAoCEQAAAAARAAAAABEAAAAAEREREREQALAgAMAA8ACGUV9PH3vQ',
    parMoves: 8,
  ),
  // Clever Ridge
  SeedLevel(
    pack: 'Switches & Gates',
    code: 'U0sBAQEJBRERERERAHBwAREAoCARAAAAAREREREQAAoBABUAB15USJAsEA',
    parMoves: 7,
  ),
  // Dusty Cipher
  SeedLevel(
    pack: 'Switches & Gates',
    code:
        'U0sBAQEKBhEREREREAcAgAEREaERERAADAAhEAAAAAEREREREQALAQAhABJVfq8VUO3uhKA',
    parMoves: 18,
  ),
  // Calm Garden
  SeedLevel(
    pack: 'Mixed Bag',
    code: 'U0sBAQEJBhERERERAHAAAREApEIRAAAAARAAAAAREREREQAKAQAVAAheVZy_Imc',
    parMoves: 8,
  ),
  // Clever Hollow
  SeedLevel(
    pack: 'Mixed Bag',
    code:
        'U0sBAQEKBhEREREREAcArCEQAACAARAAAAABEAAAAAEREREREQALAgAMAA8ADGUZxS_3iag',
    parMoves: 12,
  ),
  // Steady Wharf
  SeedLevel(
    pack: 'Mixed Bag',
    code:
        'U0sBAQEJBhERERERAAACARAAAAARAAACARAAAAAREREREQAKAgALAB0ADlW_5VCtqdMZ',
    parMoves: 14,
  ),
  // Silent Maze
  SeedLevel(
    pack: 'Mixed Bag',
    code: 'U0sBAQEJBRERERERAAcAARAAoAUREREAIREREREQAAoBABUAD1flRuS89AYc',
    parMoves: 15,
  ),
  // Eager Cellar
  SeedLevel(
    pack: 'Mixed Bag',
    code:
        'U0sBAQEKBhEREREREAcARCERAKAAARAAACABEAAAAAEREREREQALAgAPABcADluVMVDzt9_U',
    parMoves: 14,
  ),
];
