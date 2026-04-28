import 'package:deep_work/models/ml/prediction_dtos.dart';
import 'package:deep_work/models/analytics/insight_confidence_dtos.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/models/personalization/local_personalization_profile.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/services/feature_engineering/focus_feature_engineering.dart';
import 'package:deep_work/services/analytics/insight_confidence_service.dart';
import 'package:deep_work/services/personalization/personalized_recommendation_service.dart';

import 'session_success_predictor.dart';

class CategoryRecommendation {
  const CategoryRecommendation({
    required this.categoryId,
    required this.categoryName,
    required this.successProbability,
    required this.recommendedDurationMinutes,
    required this.riskFactors,
    required this.sampleCount,
    this.isCautiousFallback = false,
  });

  final String categoryId;
  final String categoryName;
  final double successProbability;
  final int recommendedDurationMinutes;
  final List<String> riskFactors;
  final int sampleCount;
  final bool isCautiousFallback;
}

/// High-level helpers to turn success probability into recommendations.
class SessionSuccessRecommendationService {
  SessionSuccessRecommendationService({
    required this.predictor,
    required this.featureEngineeringService,
    this.personalizationProfileProvider,
    this.personalizedRecommendationService,
  }) : _confidenceService = const InsightConfidenceService();

  final SessionSuccessPredictor predictor;
  final FocusFeatureEngineeringService featureEngineeringService;
  final InsightConfidenceService _confidenceService;
  final LocalPersonalizationProfile Function()? personalizationProfileProvider;
  final PersonalizedRecommendationService? personalizedRecommendationService;

  /// Picks the category that maximizes predicted success probability for the
  /// current hour, using each category's rolling-average duration as the
  /// candidate duration.
  CategoryRecommendation recommendBestCategoryForCurrentHour({
    required DateTime now,
    required List<Session> sessions,
    required List<FocusCategory> categories,
  }) {
    if (categories.isEmpty) {
      throw ArgumentError('categories must not be empty');
    }

    final personalizedRecommendation = _personalizedRecommendationOrNull(
      now: now,
      sessions: sessions,
      categories: categories,
    );
    if (personalizedRecommendation != null) {
      return personalizedRecommendation;
    }

    if (sessions.isEmpty) {
      // No history: return a neutral default.
      return CategoryRecommendation(
        categoryId: categories.first.id,
        categoryName: categories.first.name,
        successProbability: 0.5,
        recommendedDurationMinutes: 25,
        riskFactors: const ['no history yet'],
        sampleCount: 0,
        isCautiousFallback: true,
      );
    }

    final localNow = now.toLocal();
    final rollingStart = localNow.subtract(
      Duration(days: featureEngineeringService.rollingWindowDays),
    );

    List<Session> sessionsInWindowForCategory(String categoryId) {
      final inWindow = sessions.where((s) {
        final local = s.dateTime.toLocal();
        return local.isAfter(rollingStart) &&
            local.isBefore(localNow) &&
            s.categoryId == categoryId;
      }).toList();
      return inWindow;
    }

    double avgSuccessfulDurationForCategory(String categoryId) {
      final inWindow = sessionsInWindowForCategory(categoryId);
      if (inWindow.isEmpty) return 25.0;

      final successful = inWindow
          .where((s) => s.outcome.name == 'yes')
          .toList();
      final source = successful.isNotEmpty ? successful : inWindow;
      return source.map((s) => s.durationMinutes).reduce((a, b) => a + b) /
          source.length;
    }

    int practicalDurationBucket(double durationMinutes) {
      if (durationMinutes <= 15) return 10;
      if (durationMinutes <= 22) return 20;
      if (durationMinutes <= 27) return 25;
      return 30;
    }

    int idealDurationMinutesForCategory(String categoryId) {
      final avg = avgSuccessfulDurationForCategory(categoryId);
      return practicalDurationBucket(avg);
    }

    int sampleCountForCategory(String categoryId) {
      return sessionsInWindowForCategory(categoryId).length;
    }

    bool hasZeroHistoricalSuccess(String categoryId) {
      final inWindow = sessionsInWindowForCategory(categoryId);
      if (inWindow.isEmpty) return false;
      final yesCount = inWindow.where((s) => s.outcome.name == 'yes').length;
      return yesCount == 0;
    }

    bool allCategoriesPoor() {
      final eligible = categories
          .where((c) => sampleCountForCategory(c.id) >= 3)
          .toList();
      if (eligible.isEmpty) return true;
      for (final c in eligible) {
        if (!hasZeroHistoricalSuccess(c.id)) return false;
      }
      return true;
    }

    final everyCategoryLooksPoor = allCategoriesPoor();

    CategoryRecommendation? best;

    for (final c in categories) {
      final duration = idealDurationMinutesForCategory(c.id);
      final sampleCount = sampleCountForCategory(c.id);

      final candidateFeatures = featureEngineeringService.buildCandidateFeatures(
        now: now,
        sessions: sessions,
        categoryId: c.id,
        sessionDurationMinutes: duration,
        // We don't have a user goal/reflection yet for a "next session" prediction.
        intentionLength: 0,
        reflectionLength: 0,
      );

      final prediction = predictor.predictSuccessProbability(
        features: candidateFeatures,
      );
      final isEligible = _confidenceService.isRecommendationCategoryEligible(
        sampleCount: sampleCount,
        successProbability: hasZeroHistoricalSuccess(c.id)
            ? 0
            : prediction.successProbability,
        allCategoriesPoor: everyCategoryLooksPoor,
      );
      if (!isEligible) continue;

      final recommendation = CategoryRecommendation(
        categoryId: c.id,
        categoryName: c.name,
        successProbability: prediction.successProbability,
        recommendedDurationMinutes: duration,
        riskFactors: prediction.reasons,
        sampleCount: sampleCount,
        isCautiousFallback: everyCategoryLooksPoor,
      );

      if (best == null ||
          recommendation.successProbability > best.successProbability) {
        best = recommendation;
      }
    }

    return best ??
        CategoryRecommendation(
          categoryId: categories.first.id,
          categoryName: categories.first.name,
          successProbability: 0.5,
          recommendedDurationMinutes: 25,
          riskFactors: const [
            'limited category history',
            'patterns are not stable yet',
          ],
          sampleCount: 0,
          isCautiousFallback: true,
        );
  }

  CategoryRecommendation? _personalizedRecommendationOrNull({
    required DateTime now,
    required List<Session> sessions,
    required List<FocusCategory> categories,
  }) {
    final profileProvider = personalizationProfileProvider;
    final service = personalizedRecommendationService;
    if (profileProvider == null || service == null) return null;

    try {
      final profile = profileProvider();
      if (sessions.isNotEmpty && profile.totalSessions == 0) return null;

      final recommendation = service.recommend(
        now: now,
        categories: categories,
        profile: profile,
      );
      return CategoryRecommendation(
        categoryId: recommendation.categoryId,
        categoryName: recommendation.categoryName,
        successProbability: recommendation.successProbability,
        recommendedDurationMinutes: recommendation.recommendedDurationMinutes,
        riskFactors: recommendation.reasons,
        sampleCount: recommendation.sampleCount,
        isCautiousFallback: recommendation.isCautiousFallback,
      );
    } catch (_) {
      return null;
    }
  }

  /// Generates a low-success warning if the best category's probability is
  /// below [threshold].
  PredictionWarningDto? getLowSuccessWarningIfNeeded({
    required DateTime now,
    required List<Session> sessions,
    required List<FocusCategory> categories,
    double threshold = 0.45,
    String? mostLikelyDistractionTheme,
  }) {
    final confidenceService = const InsightConfidenceService();
    final totalSessions = sessions.length;
    final predictionConfidence = confidenceService
        .confidenceForPredictionWarning(totalSessionCount: totalSessions);

    final best = recommendBestCategoryForCurrentHour(
      now: now,
      sessions: sessions,
      categories: categories,
    );

    final hasMeaningfulProbabilitySignal = best.successProbability < threshold;
    final isValidWarning = _confidenceService.isPredictionWarningValid(
      confidence: predictionConfidence,
      hasEligibleRecommendation: best.sampleCount >= 3,
      hasMeaningfulProbabilitySignal: hasMeaningfulProbabilitySignal,
    );
    if (!isValidWarning) return null;

    final probLabel = best.successProbability * 100;
    final themePart =
        (mostLikelyDistractionTheme != null &&
            mostLikelyDistractionTheme.isNotEmpty)
        ? ' Recent failed sessions sometimes mention: $mostLikelyDistractionTheme.'
        : '';

    final message = best.isCautiousFallback
        ? 'Recent results look weak across categories, so this is only a cautious suggestion. '
              'You could try ${best.categoryName} for ${best.recommendedDurationMinutes} minutes, '
              'but confidence is limited.$themePart'
        : 'Estimated success probability is about ${probLabel.round()}%. '
              'You could try ${best.categoryName} for ${best.recommendedDurationMinutes} minutes'
              '${predictionConfidence.level == InsightConfidenceLevel.medium ? ', but confidence is limited' : ''}.'
              '$themePart';

    return PredictionWarningDto(
      title: 'Low success risk',
      message: message,
      successProbability: best.successProbability,
      recommendedCategoryId: best.categoryId,
      recommendedCategoryName: best.categoryName,
      recommendedDurationMinutes: best.recommendedDurationMinutes,
      riskFactors: [
        ...best.riskFactors,
        if (mostLikelyDistractionTheme != null &&
            mostLikelyDistractionTheme.isNotEmpty)
          'common distraction theme=$mostLikelyDistractionTheme',
      ],
      sampleCount: totalSessions,
      isCautiousFallback: best.isCautiousFallback,
      confidence: predictionConfidence,
    );
  }
}
