import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/services/storage/session_storage_service.dart';

class LocalSessionStorageWebService implements SessionStorageService {
  static const String _storageKey = 'deep_work_sessions_v1';

  @override
  Future<List<Session>> getAllSessions() async {
    final rows = await _readRows();
    final sessions = rows.map(_sessionFromRow).toList(growable: false);
    return List<Session>.from(sessions)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

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
    final rows = await _readRows();
    final nextId = _nextId(rows);
    final createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;

    rows.add({
      'id': nextId,
      'intention': intention,
      'category': category,
      'started_at_ms': startedAt.toUtc().millisecondsSinceEpoch,
      'stopped_at_ms': stoppedAt.toUtc().millisecondsSinceEpoch,
      'duration_seconds': durationSeconds,
      'outcome': outcome,
      'reflection': reflection,
      'created_at_ms': createdAt,
    });

    await _writeRows(rows);
    return nextId;
  }

  @override
  Future<void> deleteSession(int id) async {
    final rows = await _readRows();
    rows.removeWhere((row) => row['id'] == id);
    await _writeRows(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllRowsForExport() async {
    final rows = await _readRows();
    rows.sort(
      (a, b) => _intValue(
        a['started_at_ms'],
      ).compareTo(_intValue(b['started_at_ms'])),
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> _readRows() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (row) => row.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: true);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeRows(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(rows));
  }

  int _nextId(List<Map<String, dynamic>> rows) {
    var maxId = 0;
    for (final row in rows) {
      final id = _intValue(row['id']);
      if (id > maxId) maxId = id;
    }
    return maxId + 1;
  }

  Session _sessionFromRow(Map<String, dynamic> row) {
    final startedMs = _intValue(row['started_at_ms']);
    final stoppedMs = _intValue(row['stopped_at_ms']);

    return Session(
      id: _intValue(row['id']),
      intention: row['intention']?.toString() ?? '',
      durationMinutes: _intValue(row['duration_seconds']) ~/ 60,
      outcome: _outcomeFromString(row['outcome']?.toString() ?? ''),
      dateTime: DateTime.fromMillisecondsSinceEpoch(startedMs, isUtc: true),
      categoryId: row['category']?.toString() ?? 'other',
      reflection: row['reflection']?.toString(),
      startedAt: DateTime.fromMillisecondsSinceEpoch(startedMs, isUtc: true),
      stoppedAt: DateTime.fromMillisecondsSinceEpoch(stoppedMs, isUtc: true),
    );
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  CompletionStatus _outcomeFromString(String s) {
    return CompletionStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => CompletionStatus.no,
    );
  }
}
