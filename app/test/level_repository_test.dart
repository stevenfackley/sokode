import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sokode_app/store/json_file_level_repository.dart';
import 'package:sokode_app/store/level_repository.dart';
import 'package:sokode_app/store/stored_level.dart';
import 'package:sokode_core/sokode_core.dart';

Level _draftLevel() => Level(
  width: 4,
  height: 4,
  tiles: List.filled(16, Tile.floor),
  playerIndex: 5,
  crateIndexes: const [6],
);

Map<String, Object?> _draftJson() =>
    DraftLevel(name: 'x', level: _draftLevel()).toJson();

void main() {
  late Directory dir;
  late JsonFileLevelRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sokode_test');
    repo = JsonFileLevelRepository(File('${dir.path}/levels.json'));
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('empty load returns empty lists', () async {
    expect(await repo.loadCodes(), isEmpty);
    expect(await repo.loadDrafts(), isEmpty);
  });

  test('save/load roundtrip for codes', () async {
    await repo.saveCode(
      const StoredCode(code: 'ABC', title: 'Brave Crate', kind: 'mine'),
    );
    final codes = await repo.loadCodes();
    expect(codes.single.code, 'ABC');
    expect(codes.single.title, 'Brave Crate');
    expect(codes.single.kind, 'mine');
  });

  test('save/load roundtrip for drafts', () async {
    await repo.saveDraft(DraftLevel(name: 'Draft 1', level: _draftLevel()));
    final drafts = await repo.loadDrafts();
    expect(drafts.single.name, 'Draft 1');
    expect(drafts.single.level.playerIndex, _draftLevel().playerIndex);
    expect(drafts.single.level.crateIndexes, _draftLevel().crateIndexes);
  });

  test('saveCode upserts by code', () async {
    await repo.saveCode(
      const StoredCode(code: 'ABC', title: 'One', kind: 'mine'),
    );
    await repo.saveCode(
      const StoredCode(code: 'ABC', title: 'Two', kind: 'imported'),
    );
    final codes = await repo.loadCodes();
    expect(codes, hasLength(1));
    expect(codes.single.title, 'Two');
  });

  test('deleteCode removes it', () async {
    await repo.saveCode(
      const StoredCode(code: 'ABC', title: 'One', kind: 'mine'),
    );
    await repo.deleteCode('ABC');
    expect(await repo.loadCodes(), isEmpty);
  });

  test('corrupt file fails open with empty lists', () async {
    await File('${dir.path}/levels.json').writeAsString('}{ not json');
    expect(await repo.loadCodes(), isEmpty);
    expect(await repo.loadDrafts(), isEmpty);
  });

  test('DraftLevel.fromJson rejects a bad nibble', () {
    final json = _draftJson()..['tiles'] = (List<int>.filled(16, 0)..[0] = 99);
    expect(DraftLevel.fromJson(json), isNull);
  });

  test('DraftLevel.fromJson rejects a tiles/dims mismatch', () {
    final json = _draftJson()..['tiles'] = [0, 0];
    expect(DraftLevel.fromJson(json), isNull);
  });

  test('flags start empty, persist, and are idempotent', () async {
    expect(await repo.loadFlags(), isEmpty);
    await repo.setFlag(onboardingSeenFlag);
    await repo.setFlag(onboardingSeenFlag);
    expect(await repo.loadFlags(), {onboardingSeenFlag});
  });

  test('writing levels does not clear flags', () async {
    await repo.setFlag(onboardingSeenFlag);
    await repo.saveCode(
      const StoredCode(code: 'ABC', title: 'One', kind: 'mine'),
    );
    await repo.saveDraft(DraftLevel(name: 'Draft 1', level: _draftLevel()));
    await repo.deleteCode('ABC');
    expect(await repo.loadFlags(), {onboardingSeenFlag});
  });

  test('corrupt file fails open on flags too', () async {
    await File('${dir.path}/levels.json').writeAsString('}{ not json');
    expect(await repo.loadFlags(), isEmpty);
  });

  test('MemoryLevelRepository matches the file store on flags', () async {
    final memory = MemoryLevelRepository();
    expect(await memory.loadFlags(), isEmpty);
    await memory.setFlag(onboardingSeenFlag);
    expect(await memory.loadFlags(), {onboardingSeenFlag});
  });
}
