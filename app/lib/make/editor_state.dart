import 'package:flutter/foundation.dart';
import 'package:sokode_core/sokode_core.dart';

import '../store/stored_level.dart';

/// What the maker's brush can paint. Tiles paint the tile layer; player and
/// crate place entities; erase resets a cell to floor and removes any entity
/// on it.
enum Brush {
  floor,
  wall,
  target,
  onewayUp,
  onewayRight,
  onewayDown,
  onewayLeft,
  switchA,
  switchB,
  gateAOpen,
  gateAClosed,
  gateBOpen,
  gateBClosed,
  player,
  crate,
  erase,
}

/// Mutable authoring state. Converts to an immutable core Level on demand;
/// all validation is the core's validateStructure — the editor never
/// duplicates rules.
class EditorState extends ChangeNotifier {
  EditorState({this.width = 8, this.height = 8})
    : _tiles = List.filled(width * height, Tile.floor) {
    _borderWalls();
  }

  final int width;
  final int height;
  final List<Tile> _tiles;
  int? _playerIndex;
  final Set<int> _crateIndexes = {};
  Brush brush = Brush.wall;

  void _borderWalls() {
    for (var x = 0; x < width; x++) {
      _tiles[x] = Tile.wall;
      _tiles[(height - 1) * width + x] = Tile.wall;
    }
    for (var y = 0; y < height; y++) {
      _tiles[y * width] = Tile.wall;
      _tiles[y * width + width - 1] = Tile.wall;
    }
  }

  Tile tileAt(int index) => _tiles[index];
  int? get playerIndex => _playerIndex;
  Set<int> get crateIndexes => Set.unmodifiable(_crateIndexes);

  static const Map<Brush, Tile> _tileBrushes = {
    Brush.floor: Tile.floor,
    Brush.wall: Tile.wall,
    Brush.target: Tile.target,
    Brush.onewayUp: Tile.onewayUp,
    Brush.onewayRight: Tile.onewayRight,
    Brush.onewayDown: Tile.onewayDown,
    Brush.onewayLeft: Tile.onewayLeft,
    Brush.switchA: Tile.switchA,
    Brush.switchB: Tile.switchB,
    Brush.gateAOpen: Tile.gateAOpen,
    Brush.gateAClosed: Tile.gateAClosed,
    Brush.gateBOpen: Tile.gateBOpen,
    Brush.gateBClosed: Tile.gateBClosed,
  };

  /// Applies the current brush to [index]. Blocked-tile painting under an
  /// entity evicts the entity (a crate can't live on a wall). Placing the
  /// player moves the single player marker.
  void paint(int index) {
    final tile = _tileBrushes[brush];
    if (tile != null) {
      _tiles[index] = tile;
      final blocked =
          tile == Tile.wall ||
          tile == Tile.gateAClosed ||
          tile == Tile.gateBClosed;
      if (blocked) {
        _crateIndexes.remove(index);
        if (_playerIndex == index) _playerIndex = null;
      }
    } else if (brush == Brush.player) {
      if (_blockedAt(index) || _crateIndexes.contains(index)) return;
      _playerIndex = index;
    } else if (brush == Brush.crate) {
      if (_blockedAt(index) || _playerIndex == index) return;
      _crateIndexes.add(index);
    } else if (brush == Brush.erase) {
      _tiles[index] = Tile.floor;
      _crateIndexes.remove(index);
      if (_playerIndex == index) _playerIndex = null;
    }
    notifyListeners();
  }

  bool _blockedAt(int index) {
    final t = _tiles[index];
    return t == Tile.wall || t == Tile.gateAClosed || t == Tile.gateBClosed;
  }

  /// Immutable core Level, or null while no player is placed.
  Level? toLevel() {
    final player = _playerIndex;
    if (player == null) return null;
    return Level(
      width: width,
      height: height,
      tiles: List.of(_tiles),
      playerIndex: player,
      crateIndexes: _crateIndexes.toList(),
    );
  }

  /// Core-rule validation; noTargets etc. surface through this, plus a
  /// pseudo-check for the missing player (which toLevel can't represent).
  List<String> validationProblems() {
    final level = toLevel();
    if (level == null) return const ['Place the player.'];
    final result = const SokobanPlus().validateStructure(level);
    return [
      for (final error in result.errors)
        switch (error) {
          ValidationError.dimensionOutOfBounds => 'Board size out of range.',
          ValidationError.noTargets => 'Add at least one target.',
          ValidationError.fewerCratesThanTargets =>
            'Add crates: at least one per target.',
          ValidationError.entityOutOfBounds => 'An entity is off the board.',
          ValidationError.entityOnBlockedTile =>
            'An entity is on a wall or closed gate.',
          ValidationError.duplicateCrate => 'Two crates share a cell.',
          ValidationError.playerOnCrate => 'Player and crate overlap.',
        },
    ];
  }

  void loadDraft(DraftLevel draft) {
    _tiles.setAll(0, draft.level.tiles);
    _playerIndex = draft.level.playerIndex;
    _crateIndexes
      ..clear()
      ..addAll(draft.level.crateIndexes);
    notifyListeners();
  }
}
