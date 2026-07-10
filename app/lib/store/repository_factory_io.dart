import 'json_file_level_repository.dart';
import 'level_repository.dart';

/// Native platforms persist to a JSON file in the app documents directory.
LevelRepository createDefaultRepository() =>
    JsonFileLevelRepository.appDocuments();
