import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'level_repository.dart';
import 'stored_level.dart';

/// Single-JSON-file implementation. Levels number in the dozens; one file
/// read/written whole is simpler and atomic-enough (write temp + rename).
///
/// Kept in its own file (importing dart:io) so web-reachable code never
/// pulls dart:io into the `flutter build web` graph — the web build uses
/// [MemoryLevelRepository] instead (wired in main.dart via conditional
/// import).
class JsonFileLevelRepository implements LevelRepository {
  /// Explicit file — used by tests.
  JsonFileLevelRepository(File file) : _file = file;

  /// Lazily resolves the app documents directory on first use — the normal
  /// runtime path. path_provider is a plugin, so this branch is never hit
  /// in plain unit tests (which use the explicit-file constructor).
  JsonFileLevelRepository.appDocuments() : _file = null;

  File? _file;

  Future<File> _resolveFile() async {
    final existing = _file;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    return _file = File('${dir.path}/sokode_levels.json');
  }

  Future<(List<StoredCode>, List<DraftLevel>)> _read() async {
    final file = await _resolveFile();
    if (!await file.exists()) return (<StoredCode>[], <DraftLevel>[]);
    try {
      final root = jsonDecode(await file.readAsString());
      if (root is! Map<String, Object?>) {
        return (<StoredCode>[], <DraftLevel>[]);
      }
      final codes = <StoredCode>[
        for (final c in (root['codes'] as List? ?? []))
          StoredCode.fromJson((c as Map).cast<String, Object?>()),
      ];
      final drafts = <DraftLevel>[
        for (final d in (root['drafts'] as List? ?? []))
          ?DraftLevel.fromJson((d as Map).cast<String, Object?>()),
      ];
      return (codes, drafts);
    } on Object {
      // Corrupt store: fail open with an empty library rather than crash.
      return (<StoredCode>[], <DraftLevel>[]);
    }
  }

  Future<void> _write(List<StoredCode> codes, List<DraftLevel> drafts) async {
    final file = await _resolveFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(encodeStoreFile(codes, drafts), flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<List<StoredCode>> loadCodes() async => (await _read()).$1;

  @override
  Future<List<DraftLevel>> loadDrafts() async => (await _read()).$2;

  @override
  Future<void> saveCode(StoredCode code) async {
    final (codes, drafts) = await _read();
    codes
      ..removeWhere((c) => c.code == code.code)
      ..add(code);
    await _write(codes, drafts);
  }

  @override
  Future<void> saveDraft(DraftLevel draft) async {
    final (codes, drafts) = await _read();
    drafts
      ..removeWhere((d) => d.name == draft.name)
      ..add(draft);
    await _write(codes, drafts);
  }

  @override
  Future<void> deleteCode(String code) async {
    final (codes, drafts) = await _read();
    codes.removeWhere((c) => c.code == code);
    await _write(codes, drafts);
  }

  @override
  Future<void> deleteDraft(String name) async {
    final (codes, drafts) = await _read();
    drafts.removeWhere((d) => d.name == name);
    await _write(codes, drafts);
  }
}
