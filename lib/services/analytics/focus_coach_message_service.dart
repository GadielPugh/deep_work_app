import 'dart:math' as math;

import 'package:deep_work/models/analytics/insight_confidence_dtos.dart';
import 'package:deep_work/models/analytics/insights_analytics_dtos.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/models/insights_data.dart';
import 'package:deep_work/models/ml/prediction_dtos.dart';

class FocusCoachMessageService {
  const FocusCoachMessageService();

  FocusCoachMessage buildMessage({
    required InsightsData data,
    List<FocusCategory> categories = const [],
    DateTime? now,
  }) {
    final currentTime = (now ?? DateTime.now()).toLocal();
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };

    return _buildCurrentRecommendationMessage(
          data: data,
          categoryNames: categoryNames,
          nowHour: currentTime.hour,
        ) ??
        _buildPositivePatternMessage(
          data: data,
          categoryNames: categoryNames,
        ) ??
        _buildRecurringDistractionMessage(data) ??
        _buildStreakMessage(data: data, categoryNames: categoryNames) ??
        _buildFallbackMessage(data);
  }

  FocusCoachMessage? _buildCurrentRecommendationMessage({
    required InsightsData data,
    required Map<String, String> categoryNames,
    required int nowHour,
  }) {
    final recommendation = data.currentRecommendation;
    if (recommendation == null) return null;

    final categoryName = recommendation.categoryName.isNotEmpty
        ? recommendation.categoryName
        : _categoryName(categoryNames, recommendation.categoryId);
    final historicalPattern = _bestTimePatternForCategory(
      data,
      recommendation.categoryId,
    );
    final categorySuccess = _successRateForCategory(
      data,
      recommendation.categoryId,
    );
    final reflectionHint = _reflectionHint(data.recurringDistractionThemes);
    final betterLaterHint = _betterLaterHint(
      categoryName: categoryName,
      recommendation: recommendation,
      historicalPattern: historicalPattern,
      nowHour: nowHour,
    );
    final durationText =
        'Try ${recommendation.recommendedDurationMinutes} min of $categoryName';

    if (recommendation.isCautiousFallback && recommendation.sampleCount == 0) {
      return FocusCoachMessage(
        title: 'Start small with $categoryName.',
        body:
            'A short session is the safest first step while your pattern is forming.',
        actionText: durationText,
        confidenceLabel: 'Keep it simple',
        reasonLine: reflectionHint,
        recommendedCategory: categoryName,
        recommendedDurationMinutes: recommendation.recommendedDurationMinutes,
        type: FocusCoachMessageType.suggestion,
      );
    }

    if (data.predictionWarning != null) {
      return FocusCoachMessage(
        title: 'Right now, $categoryName looks like your best option.',
        body: betterLaterHint != null
            ? 'This may not be your strongest time, so keep it short.'
            : recommendation.isCautiousFallback
            ? 'Keep it short and simple.'
            : 'Keep it short and simple.',
        actionText: durationText,
        confidenceLabel: 'Keep it simple',
        reasonLine: betterLaterHint ?? reflectionHint,
        recommendedCategory: categoryName,
        recommendedDurationMinutes: recommendation.recommendedDurationMinutes,
        betterLaterHint: betterLaterHint,
        type: FocusCoachMessageType.warning,
      );
    }

    final isPositiveNow = _isPositiveNowRecommendation(
      recommendation: recommendation,
      historicalPattern: historicalPattern,
      categorySuccess: categorySuccess,
      nowHour: nowHour,
    );
    if (!isPositiveNow) return null;

    final hasConsistencyBoost =
        categorySuccess != null &&
        categorySuccess.count >= 5 &&
        categorySuccess.successRatePercent >= 70;
    final hasHelpfulNowPattern =
        historicalPattern != null &&
        _isHistoricalPatternHelpfulNow(
          historicalPattern: historicalPattern,
          nowHour: nowHour,
        );

    return FocusCoachMessage(
      title: 'This looks like a good time for $categoryName.',
      body: hasConsistencyBoost
          ? 'You\'ve been more consistent with $categoryName lately.'
          : hasHelpfulNowPattern
          ? '$categoryName usually feels better ${describeTimeBlock(nowHour)}.'
          : 'A short session could work well right now.',
      actionText: durationText,
      confidenceLabel: 'Try now',
      reasonLine: reflectionHint,
      recommendedCategory: categoryName,
      recommendedDurationMinutes: recommendation.recommendedDurationMinutes,
      type: FocusCoachMessageType.positive,
    );
  }

  FocusCoachMessage? _buildPositivePatternMessage({
    required InsightsData data,
    required Map<String, String> categoryNames,
  }) {
    final timePattern = _bestTimePattern(data);
    if (timePattern != null) {
      final categoryName = _categoryName(categoryNames, timePattern.categoryId);
      final timeBlock = timeBlockForHour(timePattern.bestHour);
      final isEarlyPattern =
          timePattern.confidence.level == InsightConfidenceLevel.medium;

      return FocusCoachMessage(
        title:
            '$categoryName is usually stronger ${describeTimeBlock(timePattern.bestHour)}.',
        body:
            'That is often a better window for your harder $categoryName work.',
        actionText: 'Try $categoryName in the $timeBlock',
        confidenceLabel: 'A good next step',
        reasonLine: isEarlyPattern
            ? 'This looks helpful, but the pattern is still new.'
            : 'This pattern shows up across several sessions.',
        recommendedCategory: categoryName,
        type: FocusCoachMessageType.positive,
      );
    }

    final steadyCategory = _topSteadyCategory(data);
    if (steadyCategory == null) return null;

    final categoryName = _categoryName(
      categoryNames,
      steadyCategory.categoryId,
    );
    final isStrongerPattern = steadyCategory.count >= 8;
    final suggestedDurationMinutes = _suggestedDurationMinutesForCategory(
      data: data,
      categoryId: steadyCategory.categoryId,
    );
    final suggestedDuration =
        'Try $suggestedDurationMinutes min of $categoryName';

    return FocusCoachMessage(
      title: 'You\'ve been more consistent with $categoryName lately.',
      body: 'It can be a good place to start when you want something simple.',
      actionText: suggestedDuration,
      confidenceLabel: 'Best next step',
      reasonLine: isStrongerPattern
          ? 'It stands out across several sessions.'
          : 'This looks promising, but it is still early.',
      recommendedCategory: categoryName,
      recommendedDurationMinutes: suggestedDurationMinutes,
      type: FocusCoachMessageType.positive,
    );
  }

  FocusCoachMessage? _buildRecurringDistractionMessage(InsightsData data) {
    if (data.recurringDistractionThemes.isEmpty) return null;

    final theme = data.recurringDistractionThemes.first;
    if (!_isReliableReflectionTheme(theme)) return null;
    final themeLabel = _normalizeTheme(theme.theme);

    return FocusCoachMessage(
      title: 'One distraction keeps coming up',
      body:
          'Recent reflections sometimes mention $themeLabel. Clear a little space before you start.',
      actionText: _themeActionText(themeLabel),
      confidenceLabel: 'Best next step',
      reasonLine: 'This has come up more than once.',
      type: FocusCoachMessageType.suggestion,
    );
  }

  FocusCoachMessage? _buildStreakMessage({
    required InsightsData data,
    required Map<String, String> categoryNames,
  }) {
    final streaks = data.streaks;
    if (streaks == null || streaks.currentSuccessStreak < 2) return null;

    final topCategoryEntries =
        streaks.currentCategorySuccessStreaks.entries
            .where((entry) => entry.value >= 2)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final topCategory = topCategoryEntries.isNotEmpty
        ? topCategoryEntries.first
        : null;
    final categoryName = topCategory == null
        ? null
        : _categoryName(categoryNames, topCategory.key);
    final streakCount = streaks.currentSuccessStreak;
    final isStrongStreak = streakCount >= 4;
    final suggestedDurationMinutes = topCategory == null
        ? null
        : _suggestedDurationMinutesForCategory(
            data: data,
            categoryId: topCategory.key,
          );

    return FocusCoachMessage(
      title: isStrongStreak
          ? 'You are building real momentum'
          : 'You are on a good streak',
      body: categoryName == null
          ? 'You have finished ${formatSessionCount(streakCount)} in a row. Keep the next one simple.'
          : 'You have finished ${formatSessionCount(streakCount)} in a row, and $categoryName is helping you stay steady.',
      actionText: categoryName == null
          ? 'Keep the next one short'
          : 'Try $suggestedDurationMinutes min of $categoryName',
      confidenceLabel: 'A good next step',
      reasonLine: streaks.maxSuccessStreak > streakCount
          ? 'Your best streak so far is ${streaks.maxSuccessStreak}.'
          : 'Your recent sessions are holding steady.',
      recommendedCategory: categoryName,
      recommendedDurationMinutes: suggestedDurationMinutes,
      type: FocusCoachMessageType.positive,
    );
  }

  FocusCoachMessage _buildFallbackMessage(InsightsData data) {
    final sessionCount = data.predictionWarningConfidence.sampleCount;
    if (sessionCount < 6) {
      return const FocusCoachMessage(
        title: 'I need a little more data',
        body:
            'I need a little more data before I can give a strong suggestion. Try adding a few more sessions and reflections.',
        actionText: 'Add a few more sessions',
        confidenceLabel: 'Best next step',
        type: FocusCoachMessageType.notEnoughData,
      );
    }

    return const FocusCoachMessage(
      title: 'Your pattern is still forming',
      body:
          'I do not see one clear pattern yet. Keep sessions short and add brief reflections.',
      actionText: 'Keep tracking sessions',
      confidenceLabel: 'Keep it simple',
      reasonLine: 'Nothing strong stands out yet.',
      type: FocusCoachMessageType.neutral,
    );
  }

  CategoryHourExtremaDto? _bestTimePattern(InsightsData data) {
    final trustedPatterns = _trustedTimePatterns(
      data.bestWorstHoursByCategory,
    ).where(_isReliableTimePattern).toList();
    return trustedPatterns.isEmpty ? null : trustedPatterns.first;
  }

  CategoryHourExtremaDto? _bestTimePatternForCategory(
    InsightsData data,
    String categoryId,
  ) {
    final trustedPatterns = _trustedTimePatterns(
      data.bestWorstHoursByCategory,
    ).where((pattern) => pattern.categoryId == categoryId).toList();

    return trustedPatterns.isEmpty ? null : trustedPatterns.first;
  }

  CategorySuccessRateDto? _topSteadyCategory(InsightsData data) {
    final candidates =
        data.successRateByCategory
            .where(
              (category) =>
                  category.count >= 6 && category.successRatePercent >= 75,
            )
            .toList()
          ..sort((a, b) {
            final rateOrder = b.successRatePercent.compareTo(
              a.successRatePercent,
            );
            if (rateOrder != 0) return rateOrder;
            return b.count.compareTo(a.count);
          });

    return candidates.isEmpty ? null : candidates.first;
  }

  CategorySuccessRateDto? _successRateForCategory(
    InsightsData data,
    String categoryId,
  ) {
    for (final entry in data.successRateByCategory) {
      if (entry.categoryId == categoryId) {
        return entry;
      }
    }
    return null;
  }

  String _categoryName(Map<String, String> categoryNames, String categoryId) {
    return categoryNames[categoryId] ?? categoryId;
  }

  int _confidenceSortValue(InsightConfidenceLevel level) {
    return switch (level) {
      InsightConfidenceLevel.high => 3,
      InsightConfidenceLevel.medium => 2,
      InsightConfidenceLevel.low => 1,
    };
  }

  String timeBlockForHour(int hour) {
    final normalizedHour = _normalizeHour(hour);
    if (normalizedHour >= 5 && normalizedHour <= 11) return 'morning';
    if (normalizedHour >= 12 && normalizedHour <= 16) return 'afternoon';
    if (normalizedHour >= 17 && normalizedHour <= 21) return 'evening';
    return 'night';
  }

  bool isHourNearNow(int targetHour, int nowHour, {int threshold = 2}) {
    final normalizedTargetHour = _normalizeHour(targetHour);
    final normalizedNowHour = _normalizeHour(nowHour);
    final absoluteDifference = (normalizedTargetHour - normalizedNowHour).abs();
    final wrappedDifference = 24 - absoluteDifference;
    return math.min(absoluteDifference, wrappedDifference) <= threshold;
  }

  String describeTimeBlock(int hour) {
    return switch (timeBlockForHour(hour)) {
      'morning' => 'in the morning',
      'afternoon' => 'in the afternoon',
      'evening' => 'in the evening',
      _ => 'at night',
    };
  }

  String _normalizeTheme(String theme) {
    final normalized = theme.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (normalized.isEmpty) {
      return 'A distraction';
    }

    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String _themeActionText(String themeLabel) {
    final lowerTheme = themeLabel.toLowerCase();
    if (lowerTheme == 'phone') {
      return 'Put your phone away first';
    }
    if (lowerTheme.length <= 24 && !lowerTheme.contains(',')) {
      return 'Clear $lowerTheme before you start';
    }
    return 'Clear one likely distraction';
  }

  String? _reflectionHint(List<RecurringThemeDto> themes) {
    if (themes.isEmpty) return null;

    final topTheme = themes.first;
    if (!_isReliableReflectionTheme(topTheme)) return null;

    final normalizedTheme = _normalizeTheme(topTheme.theme).toLowerCase();
    return 'Recent reflections sometimes mention $normalizedTheme.';
  }

  String formatSessionCount(int count) {
    final sessionWord = count == 1 ? 'session' : 'sessions';
    return '$count $sessionWord';
  }

  int _suggestedDurationMinutesForCategory({
    required InsightsData data,
    required String categoryId,
  }) {
    final currentRecommendation = data.currentRecommendation;
    if (currentRecommendation != null &&
        currentRecommendation.categoryId == categoryId) {
      return currentRecommendation.recommendedDurationMinutes;
    }

    for (final entry in data.avgDurationByCategory) {
      if (entry.categoryId == categoryId && entry.count >= 3) {
        return _practicalDurationBucket(entry.avgDurationMinutes);
      }
    }
    return 25;
  }

  int _practicalDurationBucket(double durationMinutes) {
    if (durationMinutes <= 15) return 10;
    if (durationMinutes <= 22) return 20;
    if (durationMinutes <= 27) return 25;
    return 30;
  }

  List<CategoryHourExtremaDto> _trustedTimePatterns(
    List<CategoryHourExtremaDto> patterns,
  ) {
    return patterns
        .where(
          (pattern) => pattern.confidence.isTrusted && pattern.isConsistent,
        )
        .toList()
      ..sort((a, b) {
        final confidenceOrder = _confidenceSortValue(
          b.confidence.level,
        ).compareTo(_confidenceSortValue(a.confidence.level));
        if (confidenceOrder != 0) return confidenceOrder;

        final sampleOrder = b.sampleCount.compareTo(a.sampleCount);
        if (sampleOrder != 0) return sampleOrder;

        return b.bestSuccessRatePercent.compareTo(a.bestSuccessRatePercent);
      });
  }

  bool _isPositiveNowRecommendation({
    required CurrentFocusRecommendationDto recommendation,
    required CategoryHourExtremaDto? historicalPattern,
    required CategorySuccessRateDto? categorySuccess,
    required int nowHour,
  }) {
    if (recommendation.isCautiousFallback) return false;
    if (recommendation.sampleCount < 6) return false;
    if (recommendation.successProbability >= 0.66) return true;
    if (historicalPattern != null &&
        _isReliableTimePattern(historicalPattern) &&
        _isHistoricalPatternHelpfulNow(
          historicalPattern: historicalPattern,
          nowHour: nowHour,
        ) &&
        recommendation.successProbability >= 0.58) {
      return true;
    }
    if (categorySuccess != null &&
        categorySuccess.count >= 6 &&
        categorySuccess.successRatePercent >= 78 &&
        recommendation.successProbability >= 0.56) {
      return true;
    }
    return false;
  }

  bool _isHistoricalPatternHelpfulNow({
    required CategoryHourExtremaDto historicalPattern,
    required int nowHour,
  }) {
    return isHourNearNow(historicalPattern.bestHour, nowHour) ||
        timeBlockForHour(historicalPattern.bestHour) ==
            timeBlockForHour(nowHour);
  }

  String? _betterLaterHint({
    required String categoryName,
    required CurrentFocusRecommendationDto recommendation,
    required CategoryHourExtremaDto? historicalPattern,
    required int nowHour,
  }) {
    if (historicalPattern == null) return null;
    if (!_isStrongBetterLaterPattern(historicalPattern)) return null;
    if (recommendation.successProbability > 0.5) return null;

    final nowTimeBlock = timeBlockForHour(nowHour);
    final historicalTimeBlock = timeBlockForHour(historicalPattern.bestHour);

    if (_isHistoricalPatternHelpfulNow(
      historicalPattern: historicalPattern,
      nowHour: nowHour,
    )) {
      return null;
    }
    if (nowTimeBlock == historicalTimeBlock) return null;

    if (nowTimeBlock == 'night' && historicalTimeBlock == 'morning') {
      return 'You may do better with this tomorrow morning.';
    }

    return '$categoryName usually works better ${describeTimeBlock(historicalPattern.bestHour)}.';
  }

  bool _isReliableReflectionTheme(RecurringThemeDto theme) {
    return theme.count >= 3;
  }

  bool _isReliableTimePattern(CategoryHourExtremaDto pattern) {
    if (!pattern.confidence.isTrusted || !pattern.isConsistent) return false;
    if (pattern.sampleCount < 8) return false;
    if (pattern.bestHourSampleCount < 3 || pattern.worstHourSampleCount < 2) {
      return false;
    }
    return true;
  }

  bool _isStrongBetterLaterPattern(CategoryHourExtremaDto pattern) {
    if (!_isReliableTimePattern(pattern)) return false;
    final gap =
        (pattern.bestSuccessRatePercent - pattern.worstSuccessRatePercent)
            .abs();
    if (gap < 20) return false;
    if (pattern.sampleCount < 10) return false;
    return pattern.confidence.level != InsightConfidenceLevel.low;
  }

  int _normalizeHour(int hour) {
    return ((hour % 24) + 24) % 24;
  }
}
