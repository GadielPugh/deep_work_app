import 'dart:convert';

import 'package:deep_work/models/ml/shadow_prediction_log_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalShadowPredictionStorageService {
  static const _shadowLogKey = 'ml_shadow_prediction_log_v1';
  static const _maxEntries = 200;

  Future<List<ShadowPredictionLogEntry>> getEntries() async {
    final values = await _readList();
    return values
        .map(ShadowPredictionLogEntry.fromJson)
        .toList(growable: false);
  }

  Future<void> saveEntry(ShadowPredictionLogEntry entry) async {
    final current = await _readList();
    final updated = [...current, entry.toJson()];
    await _writeTrimmed(updated);
  }

  Future<void> markMostRecentPendingOutcome({
    required DateTime resolvedAt,
    required bool laterSessionSucceeded,
    String? completedSessionCategoryId,
  }) async {
    final current = await getEntries();
    final index = current.lastIndexWhere(
      (entry) => entry.laterSessionSucceeded == null,
    );
    if (index == -1) return;

    final updated = [...current];
    updated[index] = updated[index].copyWithOutcome(
      resolvedAt: resolvedAt,
      laterSessionSucceeded: laterSessionSucceeded,
      completedSessionCategoryId: completedSessionCategoryId,
    );
    await _writeTrimmed(updated.map((entry) => entry.toJson()).toList());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shadowLogKey);
  }

  Future<List<Map<String, dynamic>>> _readList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_shadowLogKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeTrimmed(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = entries.length <= _maxEntries
        ? entries
        : entries.sublist(entries.length - _maxEntries);
    await prefs.setString(_shadowLogKey, jsonEncode(trimmed));
  }
}
