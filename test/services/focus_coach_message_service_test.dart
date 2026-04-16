import 'package:deep_work/models/analytics/insight_confidence_dtos.dart';
import 'package:deep_work/models/analytics/insights_analytics_dtos.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/models/insights_data.dart';
import 'package:deep_work/models/ml/prediction_dtos.dart';
import 'package:deep_work/services/analytics/focus_coach_message_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = FocusCoachMessageService();
  final categories = [
    FocusCategory(
      id: 'coding',
      name: 'Coding',
      iconCodePoint: CupertinoIcons.chevron_left_slash_chevron_right.codePoint,
      iconFontFamily: CupertinoIcons.iconFont,
      iconFontPackage: CupertinoIcons.iconFontPackage,
    ),
    FocusCategory(
      id: 'writing',
      name: 'Writing',
      iconCodePoint: CupertinoIcons.pencil.codePoint,
      iconFontFamily: CupertinoIcons.iconFont,
      iconFontPackage: CupertinoIcons.iconFontPackage,
    ),
  ];

  group('FocusCoachMessageService', () {
    test('prefers low success risk warning over other signals', () {
      final message = service.buildMessage(
        data: _baseInsightsData(
          predictionWarning: PredictionWarningDto(
            title: 'Low success risk',
            message: 'debug',
            successProbability: 0.32,
            recommendedCategoryId: 'coding',
            recommendedCategoryName: 'Coding',
            recommendedDurationMinutes: 25,
            riskFactors: const ['debug'],
            sampleCount: 12,
            confidence: const InsightConfidenceDto(
              level: InsightConfidenceLevel.high,
              sampleCount: 12,
              isTrusted: true,
              reason: 'Enough history',
            ),
          ),
          bestWorstHoursByCategory: const [
            CategoryHourExtremaDto(
              categoryId: 'writing',
              bestHour: 9,
              bestSuccessRatePercent: 90,
              bestHourSampleCount: 4,
              worstHour: 15,
              worstSuccessRatePercent: 40,
              worstHourSampleCount: 3,
              sampleCount: 8,
              confidence: InsightConfidenceDto(
                level: InsightConfidenceLevel.high,
                sampleCount: 8,
                isTrusted: true,
                reason: 'Stable',
              ),
            ),
          ],
          recurringDistractionThemes: const [
            RecurringThemeDto(theme: 'phone', count: 3),
          ],
          streaks: const StreaksDto(
            currentSuccessStreak: 4,
            maxSuccessStreak: 4,
            currentCategorySuccessStreaks: {'writing': 4},
          ),
          predictionWarningConfidence: const InsightConfidenceDto(
            level: InsightConfidenceLevel.high,
            sampleCount: 12,
            isTrusted: true,
            reason: 'Enough history',
          ),
        ),
        categories: categories,
      );

      expect(message.type, FocusCoachMessageType.warning);
      expect(message.title, 'Your next session may need a simpler plan');
      expect(message.actionText, 'Try 25 min of Coding');
    });

    test('builds a positive message from a trusted time pattern', () {
      final message = service.buildMessage(
        data: _baseInsightsData(
          bestWorstHoursByCategory: const [
            CategoryHourExtremaDto(
              categoryId: 'writing',
              bestHour: 9,
              bestSuccessRatePercent: 88,
              bestHourSampleCount: 5,
              worstHour: 15,
              worstSuccessRatePercent: 42,
              worstHourSampleCount: 4,
              sampleCount: 10,
              confidence: InsightConfidenceDto(
                level: InsightConfidenceLevel.high,
                sampleCount: 10,
                isTrusted: true,
                reason: 'Stable',
              ),
            ),
          ],
          predictionWarningConfidence: const InsightConfidenceDto(
            level: InsightConfidenceLevel.medium,
            sampleCount: 8,
            isTrusted: false,
            reason: 'Still early',
          ),
        ),
        categories: categories,
      );

      expect(message.type, FocusCoachMessageType.positive);
      expect(message.title, 'You have a strong focus window');
      expect(message.actionText, 'Plan Writing near 9 AM');
    });

    test('builds a distraction suggestion when no stronger signal exists', () {
      final message = service.buildMessage(
        data: _baseInsightsData(
          recurringDistractionThemes: const [
            RecurringThemeDto(theme: 'phone', count: 3),
          ],
          predictionWarningConfidence: const InsightConfidenceDto(
            level: InsightConfidenceLevel.medium,
            sampleCount: 7,
            isTrusted: false,
            reason: 'Still early',
          ),
        ),
        categories: categories,
      );

      expect(message.type, FocusCoachMessageType.suggestion);
      expect(message.title, 'One distraction keeps coming up');
      expect(message.actionText, 'Reduce phone before you start');
    });

    test('uses not enough data fallback when history is very small', () {
      final message = service.buildMessage(
        data: _baseInsightsData(
          predictionWarningConfidence: const InsightConfidenceDto(
            level: InsightConfidenceLevel.low,
            sampleCount: 2,
            isTrusted: false,
            reason: 'Not enough data',
          ),
        ),
        categories: categories,
      );

      expect(message.type, FocusCoachMessageType.notEnoughData);
      expect(
        message.body,
        'I need a little more data before I can give a strong suggestion. Try adding a few more sessions and reflections.',
      );
    });

    test(
      'uses neutral fallback when data exists but no pattern stands out',
      () {
        final message = service.buildMessage(
          data: _baseInsightsData(
            predictionWarningConfidence: const InsightConfidenceDto(
              level: InsightConfidenceLevel.medium,
              sampleCount: 6,
              isTrusted: false,
              reason: 'Still early',
            ),
          ),
          categories: categories,
        );

        expect(message.type, FocusCoachMessageType.neutral);
        expect(message.title, 'Your pattern is still forming');
      },
    );
  });
}

InsightsData _baseInsightsData({
  PredictionWarningDto? predictionWarning,
  InsightConfidenceDto? predictionWarningConfidence,
  List<RecurringThemeDto> recurringDistractionThemes = const [],
  List<CategoryHourExtremaDto> bestWorstHoursByCategory = const [],
  List<CategorySuccessRateDto> successRateByCategory = const [],
  StreaksDto? streaks,
}) {
  return InsightsData(
    avgDailyFocusMinutes: 30,
    successRatePercent: 70,
    weeklyFocusMinutes: const [30, 20, 10, 0, 40, 25, 15],
    weekdayLabels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    weeklyMaxY: 40,
    focusByType: const [
      FocusTypeSegment(
        label: 'Coding',
        value: 4,
        color: CupertinoColors.activeBlue,
      ),
    ],
    peakPerformanceTitle: 'Peak Performance',
    peakPerformanceMessage: 'Morning looks good.',
    predictionWarning: predictionWarning,
    predictionWarningConfidence: predictionWarningConfidence,
    recurringDistractionThemes: recurringDistractionThemes,
    streaks: streaks,
    bestWorstHoursByCategory: bestWorstHoursByCategory,
    successRateByCategory: successRateByCategory,
    avgDurationByCategory: const [],
  );
}
