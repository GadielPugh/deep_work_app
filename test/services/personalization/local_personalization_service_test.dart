import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/models/coach_feedback_entry.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/models/personalization/local_personalization_profile.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/services/analytics/focus_coach_message_service.dart';
import 'package:deep_work/services/analytics/insights_analytics_service.dart';
import 'package:deep_work/services/personalization/local_personalization_profile_service.dart';
import 'package:deep_work/services/personalization/personalized_recommendation_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Local personalization', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'produces a useful cold-start recommendation with zero history',
      () async {
        final profileService = LocalPersonalizationProfileService();
        await profileService.load();
        final analyticsService = InsightsAnalyticsService(
          personalizationProfileService: profileService,
        );

        final data = analyticsService.computeInsightsData(
          sessions: const [],
          categories: _categories,
          now: DateTime(2026, 1, 1, 9),
        );

        final recommendation = data.currentRecommendation;
        expect(recommendation, isNotNull);
        expect(recommendation!.successProbability, inInclusiveRange(0, 1));
        expect(recommendation.recommendedDurationMinutes, 15);
        expect(recommendation.isCautiousFallback, isTrue);

        final message = const FocusCoachMessageService().buildMessage(
          data: data,
          categories: _categories,
          now: DateTime(2026, 1, 1, 9),
        );
        expect(message.recommendedCategory, recommendation.categoryName);
        expect(message.recommendedDurationMinutes, 15);
        expect(message.confidenceLabel, 'Keep it simple');
      },
    );

    test(
      'updates category and time-block success rates after sessions',
      () async {
        final service = LocalPersonalizationProfileService();

        await service.recordCompletedSession(
          categoryId: 'coding',
          startedAt: DateTime(2026, 1, 1, 9),
          durationSeconds: 25 * 60,
          outcome: 'yes',
          reflection: 'Phone notifications made me tired.',
        );
        await service.recordCompletedSession(
          categoryId: 'coding',
          startedAt: DateTime(2026, 1, 2, 9),
          durationSeconds: 25 * 60,
          outcome: 'no',
        );

        final profile = service.profile;
        expect(profile.totalSessions, 2);
        expect(profile.totalSuccesses, 1);
        expect(profile.categoryStats['coding']?.attempts, 2);
        expect(profile.categoryStats['coding']?.successes, 1);
        expect(profile.timeBlockStats['morning']?.attempts, 2);
        expect(
          profile
              .categoryTimeBlockStats[LocalPersonalizationProfile.categoryTimeKey(
                'coding',
                'morning',
              )]
              ?.successes,
          1,
        );
        expect(profile.reflectionThemeCounts['phone'], 1);
        expect(profile.reflectionThemeCounts['tired'], 1);
      },
    );

    test(
      'updates preferred duration bucket from successful sessions',
      () async {
        final service = LocalPersonalizationProfileService();

        await service.recordCompletedSession(
          categoryId: 'reading',
          startedAt: DateTime(2026, 1, 1, 8),
          durationSeconds: 25 * 60,
          outcome: 'yes',
        );
        await service.recordCompletedSession(
          categoryId: 'reading',
          startedAt: DateTime(2026, 1, 2, 8),
          durationSeconds: 30 * 60,
          outcome: 'yes',
        );
        await service.recordCompletedSession(
          categoryId: 'reading',
          startedAt: DateTime(2026, 1, 3, 8),
          durationSeconds: 55 * 60,
          outcome: 'no',
        );

        expect(
          service.profile.preferredDurationBucketForCategory('reading'),
          'standard',
        );
      },
    );

    test('bootstraps existing local sessions only once', () async {
      final service = LocalPersonalizationProfileService();
      final sessions = [
        Session(
          intention: 'Practice',
          durationMinutes: 15,
          outcome: CompletionStatus.yes,
          dateTime: DateTime(2026, 1, 1, 9),
          categoryId: 'coding',
          reflection: 'Felt focused.',
        ),
        Session(
          intention: 'Read',
          durationMinutes: 40,
          outcome: CompletionStatus.no,
          dateTime: DateTime(2026, 1, 2, 22),
          categoryId: 'reading',
          reflection: 'Too tired.',
        ),
      ];

      await service.bootstrapFromSessionsIfEmpty(sessions);
      await service.bootstrapFromSessionsIfEmpty(sessions);

      expect(service.profile.totalSessions, 2);
      expect(service.profile.categoryStats['coding']?.successes, 1);
      expect(service.profile.timeBlockStats['night']?.attempts, 1);
      expect(service.profile.reflectionThemeCounts['focused'], 1);
      expect(service.profile.reflectionThemeCounts['tired'], 1);
    });

    test('stores lightweight coach helpful and not-helpful counts', () async {
      final service = LocalPersonalizationProfileService();
      final message = const FocusCoachMessage(
        title: 'Start small',
        body: 'Try a short session.',
        actionText: 'Try 15 min of Reading',
        confidenceLabel: 'Keep it simple',
        recommendedCategory: 'Reading',
        recommendedDurationMinutes: 15,
        type: FocusCoachMessageType.suggestion,
      );

      await service.recordCoachFeedback(
        CoachFeedbackEntry.fromMessage(
          message: message,
          wasHelpful: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      await service.recordCoachFeedback(
        CoachFeedbackEntry.fromMessage(
          message: message,
          wasHelpful: false,
          createdAt: DateTime(2026, 1, 2),
        ),
      );

      expect(service.profile.coachHelpfulCount, 1);
      expect(service.profile.coachNotHelpfulCount, 1);
      expect(service.profile.coachHelpfulRate, 0.5);
    });

    test(
      'personalizes recommendations after repeated local outcomes',
      () async {
        final service = LocalPersonalizationProfileService();

        for (var i = 0; i < 6; i++) {
          await service.recordCompletedSession(
            categoryId: 'coding',
            startedAt: DateTime(2026, 1, 1 + i, 22),
            durationSeconds: 25 * 60,
            outcome: 'no',
          );
          await service.recordCompletedSession(
            categoryId: 'reading',
            startedAt: DateTime(2026, 1, 1 + i, 22),
            durationSeconds: 25 * 60,
            outcome: 'yes',
          );
        }

        final recommendation = const PersonalizedRecommendationService()
            .recommend(
              now: DateTime(2026, 1, 10, 22),
              categories: _categories,
              profile: service.profile,
            );

        expect(recommendation.categoryId, 'reading');
        expect(recommendation.successProbability, inInclusiveRange(0, 1));
        expect(recommendation.sampleCount, 6);
      },
    );

    test('returns a valid recommendation with sparse local data', () async {
      final service = LocalPersonalizationProfileService();
      await service.recordCompletedSession(
        categoryId: 'writing',
        startedAt: DateTime(2026, 1, 1, 18),
        durationSeconds: 10 * 60,
        outcome: 'partially',
      );

      final recommendation = const PersonalizedRecommendationService()
          .recommend(
            now: DateTime(2026, 1, 2, 18),
            categories: _categories,
            profile: service.profile,
          );

      expect(recommendation.categoryId, isNotEmpty);
      expect(recommendation.successProbability, inInclusiveRange(0, 1));
      expect(recommendation.recommendedDurationMinutes, greaterThan(0));
    });
  });
}

final _categories = [
  FocusCategory(
    id: 'reading',
    name: 'Reading',
    iconCodePoint: CupertinoIcons.book.codePoint,
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
  FocusCategory(
    id: 'coding',
    name: 'Coding',
    iconCodePoint: CupertinoIcons.chevron_left_slash_chevron_right.codePoint,
    iconFontFamily: CupertinoIcons.iconFont,
    iconFontPackage: CupertinoIcons.iconFontPackage,
  ),
];
