import 'dart:convert';

import 'package:deep_work/models/coach_feedback_entry.dart';
import 'package:deep_work/models/personalization/local_personalization_profile.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/services/reflection/reflection_tag_extractor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalPersonalizationProfileService {
  LocalPersonalizationProfileService({ReflectionTagExtractor? tagExtractor})
    : _tagExtractor = tagExtractor ?? ReflectionTagExtractor();

  static const _profileKey = 'local_personalization_profile_v1';

  final ReflectionTagExtractor _tagExtractor;

  LocalPersonalizationProfile _profile = LocalPersonalizationProfile.empty;
  bool _isLoaded = false;

  LocalPersonalizationProfile get profile => _profile;

  Future<void> load() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) {
      _profile = LocalPersonalizationProfile.empty;
      _isLoaded = true;
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _profile = LocalPersonalizationProfile.fromJson(decoded);
    } catch (_) {
      _profile = LocalPersonalizationProfile.empty;
    }
    _isLoaded = true;
  }

  Future<void> recordCompletedSession({
    required String categoryId,
    required DateTime startedAt,
    required int durationSeconds,
    required String outcome,
    String? reflection,
  }) async {
    await load();
    final success = outcome == 'yes';
    final themes = reflection == null || reflection.trim().isEmpty
        ? const <String>[]
        : _tagExtractor
              .extractTags(reflection)
              .map((tag) => tag.name)
              .toList(growable: false);

    _profile = _profile.recordSession(
      categoryId: categoryId,
      timeBlock: timeBlockForDateTime(startedAt),
      durationBucket: durationBucketForSeconds(durationSeconds),
      success: success,
      reflectionThemes: themes,
    );
    await _persist();
  }

  Future<void> bootstrapFromSessionsIfEmpty(List<Session> sessions) async {
    await load();
    if (_profile.totalSessions > 0 || sessions.isEmpty) return;

    final chronological = [...sessions]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    var nextProfile = _profile;
    for (final session in chronological) {
      final reflection = session.reflection;
      final themes = reflection == null || reflection.trim().isEmpty
          ? const <String>[]
          : _tagExtractor
                .extractTags(reflection)
                .map((tag) => tag.name)
                .toList(growable: false);
      nextProfile = nextProfile.recordSession(
        categoryId: session.categoryId,
        timeBlock: timeBlockForDateTime(session.startedAt ?? session.dateTime),
        durationBucket: durationBucketForSeconds(session.durationMinutes * 60),
        success: session.outcome.name == 'yes',
        reflectionThemes: themes,
      );
    }
    _profile = nextProfile;
    await _persist();
  }

  Future<void> recordCoachFeedback(CoachFeedbackEntry entry) async {
    await load();
    _profile = _profile.recordCoachFeedback(wasHelpful: entry.wasHelpful);
    await _persist();
  }

  Future<void> clear() async {
    _profile = LocalPersonalizationProfile.empty;
    _isLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(_profile.toJson()));
  }

  static String timeBlockForDateTime(DateTime value) {
    final hour = value.toLocal().hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  static String durationBucketForSeconds(int durationSeconds) {
    final minutes = durationSeconds / 60;
    if (minutes <= 15) return 'short';
    if (minutes <= 30) return 'standard';
    if (minutes <= 45) return 'long';
    return 'extended';
  }
}
