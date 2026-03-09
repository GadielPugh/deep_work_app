import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/session_type.dart';
import 'package:deep_work/services/storage/session_storage_service.dart';

/// In-memory mock storage for tests or development without a real DB.
class FakeSessionStorageService implements SessionStorageService {
  final List<Session> _sessions = [
    Session(
      id: 1,
      intention: 'Complete chapter 3',
      durationMinutes: 45,
      outcome: CompletionStatus.yes,
      dateTime: DateTime(2026, 2, 5, 9, 30),
      sessionType: SessionType.reading,
    ),
    Session(
      id: 2,
      intention: 'Write essay introduction',
      durationMinutes: 30,
      outcome: CompletionStatus.partially,
      dateTime: DateTime(2026, 2, 5, 14, 15),
      sessionType: SessionType.writing,
    ),
  ];
  int _nextId = 3;

  @override
  Future<List<Session>> getAllSessions() async =>
      List.from(_sessions)..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  @override
  Future<int> insertSession({
    required String intention,
    required String category,
    required DateTime startedAt,
    required DateTime stoppedAt,
    required int durationSeconds,
    required String outcome,
    String? reflection,
  }) async {
    final type = SessionType.values.firstWhere(
      (e) => e.name == category,
      orElse: () => SessionType.other,
    );
    final status = CompletionStatus.values.firstWhere(
      (e) => e.name == outcome,
      orElse: () => CompletionStatus.no,
    );
    final id = _nextId++;
    _sessions.add(Session(
      id: id,
      intention: intention,
      durationMinutes: durationSeconds ~/ 60,
      outcome: status,
      dateTime: startedAt,
      sessionType: type,
      reflection: reflection,
      startedAt: startedAt,
      stoppedAt: stoppedAt,
    ));
    return id;
  }

  @override
  Future<void> deleteSession(int id) async {
    _sessions.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllRowsForExport() async =>
      _sessions.map((s) => {
            'id': s.id,
            'intention': s.intention,
            'category': s.sessionType.name,
            'outcome': s.outcome.name,
            'reflection': s.reflection,
          }).toList();
}
