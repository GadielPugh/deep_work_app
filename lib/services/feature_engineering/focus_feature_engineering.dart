import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/session_model.dart';

/// Per-session features derived from the stored focus-session history.
class FocusSessionFeatures {
  const FocusSessionFeatures({
    required this.hourOfDay,
    required this.dayOfWeek,
    required this.isWeekend,
    required this.sessionDurationMinutes,
    required this.intentionLength,
    required this.reflectionLength,
    required this.categoryId,
    required this.outcomeSuccess,
    required this.timeSincePreviousSessionMinutes,
    required this.rolling7dAvgDurationMinutesForCategoryAndOutcomeSuccess,
    required this.rolling7dSuccessRateForCategory,
  });

  final int hourOfDay; // 0..23 (local time)
  final int dayOfWeek; // 1..7 (local time; DateTime.weekday, Mon=1)
  final bool isWeekend;
  final int sessionDurationMinutes;
  final int intentionLength;
  final int reflectionLength;
  final String categoryId;
  final int outcomeSuccess; // 1 if CompletionStatus.yes, else 0

  /// Minutes between this session start and the previous session start.
  /// Null when this is the user's first recorded session.
  final double? timeSincePreviousSessionMinutes;

  /// Average duration in the previous 7 days for the same category and
  /// the same binary outcome_success value.
  final double rolling7dAvgDurationMinutesForCategoryAndOutcomeSuccess;

  /// Success rate in the previous 7 days for the same category.
  final double rolling7dSuccessRateForCategory; // 0..1
}

/// Features needed to predict the next session success probability.
class FocusCandidateFeatures {
  const FocusCandidateFeatures({
    required this.hourOfDay,
    required this.dayOfWeek,
    required this.isWeekend,
    required this.sessionDurationMinutes,
    required this.intentionLength,
    required this.reflectionLength,
    required this.categoryId,
    required this.timeSincePreviousSessionMinutes,
    required this.rolling7dSuccessRateForCategory,
    required this.hourSuccessRateForCategoryAtHour,
    required this.avgDurationMinutesForCategory,
    required this.avgDurationMinutesForCategorySuccess,
    required this.avgDurationMinutesForCategoryFailure,
  });

  final int hourOfDay; // 0..23 (local time)
  final int dayOfWeek; // 1..7 (local time)
  final bool isWeekend;
  final int sessionDurationMinutes;
  final int intentionLength;
  final int reflectionLength;
  final String categoryId;
  final double? timeSincePreviousSessionMinutes;

  /// Rolling success rate over the previous 7 days.
  final double rolling7dSuccessRateForCategory; // 0..1

  /// Rolling success rate over the previous 7 days for sessions that started
  /// during the same hour-of-day.
  final double hourSuccessRateForCategoryAtHour; // 0..1

  final double avgDurationMinutesForCategory;
  final double avgDurationMinutesForCategorySuccess;
  final double avgDurationMinutesForCategoryFailure;
}

/// Builds ML-ready features from existing session data.
class FocusFeatureEngineeringService {
  FocusFeatureEngineeringService({
    this.rollingWindowDays = 7,
  });

  /// Rolling window length used by derived features.
  final int rollingWindowDays;

  List<FocusSessionFeatures> buildFeatureDataset(
    List<Session> sessions, {
    DateTime? now,
  }) {
    if (sessions.isEmpty) return const [];

    final sorted = [...sessions]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final features = <FocusSessionFeatures>[];

    for (var i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      final local = s.dateTime.toLocal();
      final outcomeSuccess = s.outcome == CompletionStatus.yes ? 1 : 0;

      final timeSincePrev = i == 0
          ? null
          : local.difference(sorted[i - 1].dateTime.toLocal()).inMinutes.toDouble();

      final windowStart = local.subtract(Duration(days: rollingWindowDays));
      final prevSessions = sorted.where((p) {
        final pLocal = p.dateTime.toLocal();
        return pLocal.isAfter(windowStart) &&
            pLocal.isBefore(local) &&
            p.categoryId == s.categoryId &&
            (p.outcome == CompletionStatus.yes ? 1 : 0) == outcomeSuccess;
      });

      final prevCategorySessions = sorted.where((p) {
        final pLocal = p.dateTime.toLocal();
        return pLocal.isAfter(windowStart) &&
            pLocal.isBefore(local) &&
            p.categoryId == s.categoryId;
      });

      final prevList = prevSessions.toList();
      final prevCategoryList = prevCategorySessions.toList();

      final rollingAvgDur = prevList.isEmpty
          ? 0.0
          : prevList.map((p) => p.durationMinutes).reduce((a, b) => a + b) /
              prevList.length;

      final totalPrevCategory = prevCategoryList.length;
      final rollingSuccessRate = totalPrevCategory == 0
          ? 0.0
          : prevCategoryList.where((p) => p.outcome == CompletionStatus.yes).length /
              totalPrevCategory;

      features.add(FocusSessionFeatures(
        hourOfDay: local.hour,
        dayOfWeek: local.weekday,
        isWeekend: local.weekday == DateTime.saturday || local.weekday == DateTime.sunday,
        sessionDurationMinutes: s.durationMinutes,
        intentionLength: s.intention.trim().length,
        reflectionLength: s.reflection?.trim().length ?? 0,
        categoryId: s.categoryId,
        outcomeSuccess: outcomeSuccess,
        timeSincePreviousSessionMinutes: timeSincePrev,
        rolling7dAvgDurationMinutesForCategoryAndOutcomeSuccess: rollingAvgDur,
        rolling7dSuccessRateForCategory: rollingSuccessRate,
      ));
    }

    return features;
  }

  /// Builds candidate features for a hypothetical next session.
  ///
  /// Note: candidate sessions don't have an outcome yet, so outcome-derived
  /// features are represented as historical averages.
  FocusCandidateFeatures buildCandidateFeatures({
    required DateTime now,
    required List<Session> sessions,
    required String categoryId,
    required int sessionDurationMinutes,
    int intentionLength = 0,
    int reflectionLength = 0,
  }) {
    final sorted = [...sessions]..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final localNow = now.toLocal();
    final hour = localNow.hour;
    final dayOfWeek = localNow.weekday;
    final isWeekend = dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday;

    final rollingStart = localNow.subtract(Duration(days: rollingWindowDays));
    final pastRollingSessions = sorted.where((s) {
      final local = s.dateTime.toLocal();
      return local.isAfter(rollingStart) && local.isBefore(localNow);
    }).toList();

    final pastCategorySessions = pastRollingSessions.where((s) => s.categoryId == categoryId).toList();
    final total = pastCategorySessions.length;

    final rollingSuccessRate = total == 0
        ? 0.0
        : pastCategorySessions.where((s) => s.outcome == CompletionStatus.yes).length / total;

    final hourSessions = pastCategorySessions.where((s) => s.dateTime.toLocal().hour == hour).toList();
    final hourSuccessRate = hourSessions.isEmpty
        ? rollingSuccessRate
        : hourSessions.where((s) => s.outcome == CompletionStatus.yes).length / hourSessions.length;

    final avgDurationForCategory = total == 0
        ? 0.0
        : pastCategorySessions.map((s) => s.durationMinutes).reduce((a, b) => a + b) / total;

    final successSessions = pastCategorySessions.where((s) => s.outcome == CompletionStatus.yes).toList();
    final failureSessions = pastCategorySessions.where((s) => s.outcome != CompletionStatus.yes).toList();

    final avgDurationSuccess = successSessions.isEmpty
        ? avgDurationForCategory
        : successSessions.map((s) => s.durationMinutes).reduce((a, b) => a + b) / successSessions.length;
    final avgDurationFailure = failureSessions.isEmpty
        ? avgDurationForCategory
        : failureSessions.map((s) => s.durationMinutes).reduce((a, b) => a + b) / failureSessions.length;

    final lastSession = sorted.isEmpty ? null : sorted.first;
    final timeSincePrevMinutes = lastSession == null
        ? null
        : localNow.difference(lastSession.dateTime.toLocal()).inMinutes.toDouble();

    return FocusCandidateFeatures(
      hourOfDay: hour,
      dayOfWeek: dayOfWeek,
      isWeekend: isWeekend,
      sessionDurationMinutes: sessionDurationMinutes,
      intentionLength: intentionLength,
      reflectionLength: reflectionLength,
      categoryId: categoryId,
      timeSincePreviousSessionMinutes: timeSincePrevMinutes,
      rolling7dSuccessRateForCategory: rollingSuccessRate,
      hourSuccessRateForCategoryAtHour: hourSuccessRate,
      avgDurationMinutesForCategory: avgDurationForCategory,
      avgDurationMinutesForCategorySuccess: avgDurationSuccess,
      avgDurationMinutesForCategoryFailure: avgDurationFailure,
    );
  }
}

