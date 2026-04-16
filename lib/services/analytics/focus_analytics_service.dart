import 'package:deep_work/models/analytics/insights_analytics_dtos.dart';
import 'package:deep_work/models/analytics/insight_confidence_dtos.dart';
import 'package:deep_work/models/ml/chart_series_dtos.dart';
import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/session_model.dart';

import 'insight_confidence_service.dart';

import '../reflection/reflection_tag_extractor.dart';

class FocusAnalyticsResults {
  const FocusAnalyticsResults({
    required this.bestWorstHoursByCategory,
    required this.successRateByCategory,
    required this.avgDurationByCategory,
    required this.distractionTrend,
    required this.streaks,
  });

  final List<CategoryHourExtremaDto> bestWorstHoursByCategory;
  final List<CategorySuccessRateDto> successRateByCategory;
  final List<CategoryDurationAverageDto> avgDurationByCategory;
  final DistractionTrendDto distractionTrend;
  final StreaksDto streaks;
}

/// Computes reusable analytics derived from `Session` history.
///
/// This is Phase 1 and intentionally lightweight (no heavy dependencies).
class FocusAnalyticsService {
  FocusAnalyticsService({
    required this.tagExtractor,
  }) : _confidenceService = const InsightConfidenceService();

  final ReflectionTagExtractor tagExtractor;
  final InsightConfidenceService _confidenceService;

  FocusAnalyticsResults compute({
    required List<Session> sessions,
    required DateTime now,
    required List<FocusCategory> categories,
    int lookbackDays = 90,
    int trendDays = 14,
    int minSamplesPerHourBucket = 2,
  }) {
    if (sessions.isEmpty) {
      return FocusAnalyticsResults(
        bestWorstHoursByCategory: const [],
        successRateByCategory: const [],
        avgDurationByCategory: const [],
        distractionTrend: DistractionTrendDto(
          series: ChartSeriesDouble.empty(),
        ),
        streaks: const StreaksDto(
          currentSuccessStreak: 0,
          maxSuccessStreak: 0,
          currentCategorySuccessStreaks: {},
        ),
      );
    }

    final localNow = now.toLocal();
    final lookbackStart = localNow.subtract(Duration(days: lookbackDays));

    final sessionsInWindow = sessions.where((s) {
      final local = s.dateTime.toLocal();
      return local.isAfter(lookbackStart) && local.isBefore(localNow);
    }).toList();

    // Success & duration by category.
    final sessionsByCategory = <String, List<Session>>{};
    for (final s in sessionsInWindow) {
      (sessionsByCategory[s.categoryId] ??= []).add(s);
    }

    final successRateByCategory = <CategorySuccessRateDto>[];
    final avgDurationByCategory = <CategoryDurationAverageDto>[];

    for (final c in categories) {
      final list = sessionsByCategory[c.id];
      if (list == null || list.isEmpty) continue;

      final count = list.length;
      final successCount = list.where((s) => s.outcome == CompletionStatus.yes).length;
      final successRate = successCount / count;
      final avgDuration = list.map((s) => s.durationMinutes).reduce((a, b) => a + b) / count;

      successRateByCategory.add(
        CategorySuccessRateDto(
          categoryId: c.id,
          successRatePercent: successRate * 100,
          count: count,
        ),
      );
      avgDurationByCategory.add(
        CategoryDurationAverageDto(
          categoryId: c.id,
          avgDurationMinutes: avgDuration,
          count: count,
        ),
      );
    }

    // Best/Worst hours by category.
    final bestWorstHoursByCategory = <CategoryHourExtremaDto>[];
    for (final c in categories) {
      final list = sessionsByCategory[c.id];
      if (list == null || list.length < minSamplesPerHourBucket) continue;

      final byHour = <int, List<Session>>{};
      for (final s in list) {
        final hour = s.dateTime.toLocal().hour;
        (byHour[hour] ??= []).add(s);
      }

      final hourStats = byHour.entries
          .map((e) {
            final hour = e.key;
            final bucket = e.value;
            final total = bucket.length;
            final successCount = bucket.where((s) => s.outcome == CompletionStatus.yes).length;
            final successRate = total == 0 ? 0.0 : successCount / total;
            return MapEntry(hour, (successRate: successRate, count: total));
          })
          .toList();

      final eligible = hourStats.where((e) => e.value.count >= minSamplesPerHourBucket).toList();
      final candidates = eligible.isEmpty ? hourStats : eligible;

      if (candidates.isEmpty) continue;

      candidates.sort((a, b) {
        final cmp = a.value.successRate.compareTo(b.value.successRate);
        if (cmp != 0) return cmp;
        return b.value.count.compareTo(a.value.count);
      });

      final worst = candidates.first;
      final best = candidates.last;
      final isConsistent = _confidenceService.hasMeaningfulHourSeparation(
        bestSuccessRatePercent: best.value.successRate * 100,
        worstSuccessRatePercent: worst.value.successRate * 100,
        bestHourSampleCount: best.value.count,
        worstHourSampleCount: worst.value.count,
      );
      final confidence = _confidenceService.confidenceForBestWorstHours(
        categorySampleCount: list.length,
      );

      bestWorstHoursByCategory.add(
        CategoryHourExtremaDto(
          categoryId: c.id,
          bestHour: best.key,
          bestSuccessRatePercent: best.value.successRate * 100,
          bestHourSampleCount: best.value.count,
          worstHour: worst.key,
          worstSuccessRatePercent: worst.value.successRate * 100,
          worstHourSampleCount: worst.value.count,
          sampleCount: list.length,
          isConsistent: isConsistent,
          confidence: isConsistent
              ? confidence
              : InsightConfidenceDto(
                  level: InsightConfidenceLevel.low,
                  sampleCount: list.length,
                  isTrusted: false,
                  reason: 'Not enough consistent data yet.',
                ),
        ),
      );
    }

    // Distraction trend.
    final labels = <String>[];
    final values = <double>[];

    final distractionTags = ReflectionTagExtractor.defaultDistractionTags;
    final nowDay = DateTime(localNow.year, localNow.month, localNow.day);

    for (var i = trendDays - 1; i >= 0; i--) {
      final day = nowDay.subtract(Duration(days: i));
      labels.add('${day.month}/${day.day}');

      final daySessions = sessions.where((s) {
        final local = s.dateTime.toLocal();
        return local.year == day.year && local.month == day.month && local.day == day.day;
      }).toList();

      if (daySessions.isEmpty) {
        values.add(0.0);
        continue;
      }

      var distractionCount = 0;
      for (final s in daySessions) {
        final reflection = s.reflection;
        if (reflection == null || reflection.trim().isEmpty) continue;
        final tags = tagExtractor.extractTags(reflection);
        if (tags.any((t) => distractionTags.contains(t))) {
          distractionCount++;
        }
      }

      final rate = distractionCount / daySessions.length;
      values.add(rate);
    }

    final maxY = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);

    final distractionTrend = DistractionTrendDto(
      series: ChartSeriesDouble(
        labels: labels,
        values: values,
        maxY: maxY,
      ),
    );

    // Streaks.
    final sortedAsc = [...sessions]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    var current = 0;
    var max = 0;
    for (final s in sortedAsc) {
      if (s.outcome == CompletionStatus.yes) {
        current++;
        if (current > max) max = current;
      } else {
        current = 0;
      }
    }

    final sortedDesc = [...sessions]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    var currentSuccessStreak = 0;
    for (final s in sortedDesc) {
      if (s.outcome == CompletionStatus.yes) {
        currentSuccessStreak++;
      } else {
        break;
      }
    }

    final byCategory = <String, List<Session>>{};
    for (final s in sessions) {
      (byCategory[s.categoryId] ??= []).add(s);
    }

    final currentCategorySuccessStreaks = <String, int>{};
    for (final entry in byCategory.entries) {
      final catSessions = [...entry.value]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      var catStreak = 0;
      for (final s in catSessions) {
        if (s.outcome == CompletionStatus.yes) {
          catStreak++;
        } else {
          break;
        }
      }
      currentCategorySuccessStreaks[entry.key] = catStreak;
    }

    return FocusAnalyticsResults(
      bestWorstHoursByCategory: bestWorstHoursByCategory,
      successRateByCategory: successRateByCategory,
      avgDurationByCategory: avgDurationByCategory,
      distractionTrend: distractionTrend,
      streaks: StreaksDto(
        currentSuccessStreak: currentSuccessStreak,
        maxSuccessStreak: max,
        currentCategorySuccessStreaks: currentCategorySuccessStreaks,
      ),
    );
  }
}

