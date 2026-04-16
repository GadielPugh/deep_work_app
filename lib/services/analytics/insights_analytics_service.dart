import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/models/insights_data.dart';
import 'package:deep_work/session_model.dart';

import '../feature_engineering/focus_feature_engineering.dart';
import '../prediction/rule_based_success_predictor.dart';
import '../prediction/predictor_evaluation_service.dart';
import '../prediction/session_success_recommendation_service.dart';
import '../prediction/session_success_predictor.dart';
import '../reflection/reflection_analyzer_service.dart';
import '../reflection/reflection_tag_extractor.dart';
import 'focus_analytics_service.dart';
import 'insight_confidence_service.dart';
import 'package:deep_work/models/analytics/insights_debug_info_dtos.dart';
import 'package:deep_work/models/analytics/predictor_evaluation_dtos.dart';

/// Produces an `InsightsData` DTO consumable by the Flutter UI.
///
/// This is where Phase 1 (feature engineering + analytics) and Phase 2/3
/// (prediction + reflection themes) get orchestrated.
class InsightsAnalyticsService {
  InsightsAnalyticsService({
    FocusFeatureEngineeringService? featureEngineeringService,
    ReflectionTagExtractor? tagExtractor,
    ReflectionAnalyzerService? reflectionAnalyzerService,
    FocusAnalyticsService? focusAnalyticsService,
    SessionSuccessPredictor? predictor,
    SessionSuccessRecommendationService? recommendationService,
  })  : _reflectionAnalyzerService = reflectionAnalyzerService ??
            ReflectionAnalyzerService(
              tagExtractor: tagExtractor ?? ReflectionTagExtractor(),
            ),
        _focusAnalyticsService = focusAnalyticsService ??
            FocusAnalyticsService(
              tagExtractor: tagExtractor ?? ReflectionTagExtractor(),
            ),
        _featureEngineeringService =
            featureEngineeringService ?? FocusFeatureEngineeringService(),
        _predictor = predictor ?? RuleBasedSessionSuccessPredictor(),
        _recommendationService = recommendationService ??
            SessionSuccessRecommendationService(
              predictor: predictor ?? RuleBasedSessionSuccessPredictor(),
              featureEngineeringService:
                  featureEngineeringService ?? FocusFeatureEngineeringService(),
            );

  final ReflectionAnalyzerService _reflectionAnalyzerService;
  final FocusAnalyticsService _focusAnalyticsService;
  final FocusFeatureEngineeringService _featureEngineeringService;
  final SessionSuccessPredictor _predictor;
  final SessionSuccessRecommendationService _recommendationService;

  InsightsData computeInsightsData({
    required List<Session> sessions,
    required List<FocusCategory> categories,
    required DateTime now,
    bool includeDebugEvaluation = false,
  }) {
    if (sessions.isEmpty) return InsightsData.empty();

    final insightConfidenceService = const InsightConfidenceService();
    final predictionWarningConfidence = insightConfidenceService
        .confidenceForPredictionWarning(totalSessionCount: sessions.length);

    // ---- Existing UI fields (preserve behavior) ----
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekSessions = sessions.where((s) => s.dateTime.isAfter(weekAgo)).toList();

    // Avg daily focus (last 7 days)
    final daysWithSessions = <DateTime>{};
    var totalMinutes = 0;
    for (final s in weekSessions) {
      final d = DateTime(s.dateTime.year, s.dateTime.month, s.dateTime.day);
      daysWithSessions.add(d);
      totalMinutes += s.durationMinutes;
    }
    final days = daysWithSessions.isEmpty ? 1 : daysWithSessions.length;
    final avgDaily = (totalMinutes / days).round();

    // Success rate
    final completed = weekSessions.where((s) => s.outcome == CompletionStatus.yes).length;
    final successRate = weekSessions.isEmpty
        ? 0
        : (completed * 100 / weekSessions.length).round();

    // Weekly focus (Mon–Sun)
    final labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final values = List<int>.filled(7, 0);
    for (final s in weekSessions) {
      var w = s.dateTime.weekday - 1; // 1=Mon
      w = w.clamp(0, 6);
      values[w] += s.durationMinutes;
    }
    final maxY = values.isEmpty ? 60 : values.reduce((a, b) => a > b ? a : b);
    final weeklyMaxY = ((maxY / 40).ceil() * 40).clamp(40, 200);

    // Focus by type (all-time)
    final byType = <String, int>{};
    for (final s in sessions) {
      byType[s.categoryId] = (byType[s.categoryId] ?? 0) + 1;
    }

    final palette = <Color>[
      CupertinoColors.activeBlue,
      CupertinoColors.systemPurple,
      CupertinoColors.systemGreen,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPink,
      CupertinoColors.systemTeal,
      CupertinoColors.systemGrey,
    ];

    final focusByType = <FocusTypeSegment>[];
    var colorIndex = 0;
    for (final e in byType.entries) {
      if (e.value <= 0) continue;

      FocusCategory? category;
      for (final c in categories) {
        if (c.id == e.key) {
          category = c;
          break;
        }
      }

      focusByType.add(
        FocusTypeSegment(
          label: category?.name ?? e.key,
          value: e.value,
          color: palette[colorIndex++ % palette.length],
        ),
      );
    }

    // Peak performance (simplified: morning vs afternoon)
    var morning = 0;
    var afternoon = 0;
    for (final s in weekSessions) {
      if (s.dateTime.hour < 12) {
        morning++;
      } else {
        afternoon++;
      }
    }
    final peakTitle = 'Peak Performance';
    final peakMessage = morning >= afternoon
        ? 'You focus best in the morning.\nConsider scheduling your most\nimportant work during this time.'
        : 'You focus best in the afternoon.\nConsider scheduling your most\nimportant work during this time.';

    // ---- New ML/analytics fields ----
    final analytics = _focusAnalyticsService.compute(
      sessions: sessions,
      now: now,
      categories: categories,
    );

    final recurringThemes = _reflectionAnalyzerService.extractRecurringDistractionThemes(
      sessions: sessions,
      distractionTags: ReflectionTagExtractor.defaultDistractionTags,
      onlyFailures: true,
      topN: 3,
    ).where((theme) {
      return insightConfidenceService.shouldShowLikelyCauseTheme(
        themeCount: theme.count,
      );
    }).toList();

    final topTheme = recurringThemes.isNotEmpty ? recurringThemes.first : null;

    final predictionWarning = _recommendationService.getLowSuccessWarningIfNeeded(
      now: now,
      sessions: sessions,
      categories: categories,
      threshold: 0.45,
      mostLikelyDistractionTheme: topTheme?.theme,
    );

    InsightsDebugInfoDto? debugInfo;
    if (includeDebugEvaluation) {
      final evaluationService = PredictorEvaluationService(
        featureEngineeringService: _featureEngineeringService,
        successPredictor: _predictor,
      );

      final evaluationSummary = evaluationService.evaluate(
        sessions: sessions,
        categories: categories,
      );

      final bestRecommendation = _recommendationService
          .recommendBestCategoryForCurrentHour(
        now: now,
        sessions: sessions,
        categories: categories,
      );

      final predictionReasons = <String>[
        ...bestRecommendation.riskFactors,
        if (topTheme != null && topTheme.theme.isNotEmpty)
          'recent failed sessions sometimes mention=${topTheme.theme}',
      ];

      debugInfo = InsightsDebugInfoDto(
        totalSessionCount: sessions.length,
        predictionConfidence: predictionWarningConfidence,
        predictedSuccessProbability: bestRecommendation.successProbability,
        predictionReasons: predictionReasons,
        evaluationSummary: evaluationSummary,
        ruleBeatsBaselines: _ruleBeatsBaselines(evaluationSummary),
      );
    }

    return InsightsData(
      avgDailyFocusMinutes: avgDaily,
      successRatePercent: successRate,
      weeklyFocusMinutes: values,
      weekdayLabels: labels,
      weeklyMaxY: weeklyMaxY,
      focusByType: focusByType.isEmpty
          ? [
              FocusTypeSegment(
                label: 'No data',
                value: 0,
                color: CupertinoColors.systemGrey,
              )
            ]
          : focusByType,
      peakPerformanceTitle: peakTitle,
      peakPerformanceMessage: peakMessage,
      predictionWarning: predictionWarning,
      predictionWarningConfidence: predictionWarningConfidence,
      distractionTrend: analytics.distractionTrend,
      recurringDistractionThemes: recurringThemes,
      streaks: analytics.streaks,
      bestWorstHoursByCategory: analytics.bestWorstHoursByCategory,
      successRateByCategory: analytics.successRateByCategory,
      avgDurationByCategory: analytics.avgDurationByCategory,
      debugInfo: debugInfo,
    );
  }

  bool _ruleBeatsBaselines(PredictorEvaluationSummaryDto evaluationSummary) {
    // Prefer lower Brier score (probabilistic correctness).
    final ruleBrier = evaluationSummary.ruleBased.overall.brierScore;
    final baselineRollBrier =
        evaluationSummary.baselineRollingCategoryOnly.overall.brierScore;
    final baselineGlobalBrier =
        evaluationSummary.baselineGlobalOnly.overall.brierScore;
    return ruleBrier <= baselineRollBrier && ruleBrier <= baselineGlobalBrier;
  }
}

