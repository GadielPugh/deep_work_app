import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:deep_work/models/coach_feedback_entry.dart';
import 'package:deep_work/models/coach_message_snapshot.dart';

class LocalCoachStorageService {
  static const _feedbackKey = 'coach_feedback_entries_v1';
  static const _snapshotKey = 'coach_message_snapshots_v1';
  static const _maxEntries = 100;

  Future<List<CoachFeedbackEntry>> getFeedbackEntries() async {
    final values = await _readList(_feedbackKey);
    return values.map(CoachFeedbackEntry.fromJson).toList(growable: false);
  }

  Future<void> saveFeedback(CoachFeedbackEntry entry) async {
    await _appendItem(_feedbackKey, entry.toJson());
  }

  Future<List<CoachMessageSnapshot>> getMessageSnapshots() async {
    final values = await _readList(_snapshotKey);
    return values.map(CoachMessageSnapshot.fromJson).toList(growable: false);
  }

  Future<void> saveMessageSnapshot(CoachMessageSnapshot snapshot) async {
    await _appendItem(_snapshotKey, snapshot.toJson());
  }

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _appendItem(String key, Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await _readList(key);
    final updated = [...current, item];
    final trimmed = updated.length <= _maxEntries
        ? updated
        : updated.sublist(updated.length - _maxEntries);
    await prefs.setString(key, jsonEncode(trimmed));
  }
}
