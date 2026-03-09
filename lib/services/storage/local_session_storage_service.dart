import 'package:deep_work/database/session_repository.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/services/storage/session_storage_service.dart';

/// SQLite-backed implementation of [SessionStorageService].
class LocalSessionStorageService implements SessionStorageService {
  @override
  Future<List<Session>> getAllSessions() => SessionRepository.getAll();

  @override
  Future<int> insertSession({
    required String intention,
    required String category,
    required DateTime startedAt,
    required DateTime stoppedAt,
    required int durationSeconds,
    required String outcome,
    String? reflection,
  }) =>
      SessionRepository.insert(
        intention: intention,
        category: category,
        startedAt: startedAt,
        stoppedAt: stoppedAt,
        durationSeconds: durationSeconds,
        outcome: outcome,
        reflection: reflection,
      );

  @override
  Future<void> deleteSession(int id) => SessionRepository.delete(id);

  @override
  Future<List<Map<String, dynamic>>> getAllRowsForExport() =>
      SessionRepository.getAllRowsForExport();
}
