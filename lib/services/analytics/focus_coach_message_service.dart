import 'package:deep_work/models/analytics/insight_confidence_dtos.dart';
import 'package:deep_work/models/analytics/insights_analytics_dtos.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/models/insights_data.dart';

class FocusCoachMessageService {
  const FocusCoachMessageService();

  FocusCoachMessage buildMessage({
    required InsightsData data,
    List<FocusCategory> categories = const [],
  }) {
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };

    return _buildLowSuccessRiskMessage(
          data: data,
          categoryNames: categoryNames,
        ) ??
        _buildPositivePatternMessage(
          data: data,
          categoryNames: categoryNames,
        ) ??
        _buildRecurringDistractionMessage(data) ??
        _buildStreakMessage(data: data, categoryNames: categoryNames) ??
        _buildFallbackMessage(data);
  }

  FocusCoachMessage? _buildLowSuccessRiskMessage({
    required InsightsData data,
    required Map<String, String> categoryNames,
  }) {
    final warning = data.predictionWarning;
    if (warning == null) return null;

    final categoryName = warning.recommendedCategoryName.isNotEmpty
        ? warning.recommendedCategoryName
        : _categoryName(categoryNames, warning.recommendedCategoryId);
    final topTheme = data.recurringDistractionThemes.isNotEmpty
        ? data.recurringDistractionThemes.first
        : null;

    return FocusCoachMessage(
      title: 'Your next session may need a simpler plan',
      body: warning.isCautiousFallback
          ? 'Recent sessions look harder to finish. Start with a short $categoryName block and keep the goal simple.'
          : 'Recent sessions like this may be harder to finish. A shorter $categoryName block may work better right now.',
      actionText:
          'Try ${warning.recommendedDurationMinutes} min of $categoryName',
      confidenceLabel: _confidenceLabelForLevel(warning.confidence.level),
      reasonLine: topTheme != null
          ? '"${_normalizeTheme(topTheme.theme)}" came up more than once in harder sessions.'
          : 'This comes from your recent session pattern.',
      type: FocusCoachMessageType.warning,
    );
  }

  FocusCoachMessage? _buildPositivePatternMessage({
    required InsightsData data,
    required Map<String, String> categoryNames,
  }) {
    final timePattern = _bestTimePattern(data);
    if (timePattern != null) {
      final categoryName = _categoryName(categoryNames, timePattern.categoryId);
      final bestTime = _hourLabel(timePattern.bestHour);
      final isEarlyPattern =
          timePattern.confidence.level == InsightConfidenceLevel.medium;

      return FocusCoachMessage(
        title: 'You have a strong focus window',
        body:
            'Your $categoryName sessions tend to go better around $bestTime. Put your hardest $categoryName work there if you can.',
        actionText: 'Plan $categoryName near $bestTime',
        confidenceLabel: _confidenceLabelForLevel(timePattern.confidence.level),
        reasonLine: isEarlyPattern
            ? 'This looks helpful, but the pattern is still new.'
            : 'This pattern shows up across several sessions.',
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

    return FocusCoachMessage(
      title: '$categoryName is working well for you',
      body:
          '$categoryName has been one of your steadier focus types lately. Use it when you want an easier start.',
      actionText: 'Start with $categoryName',
      confidenceLabel: isStrongerPattern ? 'Good signal' : 'Early signal',
      reasonLine: isStrongerPattern
          ? 'It stands out across several sessions.'
          : 'This looks promising, but it is still early.',
      type: FocusCoachMessageType.positive,
    );
  }

  FocusCoachMessage? _buildRecurringDistractionMessage(InsightsData data) {
    if (data.recurringDistractionThemes.isEmpty) return null;

    final theme = data.recurringDistractionThemes.first;
    final themeLabel = _normalizeTheme(theme.theme);
    final isStrongPattern = theme.count >= 3;

    return FocusCoachMessage(
      title: isStrongPattern
          ? 'One distraction keeps coming up'
          : 'One distraction may be getting in the way',
      body: isStrongPattern
          ? '$themeLabel keeps showing up in harder sessions. Make it a little harder to reach before you start.'
          : '$themeLabel showed up more than once in harder sessions. It may help to set it aside before you begin.',
      actionText: _themeActionText(themeLabel),
      confidenceLabel: isStrongPattern ? 'Good signal' : 'Early signal',
      reasonLine: isStrongPattern
          ? 'This came up in a few reflections.'
          : 'This is still an early pattern.',
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

    return FocusCoachMessage(
      title: isStrongStreak
          ? 'You are building real momentum'
          : 'You are on a good streak',
      body: categoryName == null
          ? 'You have finished $streakCount sessions in a row. Keep the next session clear and simple.'
          : 'You have finished $streakCount sessions in a row, and $categoryName is helping you stay steady. Keep the next session clear and simple.',
      actionText: categoryName == null
          ? 'Protect your next session'
          : 'Keep going with $categoryName',
      confidenceLabel: isStrongStreak ? 'Good signal' : 'Recent pattern',
      reasonLine: streaks.maxSuccessStreak > streakCount
          ? 'Your best streak so far is ${streaks.maxSuccessStreak}.'
          : 'Your recent sessions are holding steady.',
      type: FocusCoachMessageType.positive,
    );
  }

  FocusCoachMessage _buildFallbackMessage(InsightsData data) {
    final sessionCount = data.predictionWarningConfidence.sampleCount;
    if (sessionCount < 5) {
      return const FocusCoachMessage(
        title: 'I need a little more data',
        body:
            'I need a little more data before I can give a strong suggestion. Try adding a few more sessions and reflections.',
        actionText: 'Add a few more sessions',
        confidenceLabel: 'Not enough data',
        type: FocusCoachMessageType.notEnoughData,
      );
    }

    return const FocusCoachMessage(
      title: 'Your pattern is still forming',
      body:
          'I do not see one strong pattern yet. Keep sessions simple and add short reflections so I can learn what helps you most.',
      actionText: 'Keep tracking sessions',
      confidenceLabel: 'Mixed signal',
      reasonLine: 'Nothing strong stands out yet.',
      type: FocusCoachMessageType.neutral,
    );
  }

  CategoryHourExtremaDto? _bestTimePattern(InsightsData data) {
    final trustedPatterns =
        data.bestWorstHoursByCategory
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

    return trustedPatterns.isEmpty ? null : trustedPatterns.first;
  }

  CategorySuccessRateDto? _topSteadyCategory(InsightsData data) {
    final candidates =
        data.successRateByCategory
            .where(
              (category) =>
                  category.count >= 5 && category.successRatePercent >= 70,
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

  String _categoryName(Map<String, String> categoryNames, String categoryId) {
    return categoryNames[categoryId] ?? categoryId;
  }

  String _confidenceLabelForLevel(InsightConfidenceLevel level) {
    return switch (level) {
      InsightConfidenceLevel.high => 'Strong signal',
      InsightConfidenceLevel.medium => 'Good signal',
      InsightConfidenceLevel.low => 'Early signal',
    };
  }

  int _confidenceSortValue(InsightConfidenceLevel level) {
    return switch (level) {
      InsightConfidenceLevel.high => 3,
      InsightConfidenceLevel.medium => 2,
      InsightConfidenceLevel.low => 1,
    };
  }

  String _hourLabel(int hour) {
    final normalizedHour = hour.clamp(0, 23);
    final suffix = normalizedHour >= 12 ? 'PM' : 'AM';
    final hourOfPeriod = normalizedHour % 12 == 0 ? 12 : normalizedHour % 12;
    return '$hourOfPeriod $suffix';
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
    if (lowerTheme.length <= 24 && !lowerTheme.contains(',')) {
      return 'Reduce $lowerTheme before you start';
    }
    return 'Reduce one likely distraction';
  }
}
