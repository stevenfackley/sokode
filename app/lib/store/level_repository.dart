import 'stored_level.dart';

/// Local persistence seam (spec §8): a future backend implements this same
/// interface without touching game logic or UI.
abstract interface class LevelRepository {
  Future<List<StoredCode>> loadCodes();
  Future<List<DraftLevel>> loadDrafts();
  Future<void> saveCode(StoredCode code);
  Future<void> saveDraft(DraftLevel draft);
  Future<void> deleteCode(String code);
  Future<void> deleteDraft(String name);
}

/// In-memory implementation: web fallback (no dart:io) and test double.
class MemoryLevelRepository implements LevelRepository {
  final List<StoredCode> _codes = [];
  final List<DraftLevel> _drafts = [];

  @override
  Future<List<StoredCode>> loadCodes() async => List.of(_codes);

  @override
  Future<List<DraftLevel>> loadDrafts() async => List.of(_drafts);

  @override
  Future<void> saveCode(StoredCode code) async {
    _codes
      ..removeWhere((c) => c.code == code.code)
      ..add(code);
  }

  @override
  Future<void> saveDraft(DraftLevel draft) async {
    _drafts
      ..removeWhere((d) => d.name == draft.name)
      ..add(draft);
  }

  @override
  Future<void> deleteCode(String code) async =>
      _codes.removeWhere((c) => c.code == code);

  @override
  Future<void> deleteDraft(String name) async =>
      _drafts.removeWhere((d) => d.name == name);
}
