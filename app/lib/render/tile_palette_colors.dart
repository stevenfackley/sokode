import 'package:flutter/material.dart';
import 'package:sokode_core/sokode_core.dart';

/// Maps every [Tile] kind, plus the board background, to a color. One
/// color per tile kind; switch/gate channels A and B use distinct hues
/// (A: blue family, B: purple family) and closed gates are visibly
/// darker than their open counterpart so state reads at a glance.
class TilePaletteColors {
  const TilePaletteColors();

  Color get background => const Color(0xFF1B1F23);

  Color get floor => const Color(0xFF2B3138);
  Color get wall => const Color(0xFF464E58);
  Color get target => const Color(0xFFE0C341);

  Color get onewayArrow => const Color(0xFF9AA5B1);

  Color get switchA => const Color(0xFF4C8DFF);
  Color get switchB => const Color(0xFFB161E8);

  Color get gateAOpen => const Color(0xFF6FB3FF);
  Color get gateAClosed => const Color(0xFF1E3A63);
  Color get gateBOpen => const Color(0xFFD68CFF);
  Color get gateBClosed => const Color(0xFF3C1E5C);

  /// The color for a tile as it currently sits on the board. Gate color is
  /// resolved from live [isOpen] state, not the static tile — the same
  /// tile kind can flip color as the level plays.
  Color colorFor(Tile tile, {required bool isOpen}) => switch (tile) {
    Tile.floor => floor,
    Tile.wall => wall,
    Tile.target => target,
    Tile.onewayUp ||
    Tile.onewayRight ||
    Tile.onewayDown ||
    Tile.onewayLeft => floor,
    Tile.switchA => switchA,
    Tile.switchB => switchB,
    Tile.gateAOpen || Tile.gateAClosed => isOpen ? gateAOpen : gateAClosed,
    Tile.gateBOpen || Tile.gateBClosed => isOpen ? gateBOpen : gateBClosed,
  };
}
