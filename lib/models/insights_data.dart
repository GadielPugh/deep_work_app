import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/analytics/insights_analytics_dtos.dart';
import 'package:deep_work/models/analytics/insight_confidence_dtos.dart';
import 'package:deep_work/models/analytics/insights_debug_info_dtos.dart';
import 'package:deep_work/models/ml/prediction_dtos.dart';

/// Data for Insights page (charts, stats). Computed from sessions.
class InsightsData {
  const InsightsData({
    required this.avgDailyFocusMinutes,
    required this.successRatePercent,
    required this.weeklyFocusMinutes,
    required this.weekdayLabels,
    required this.weeklyMaxY,
    required this.focusByType,
    required this.peakPerformanceTitle,
    required this.peakPerformanceMessage,
    this.predictionWarning,
    InsightConfidenceDto? predictionWarningConfidence,
    this.distractionTrend,
    this.recurringDistractionThemes = const [],
    this.streaks,
    this.bestWorstHoursByCategory = const [],
    this.successRateByCategory = const [],
    this.avgDurationByCategory = const [],
    this.debugInfo,
  }) : _predictionWarningConfidence = predictionWarningConfidence;

  final int avgDailyFocusMinutes;
  final int successRatePercent;
  final List<int> weeklyFocusMinutes;
  final List<String> weekdayLabels;
  final int weeklyMaxY;
  final List<FocusTypeSegment> focusByType;
  final String peakPerformanceTitle;
  final String peakPerformanceMessage;

  /// Present only when the predictor estimates a low success probability.
  final PredictionWarningDto? predictionWarning;

  /// Confidence metadata for whether prediction warnings should be shown.
  final InsightConfidenceDto? _predictionWarningConfidence;

  InsightConfidenceDto get predictionWarningConfidence =>
      _predictionWarningConfidence ??
      const InsightConfidenceDto(
        level: InsightConfidenceLevel.low,
        sampleCount: 0,
        isTrusted: false,
        reason: 'No sessions yet',
      );

  /// Distraction trend over time (reflection-derived).
  final DistractionTrendDto? distractionTrend;

  /// Top themes derived from reflection tags.
  final List<RecurringThemeDto> recurringDistractionThemes;

  /// Success streaks derived from outcomes.
  final StreaksDto? streaks;

  /// Best/worst hour-of-day recommendations derived from success rates.
  final List<CategoryHourExtremaDto> bestWorstHoursByCategory;

  /// Average success rate by category (chart-ready).
  final List<CategorySuccessRateDto> successRateByCategory;

  /// Average session duration by category (chart-ready).
  final List<CategoryDurationAverageDto> avgDurationByCategory;

  /// Dev-only details (evaluation/backtesting and prediction internals).
  final InsightsDebugInfoDto? debugInfo;

  /// Fallback when no sessions yet
  factory InsightsData.empty() {
    return InsightsData(
      avgDailyFocusMinutes: 0,
      successRatePercent: 0,
      weeklyFocusMinutes: const [0, 0, 0, 0, 0, 0, 0],
      weekdayLabels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      weeklyMaxY: 60,
      focusByType: [],
      peakPerformanceTitle: 'Peak Performance',
      peakPerformanceMessage:
          'Complete focus sessions to see insights about your productivity patterns.',
    );
  }
}

class FocusTypeSegment {
  const FocusTypeSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}
