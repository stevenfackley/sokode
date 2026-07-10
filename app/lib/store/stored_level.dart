import 'dart:convert';

import 'package:sokode_core/sokode_core.dart';

/// A level saved as its share code — used for published ("mine") and
/// imported levels. The code IS the source of truth: canonical,
/// proof-carrying, and re-verified on load through LevelImporter.
class StoredCode {
  const StoredCode({
    required this.code,
    required this.title,
    required this.kind,
  });

  final String code;
  final String title;

  /// 'mine' or 'imported'.
  final String kind;

  Map<String, Object?> toJson() => {'code': code, 'title': title, 'kind': kind};

  static StoredCode fromJson(Map<String, Object?> json) => StoredCode(
    code: json['code']! as String,
    title: json['title']! as String,
    kind: json['kind']! as String,
  );
}

/// A maker draft — no solution yet, so it CANNOT be a share code (v1 codes
/// require an embedded solution). Raw JSON persistence instead.
class DraftLevel {
  const DraftLevel({required this.name, required this.level});

  final String name; // generated word-pair; still no free text
  final Level level;

  Map<String, Object?> toJson() => {
    'name': name,
    'width': level.width,
    'height': level.height,
    'tiles': [for (final t in level.tiles) t.nibble],
    'player': level.playerIndex,
    'crates': level.crateIndexes,
  };

  /// Total: returns null instead of throwing on malformed/hostile JSON —
  /// drafts only ever come from our own writes, but disk is still input.
  static DraftLevel? fromJson(Map<String, Object?> json) {
    try {
      final tiles = <Tile>[];
      for (final n in json['tiles']! as List) {
        final tile = Tile.fromNibble(n as int);
        if (tile == null) return null;
        tiles.add(tile);
      }
      final width = json['width']! as int;
      final height = json['height']! as int;
      if (tiles.length != width * height) return null;
      return DraftLevel(
        name: json['name']! as String,
        level: Level(
          width: width,
          height: height,
          tiles: tiles,
          playerIndex: json['player']! as int,
          crateIndexes: [for (final c in json['crates']! as List) c as int],
        ),
      );
    } on Object {
      return null;
    }
  }
}

String encodeStoreFile(List<StoredCode> codes, List<DraftLevel> drafts) =>
    jsonEncode({
      'version': 1,
      'codes': [for (final c in codes) c.toJson()],
      'drafts': [for (final d in drafts) d.toJson()],
    });
