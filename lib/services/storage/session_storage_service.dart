import 'package:deep_work/session_model.dart';

/// Abstract storage service for sessions.
///
/// UI and State Management layers use this interface only.
/// Implementations: [LocalSessionStorageService] (SQLite), [FakeSessionStorageService] (tests).
abstract class SessionStorageService {
  Future<List<Session>> getAllSessions();
  Future<int> insertSession({
    required String intention,
    required String category,
    required DateTime startedAt,
    required DateTime stoppedAt,
    required int durationSeconds,
    required String outcome,
    String? reflection,
  });
  Future<void> deleteSession(int id);
  Future<List<Map<String, dynamic>>> getAllRowsForExport();
}
