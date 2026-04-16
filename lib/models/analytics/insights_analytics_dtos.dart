import 'package:deep_work/models/ml/chart_series_dtos.dart';
import 'package:deep_work/models/analytics/insight_confidence_dtos.dart';

class CategoryHourExtremaDto {
  const CategoryHourExtremaDto({
    required this.categoryId,
    required this.bestHour,
    required this.bestSuccessRatePercent,
    required this.bestHourSampleCount,
    required this.worstHour,
    required this.worstSuccessRatePercent,
    required this.worstHourSampleCount,
    required this.sampleCount,
    this.isConsistent = true,
    InsightConfidenceDto? confidence,
  }) : _confidence = confidence;

  final String categoryId;
  final int bestHour;
  final double bestSuccessRatePercent;
  final int bestHourSampleCount;
  final int worstHour;
  final double worstSuccessRatePercent;
  final int worstHourSampleCount;
  final int sampleCount;
  final bool isConsistent;
  final InsightConfidenceDto? _confidence;

  InsightConfidenceDto get confidence =>
      _confidence ??
      const InsightConfidenceDto(
        level: InsightConfidenceLevel.low,
        sampleCount: 0,
        isTrusted: false,
        reason: 'Not enough data yet.',
      );
}

class CategorySuccessRateDto {
  const CategorySuccessRateDto({
    required this.categoryId,
    required this.successRatePercent,
    required this.count,
  });

  final String categoryId;
  final double successRatePercent;
  final int count;
}

class CategoryDurationAverageDto {
  const CategoryDurationAverageDto({
    required this.categoryId,
    required this.avgDurationMinutes,
    required this.count,
  });

  final String categoryId;
  final double avgDurationMinutes;
  final int count;
}

class StreaksDto {
  const StreaksDto({
    required this.currentSuccessStreak,
    required this.maxSuccessStreak,
    required this.currentCategorySuccessStreaks,
  });

  final int currentSuccessStreak;
  final int maxSuccessStreak;
  final Map<String, int> currentCategorySuccessStreaks;
}

/// Most common "distraction" themes extracted from reflection text.
class RecurringThemeDto {
  const RecurringThemeDto({
    required this.theme,
    required this.count,
  });

  final String theme;
  final int count;
}

class ReflectionClusterDto {
  const ReflectionClusterDto({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class FailureReasonSummaryDto {
  const FailureReasonSummaryDto({
    required this.title,
    required this.keyReasons,
  });

  final String title;
  final List<String> keyReasons;
}

/// A chart-ready representation of distraction over time.
class DistractionTrendDto {
  const DistractionTrendDto({required this.series});
  final ChartSeriesDouble series;
}

