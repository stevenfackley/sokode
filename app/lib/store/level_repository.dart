import 'repository_factory_web.dart'
    if (dart.library.io) 'repository_factory_io.dart';
import 'stored_level.dart';

/// The platform-appropriate repository: a JSON file on native platforms, an
/// in-memory store on web (no dart:io). Wired via conditional import so
/// `flutter build web` never pulls dart:io into its graph.
LevelRepository defaultRepository() => createDefaultRepository();

/// Local persistence seam (spec §8): a future backend implements this same
/// interface without touching game logic or UI.
abstract interface class LevelRepository {
  Future<List<StoredCode>> loadCodes();
  Future<List<DraftLevel>> loadDrafts();
  Future<void> saveCode(StoredCode code);
  Future<void> saveDraft(DraftLevel draft);
  Future<void> deleteCode(String code);
  Future<void> deleteDraft(String name);

  /// Sticky one-shot UI markers (currently just [onboardingSeenFlag]).
  ///
  /// A set of opaque strings rather than a field per feature: this is the
  /// app's only storage seam, and a growing interface would force every
  /// future implementation to grow with it. A backend that has no use for
  /// them can return an empty set forever without breaking play.
  Future<Set<String>> loadFlags();
  Future<void> setFlag(String flag);
}

/// Marks that the first-run walkthrough has been shown. Versioned in the
/// name so a materially rewritten walkthrough can show once more.
const String onboardingSeenFlag = 'onboarding-seen-v1';

/// In-memory implementation: web fallback (no dart:io) and test double.
class MemoryLevelRepository implements LevelRepository {
  final List<StoredCode> _codes = [];
  final List<DraftLevel> _drafts = [];
  final Set<String> _flags = {};

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

  @override
  Future<Set<String>> loadFlags() async => Set.of(_flags);

  @override
  Future<void> setFlag(String flag) async => _flags.add(flag);
}
