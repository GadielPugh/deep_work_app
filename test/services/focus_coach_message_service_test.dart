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
    test('builds a warning message for a weak current recommendation', () {
      final message = service.buildMessage(
        data: _baseInsightsData(
          currentRecommendation: const CurrentFocusRecommendationDto(
            categoryId: 'coding',
            categoryName: 'Coding',
            recommendedDurationMinutes: 20,
            successProbability: 0.42,
            sampleCount: 12,
          ),
          predictionWarning: PredictionWarningDto(
            title: 'Low success risk',
            message: 'debug',
            successProbability: 0.32,
            recommendedCategoryId: 'coding',
            recommendedCategoryName: 'Coding',
            recommendedDurationMinutes: 20,
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
              categoryId: 'coding',
              bestHour: 9,
              bestSuccessRatePercent: 90,
              bestHourSampleCount: 5,
              worstHour: 23,
              worstSuccessRatePercent: 40,
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
            level: InsightConfidenceLevel.high,
            sampleCount: 12,
            isTrusted: true,
            reason: 'Enough history',
          ),
        ),
        categories: categories,
        now: DateTime(2026, 1, 1, 23),
      );

      expect(message.type, FocusCoachMessageType.warning);
      expect(message.title, 'Right now, Coding looks like your best option.');
      expect(
        message.body,
        'This may not be your strongest time, so keep it short.',
      );
      expect(message.confidenceLabel, 'Keep it simple');
      expect(message.actionText, 'Try 20 min of Coding');
      expect(
        message.reasonLine,
        'You may do better with this tomorrow morning.',
      );
    });

    test(
      'builds a positive try-now message for a strong current recommendation',
      () {
        final message = service.buildMessage(
          data: _baseInsightsData(
            currentRecommendation: const CurrentFocusRecommendationDto(
              categoryId: 'writing',
              categoryName: 'Writing',
              recommendedDurationMinutes: 25,
              successProbability: 0.68,
              sampleCount: 8,
            ),
            successRateByCategory: const [
              CategorySuccessRateDto(
                categoryId: 'writing',
                successRatePercent: 82,
                count: 8,
              ),
            ],
            bestWorstHoursByCategory: const [
              CategoryHourExtremaDto(
                categoryId: 'writing',
                bestHour: 18,
                bestSuccessRatePercent: 88,
                bestHourSampleCount: 5,
                worstHour: 12,
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
          now: DateTime(2026, 1, 1, 18),
        );

        expect(message.type, FocusCoachMessageType.positive);
        expect(message.title, 'This looks like a good time for Writing.');
        expect(
          message.body,
          'You\'ve been more consistent with Writing lately.',
        );
        expect(message.confidenceLabel, 'Try now');
        expect(message.actionText, 'Try 25 min of Writing');
      },
    );

    test('builds a positive historical pattern message with a time block', () {
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
        now: DateTime(2026, 1, 1, 18),
      );

      expect(message.type, FocusCoachMessageType.positive);
      expect(message.title, 'Writing is usually stronger in the morning.');
      expect(message.confidenceLabel, 'A good next step');
      expect(message.actionText, 'Try Writing in the morning');
    });

    test('hides better-later hint when the time pattern is weak', () {
      final message = service.buildMessage(
        data: _baseInsightsData(
          currentRecommendation: const CurrentFocusRecommendationDto(
            categoryId: 'coding',
            categoryName: 'Coding',
            recommendedDurationMinutes: 20,
            successProbability: 0.42,
            sampleCount: 12,
          ),
          predictionWarning: PredictionWarningDto(
            title: 'Low success risk',
            message: 'debug',
            successProbability: 0.42,
            recommendedCategoryId: 'coding',
            recommendedCategoryName: 'Coding',
            recommendedDurationMinutes: 20,
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
              categoryId: 'coding',
              bestHour: 9,
              bestSuccessRatePercent: 68,
              bestHourSampleCount: 3,
              worstHour: 23,
              worstSuccessRatePercent: 52,
              worstHourSampleCount: 2,
              sampleCount: 8,
              confidence: InsightConfidenceDto(
                level: InsightConfidenceLevel.medium,
                sampleCount: 8,
                isTrusted: true,
                reason: 'Early pattern',
              ),
            ),
          ],
          predictionWarningConfidence: const InsightConfidenceDto(
            level: InsightConfidenceLevel.high,
            sampleCount: 12,
            isTrusted: true,
            reason: 'Enough history',
          ),
        ),
        categories: categories,
        now: DateTime(2026, 1, 1, 23),
      );

      expect(message.reasonLine, isNull);
    });

    test('uses a soft reflection hint when it is repeated enough', () {
      final message = service.buildMessage(
        data: _baseInsightsData(
          currentRecommendation: const CurrentFocusRecommendationDto(
            categoryId: 'coding',
            categoryName: 'Coding',
            recommendedDurationMinutes: 20,
            successProbability: 0.44,
            sampleCount: 9,
          ),
          predictionWarning: PredictionWarningDto(
            title: 'Low success risk',
            message: 'debug',
            successProbability: 0.44,
            recommendedCategoryId: 'coding',
            recommendedCategoryName: 'Coding',
            recommendedDurationMinutes: 20,
            riskFactors: const ['debug'],
            sampleCount: 9,
            confidence: const InsightConfidenceDto(
              level: InsightConfidenceLevel.high,
              sampleCount: 9,
              isTrusted: true,
              reason: 'Enough history',
            ),
          ),
          recurringDistractionThemes: const [
            RecurringThemeDto(theme: 'school stress', count: 3),
          ],
          predictionWarningConfidence: const InsightConfidenceDto(
            level: InsightConfidenceLevel.high,
            sampleCount: 9,
            isTrusted: true,
            reason: 'Enough history',
          ),
        ),
        categories: categories,
        now: DateTime(2026, 1, 1, 14),
      );

      expect(
        message.reasonLine,
        'Recent reflections sometimes mention school stress.',
      );
    });

    test('hides reflection hint when it is weak', () {
      final message = service.buildMessage(
        data: _baseInsightsData(
          currentRecommendation: const CurrentFocusRecommendationDto(
            categoryId: 'writing',
            categoryName: 'Writing',
            recommendedDurationMinutes: 25,
            successProbability: 0.68,
            sampleCount: 8,
          ),
          successRateByCategory: const [
            CategorySuccessRateDto(
              categoryId: 'writing',
              successRatePercent: 82,
              count: 8,
            ),
          ],
          recurringDistractionThemes: const [
            RecurringThemeDto(theme: 'school stress', count: 2),
          ],
          predictionWarningConfidence: const InsightConfidenceDto(
            level: InsightConfidenceLevel.medium,
            sampleCount: 8,
            isTrusted: false,
            reason: 'Still early',
          ),
        ),
        categories: categories,
        now: DateTime(2026, 1, 1, 18),
      );

      expect(message.reasonLine, isNull);
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
        now: DateTime(2026, 1, 1, 14),
      );

      expect(message.type, FocusCoachMessageType.suggestion);
      expect(message.title, 'One distraction keeps coming up');
      expect(message.confidenceLabel, 'Best next step');
      expect(message.actionText, 'Put your phone away first');
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
        now: DateTime(2026, 1, 1, 14),
      );

      expect(message.type, FocusCoachMessageType.notEnoughData);
      expect(message.confidenceLabel, 'Best next step');
      expect(
        message.body,
        'I need a little more data before I can give a strong suggestion. Try adding a few more sessions and reflections.',
      );
    });

    test('uses neutral fallback when data exists but no pattern stands out', () {
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
        now: DateTime(2026, 1, 1, 14),
      );

      expect(message.type, FocusCoachMessageType.neutral);
      expect(message.title, 'Your pattern is still forming');
      expect(message.confidenceLabel, 'Keep it simple');
      expect(
        message.body,
        'I do not see one clear pattern yet. Keep sessions short and add brief reflections.',
      );
    });

    test(
      'maps hours into time blocks and handles near-now around midnight',
      () {
        expect(service.timeBlockForHour(5), 'morning');
        expect(service.timeBlockForHour(14), 'afternoon');
        expect(service.timeBlockForHour(19), 'evening');
        expect(service.timeBlockForHour(23), 'night');
        expect(service.timeBlockForHour(2), 'night');
        expect(service.isHourNearNow(23, 1), isTrue);
        expect(service.isHourNearNow(9, 14), isFalse);
        expect(service.describeTimeBlock(9), 'in the morning');
      },
    );

    test('formats singular and plural session wording', () {
      expect(service.formatSessionCount(1), '1 session');
      expect(service.formatSessionCount(2), '2 sessions');
    });
  });
}

InsightsData _baseInsightsData({
  CurrentFocusRecommendationDto? currentRecommendation,
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
    currentRecommendation: currentRecommendation,
    predictionWarning: predictionWarning,
    predictionWarningConfidence: predictionWarningConfidence,
    recurringDistractionThemes: recurringDistractionThemes,
    streaks: streaks,
    bestWorstHoursByCategory: bestWorstHoursByCategory,
    successRateByCategory: successRateByCategory,
    avgDurationByCategory: const [],
  );
}
