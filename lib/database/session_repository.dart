import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/session_type.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

const String _table = 'sessions';

/// CRUD for focus sessions. Use this everywhere instead of raw DB access.
/// Data shape is ready for ML export: one row per session, timestamps in UTC ms.
class SessionRepository {
  static Future<Database> get _db => AppDatabase.database;

  /// Insert a new session. Returns the new row id.
  static Future<int> insert({
    required String intention,
    required String category,
    required DateTime startedAt,
    required DateTime stoppedAt,
    required int durationSeconds,
    required String outcome,
    String? reflection,
  }) async {
    final db = await _db;
    final now = DateTime.now().toUtc();
    return db.insert(
      _table,
      {
        'intention': intention,
        'category': category,
        'started_at_ms': startedAt.toUtc().millisecondsSinceEpoch,
        'stopped_at_ms': stoppedAt.toUtc().millisecondsSinceEpoch,
        'duration_seconds': durationSeconds,
        'outcome': outcome,
        'reflection': reflection,
        'created_at_ms': now.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// All sessions, newest first (by started_at).
  static Future<List<Session>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      _table,
      orderBy: 'started_at_ms DESC',
    );
    return rows.map(_sessionFromRow).toList();
  }

  /// One session by id. Returns null if not found.
  static Future<Session?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _sessionFromRow(rows.first);
  }

  /// Delete a session by id.
  static Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Raw rows for export (e.g. CSV/JSON for ML). Columns match schema.
  static Future<List<Map<String, dynamic>>> getAllRowsForExport() async {
    final db = await _db;
    return db.query(_table, orderBy: 'started_at_ms ASC');
  }

  static Session _sessionFromRow(Map<String, dynamic> row) {
    final id = row['id'] as int?;
    final intention = row['intention'] as String;
    final category = _categoryFromString(row['category'] as String);
    final startedMs = row['started_at_ms'] as int;
    final stoppedMs = row['stopped_at_ms'] as int;
    final durationSeconds = row['duration_seconds'] as int;
    final outcome = _outcomeFromString(row['outcome'] as String);
    final reflection = row['reflection'] as String?;

    final startedAt = DateTime.fromMillisecondsSinceEpoch(startedMs, isUtc: true);
    final stoppedAt = DateTime.fromMillisecondsSinceEpoch(stoppedMs, isUtc: true);

    return Session(
      id: id,
      intention: intention,
      durationMinutes: durationSeconds ~/ 60,
      outcome: outcome,
      dateTime: startedAt,
      sessionType: category,
      reflection: reflection,
      startedAt: startedAt,
      stoppedAt: stoppedAt,
    );
  }

  static SessionType _categoryFromString(String s) {
    return SessionType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => SessionType.other,
    );
  }

  static CompletionStatus _outcomeFromString(String s) {
    return CompletionStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => CompletionStatus.no,
    );
  }
}
