import 'level_repository.dart';

/// Web has no dart:io filesystem, so the default repository is in-memory.
LevelRepository createDefaultRepository() => MemoryLevelRepository();
