class LocalSuccessStat {
  const LocalSuccessStat({this.attempts = 0, this.successes = 0});

  final int attempts;
  final int successes;

  double get successRate => attempts == 0 ? 0.0 : successes / attempts;

  LocalSuccessStat add({required bool success}) {
    return LocalSuccessStat(
      attempts: attempts + 1,
      successes: successes + (success ? 1 : 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'attempts': attempts,
    'successes': successes,
  };

  factory LocalSuccessStat.fromJson(Map<String, dynamic> json) {
    return LocalSuccessStat(
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      successes: (json['successes'] as num?)?.toInt() ?? 0,
    );
  }
}

class LocalPersonalizationProfile {
  const LocalPersonalizationProfile({
    this.totalSessions = 0,
    this.totalSuccesses = 0,
    this.categoryStats = const {},
    this.timeBlockStats = const {},
    this.categoryTimeBlockStats = const {},
    this.durationBucketCountsByCategory = const {},
    this.durationBucketSuccessCountsByCategory = const {},
    this.reflectionThemeCounts = const {},
    this.coachHelpfulCount = 0,
    this.coachNotHelpfulCount = 0,
    this.currentSuccessStreak = 0,
    this.currentFailureStreak = 0,
    this.recentOutcomes = const [],
  });

  final int totalSessions;
  final int totalSuccesses;
  final Map<String, LocalSuccessStat> categoryStats;
  final Map<String, LocalSuccessStat> timeBlockStats;
  final Map<String, LocalSuccessStat> categoryTimeBlockStats;
  final Map<String, Map<String, int>> durationBucketCountsByCategory;
  final Map<String, Map<String, int>> durationBucketSuccessCountsByCategory;
  final Map<String, int> reflectionThemeCounts;
  final int coachHelpfulCount;
  final int coachNotHelpfulCount;
  final int currentSuccessStreak;
  final int currentFailureStreak;
  final List<bool> recentOutcomes;

  static const empty = LocalPersonalizationProfile();

  double get overallSuccessRate =>
      totalSessions == 0 ? 0.0 : totalSuccesses / totalSessions;

  int get coachFeedbackCount => coachHelpfulCount + coachNotHelpfulCount;

  double get coachHelpfulRate =>
      coachFeedbackCount == 0 ? 0.5 : coachHelpfulCount / coachFeedbackCount;

  LocalPersonalizationProfile recordSession({
    required String categoryId,
    required String timeBlock,
    required String durationBucket,
    required bool success,
    required Iterable<String> reflectionThemes,
  }) {
    final normalizedCategory = _normalizeKey(categoryId);
    final normalizedTimeBlock = _normalizeKey(timeBlock);
    final normalizedDurationBucket = _normalizeKey(durationBucket);
    final categoryTimeKey = _categoryTimeKey(
      normalizedCategory,
      normalizedTimeBlock,
    );

    final updatedRecent = [...recentOutcomes, success];
    final trimmedRecent = updatedRecent.length <= 10
        ? updatedRecent
        : updatedRecent.sublist(updatedRecent.length - 10);

    return LocalPersonalizationProfile(
      totalSessions: totalSessions + 1,
      totalSuccesses: totalSuccesses + (success ? 1 : 0),
      categoryStats: _addSuccessStat(
        categoryStats,
        normalizedCategory,
        success: success,
      ),
      timeBlockStats: _addSuccessStat(
        timeBlockStats,
        normalizedTimeBlock,
        success: success,
      ),
      categoryTimeBlockStats: _addSuccessStat(
        categoryTimeBlockStats,
        categoryTimeKey,
        success: success,
      ),
      durationBucketCountsByCategory: _incrementNestedCount(
        durationBucketCountsByCategory,
        normalizedCategory,
        normalizedDurationBucket,
      ),
      durationBucketSuccessCountsByCategory: success
          ? _incrementNestedCount(
              durationBucketSuccessCountsByCategory,
              normalizedCategory,
              normalizedDurationBucket,
            )
          : durationBucketSuccessCountsByCategory,
      reflectionThemeCounts: _addThemeCounts(
        reflectionThemeCounts,
        reflectionThemes,
      ),
      coachHelpfulCount: coachHelpfulCount,
      coachNotHelpfulCount: coachNotHelpfulCount,
      currentSuccessStreak: success ? currentSuccessStreak + 1 : 0,
      currentFailureStreak: success ? 0 : currentFailureStreak + 1,
      recentOutcomes: trimmedRecent,
    );
  }

  LocalPersonalizationProfile recordCoachFeedback({required bool wasHelpful}) {
    return LocalPersonalizationProfile(
      totalSessions: totalSessions,
      totalSuccesses: totalSuccesses,
      categoryStats: categoryStats,
      timeBlockStats: timeBlockStats,
      categoryTimeBlockStats: categoryTimeBlockStats,
      durationBucketCountsByCategory: durationBucketCountsByCategory,
      durationBucketSuccessCountsByCategory:
          durationBucketSuccessCountsByCategory,
      reflectionThemeCounts: reflectionThemeCounts,
      coachHelpfulCount: coachHelpfulCount + (wasHelpful ? 1 : 0),
      coachNotHelpfulCount: coachNotHelpfulCount + (wasHelpful ? 0 : 1),
      currentSuccessStreak: currentSuccessStreak,
      currentFailureStreak: currentFailureStreak,
      recentOutcomes: recentOutcomes,
    );
  }

  String? preferredDurationBucketForCategory(String categoryId) {
    final normalizedCategory = _normalizeKey(categoryId);
    final successful =
        durationBucketSuccessCountsByCategory[normalizedCategory] ?? const {};
    final all = durationBucketCountsByCategory[normalizedCategory] ?? const {};
    final source = successful.isNotEmpty ? successful : all;
    if (source.isEmpty) return null;

    final entries = source.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return _durationBucketRank(a.key).compareTo(_durationBucketRank(b.key));
      });
    return entries.first.key;
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'totalSessions': totalSessions,
      'totalSuccesses': totalSuccesses,
      'categoryStats': _statMapToJson(categoryStats),
      'timeBlockStats': _statMapToJson(timeBlockStats),
      'categoryTimeBlockStats': _statMapToJson(categoryTimeBlockStats),
      'durationBucketCountsByCategory': durationBucketCountsByCategory,
      'durationBucketSuccessCountsByCategory':
          durationBucketSuccessCountsByCategory,
      'reflectionThemeCounts': reflectionThemeCounts,
      'coachHelpfulCount': coachHelpfulCount,
      'coachNotHelpfulCount': coachNotHelpfulCount,
      'currentSuccessStreak': currentSuccessStreak,
      'currentFailureStreak': currentFailureStreak,
      'recentOutcomes': recentOutcomes,
    };
  }

  factory LocalPersonalizationProfile.fromJson(Map<String, dynamic> json) {
    return LocalPersonalizationProfile(
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      totalSuccesses: (json['totalSuccesses'] as num?)?.toInt() ?? 0,
      categoryStats: _statMapFromJson(json['categoryStats']),
      timeBlockStats: _statMapFromJson(json['timeBlockStats']),
      categoryTimeBlockStats: _statMapFromJson(json['categoryTimeBlockStats']),
      durationBucketCountsByCategory: _nestedIntMapFromJson(
        json['durationBucketCountsByCategory'],
      ),
      durationBucketSuccessCountsByCategory: _nestedIntMapFromJson(
        json['durationBucketSuccessCountsByCategory'],
      ),
      reflectionThemeCounts: _intMapFromJson(json['reflectionThemeCounts']),
      coachHelpfulCount: (json['coachHelpfulCount'] as num?)?.toInt() ?? 0,
      coachNotHelpfulCount:
          (json['coachNotHelpfulCount'] as num?)?.toInt() ?? 0,
      currentSuccessStreak:
          (json['currentSuccessStreak'] as num?)?.toInt() ?? 0,
      currentFailureStreak:
          (json['currentFailureStreak'] as num?)?.toInt() ?? 0,
      recentOutcomes: (json['recentOutcomes'] as List<dynamic>? ?? const [])
          .whereType<bool>()
          .toList(growable: false),
    );
  }

  static String categoryTimeKey(String categoryId, String timeBlock) {
    return _categoryTimeKey(
      _normalizeKey(categoryId),
      _normalizeKey(timeBlock),
    );
  }

  static String _categoryTimeKey(String categoryId, String timeBlock) {
    return '$categoryId@$timeBlock';
  }

  static String _normalizeKey(String value) => value.trim().toLowerCase();

  static Map<String, LocalSuccessStat> _addSuccessStat(
    Map<String, LocalSuccessStat> source,
    String key, {
    required bool success,
  }) {
    return {
      ...source,
      key: (source[key] ?? const LocalSuccessStat()).add(success: success),
    };
  }

  static Map<String, Map<String, int>> _incrementNestedCount(
    Map<String, Map<String, int>> source,
    String outerKey,
    String innerKey,
  ) {
    final inner = source[outerKey] ?? const {};
    return {
      ...source,
      outerKey: {...inner, innerKey: (inner[innerKey] ?? 0) + 1},
    };
  }

  static Map<String, int> _addThemeCounts(
    Map<String, int> source,
    Iterable<String> themes,
  ) {
    final updated = {...source};
    for (final theme in themes) {
      final key = _normalizeKey(theme);
      if (key.isEmpty) continue;
      updated[key] = (updated[key] ?? 0) + 1;
    }
    return updated;
  }

  static Map<String, dynamic> _statMapToJson(
    Map<String, LocalSuccessStat> source,
  ) {
    return source.map((key, value) => MapEntry(key, value.toJson()));
  }

  static Map<String, LocalSuccessStat> _statMapFromJson(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, raw) {
      final map = raw is Map<String, dynamic>
          ? raw
          : raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      return MapEntry(key.toString(), LocalSuccessStat.fromJson(map));
    });
  }

  static Map<String, Map<String, int>> _nestedIntMapFromJson(Object? value) {
    if (value is! Map) return const {};
    return value.map((outerKey, rawInner) {
      return MapEntry(outerKey.toString(), _intMapFromJson(rawInner));
    });
  }

  static Map<String, int> _intMapFromJson(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, raw) {
      return MapEntry(key.toString(), (raw as num?)?.toInt() ?? 0);
    });
  }

  static int _durationBucketRank(String bucket) {
    switch (bucket) {
      case 'short':
        return 0;
      case 'standard':
        return 1;
      case 'long':
        return 2;
      case 'extended':
        return 3;
      default:
        return 4;
    }
  }
}
