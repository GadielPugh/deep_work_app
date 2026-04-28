import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/models/personalization/local_personalization_profile.dart';
import 'package:deep_work/services/personalization/default_recommendation_priors.dart';
import 'package:deep_work/services/personalization/local_personalization_profile_service.dart';

class PersonalizedScoredRecommendation {
  const PersonalizedScoredRecommendation({
    required this.categoryId,
    required this.categoryName,
    required this.durationBucket,
    required this.recommendedDurationMinutes,
    required this.successProbability,
    required this.confidenceLabel,
    required this.reasons,
    required this.sampleCount,
    required this.isCautiousFallback,
  });

  final String categoryId;
  final String categoryName;
  final String durationBucket;
  final int recommendedDurationMinutes;
  final double successProbability;
  final String confidenceLabel;
  final List<String> reasons;
  final int sampleCount;
  final bool isCautiousFallback;
}

class PersonalizedRecommendationService {
  const PersonalizedRecommendationService({
    this.priors = const DefaultRecommendationPriors(),
  });

  final DefaultRecommendationPriors priors;

  PersonalizedScoredRecommendation recommend({
    required DateTime now,
    required List<FocusCategory> categories,
    required LocalPersonalizationProfile profile,
  }) {
    if (categories.isEmpty) {
      throw ArgumentError('categories must not be empty');
    }

    final timeBlock = LocalPersonalizationProfileService.timeBlockForDateTime(
      now,
    );
    final scored = categories.map((category) {
      final durationBucket =
          profile.preferredDurationBucketForCategory(category.id) ??
          priors.defaultDurationBucket(
            categoryId: category.id,
            categoryName: category.name,
            totalSessions: profile.totalSessions,
          );
      final score = _scoreCategory(
        category: category,
        timeBlock: timeBlock,
        durationBucket: durationBucket,
        profile: profile,
      );
      return _ScoredCategory(
        category: category,
        durationBucket: durationBucket,
        score: score.score,
        reasons: score.reasons,
        sampleCount: score.sampleCount,
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    final best = scored.first;
    final confidenceLabel = _confidenceLabel(
      score: best.score,
      profile: profile,
      sampleCount: best.sampleCount,
    );
    final isCautious = profile.totalSessions < 5 || best.sampleCount < 3;

    return PersonalizedScoredRecommendation(
      categoryId: best.category.id,
      categoryName: best.category.name,
      durationBucket: best.durationBucket,
      recommendedDurationMinutes: priors.durationMinutesForBucket(
        best.durationBucket,
      ),
      successProbability: best.score.clamp(0.05, 0.95),
      confidenceLabel: confidenceLabel,
      reasons: [
        ...best.reasons,
        'confidence=$confidenceLabel',
        if (isCautious) 'using cautious local prior',
      ],
      sampleCount: best.sampleCount,
      isCautiousFallback: isCautious,
    );
  }

  _ScoreResult _scoreCategory({
    required FocusCategory category,
    required String timeBlock,
    required String durationBucket,
    required LocalPersonalizationProfile profile,
  }) {
    final categoryKey = category.id.toLowerCase();
    final timeKey = timeBlock.toLowerCase();
    final categoryTimeKey = LocalPersonalizationProfile.categoryTimeKey(
      categoryKey,
      timeKey,
    );
    final categoryStat = profile.categoryStats[categoryKey];
    final timeStat = profile.timeBlockStats[timeKey];
    final categoryTimeStat = profile.categoryTimeBlockStats[categoryTimeKey];
    final prior = priors.categoryTimePrior(
      categoryId: category.id,
      categoryName: category.name,
      timeBlock: timeBlock,
    );

    var score = prior;
    final reasons = <String>[
      'prior=${prior.toStringAsFixed(2)}',
      'duration=$durationBucket',
    ];

    if (categoryStat != null && categoryStat.attempts > 0) {
      final blended = _smoothedRate(categoryStat, prior: prior);
      score = 0.55 * score + 0.45 * blended;
      reasons.add(
        'category success=${(categoryStat.successRate * 100).round()}%',
      );
    }
    if (timeStat != null && timeStat.attempts > 0) {
      final blended = _smoothedRate(timeStat, prior: prior);
      score = 0.75 * score + 0.25 * blended;
      reasons.add('time success=${(timeStat.successRate * 100).round()}%');
    }
    if (categoryTimeStat != null && categoryTimeStat.attempts > 0) {
      final blended = _smoothedRate(categoryTimeStat, prior: prior);
      score = 0.65 * score + 0.35 * blended;
      reasons.add(
        'category-time success=${(categoryTimeStat.successRate * 100).round()}%',
      );
    }

    score += priors.durationBucketAdjustment(
      bucket: durationBucket,
      totalSessions: profile.totalSessions,
    );
    if (profile.currentSuccessStreak >= 2) {
      score += 0.03;
      reasons.add('recent success streak=${profile.currentSuccessStreak}');
    }
    if (profile.currentFailureStreak >= 2) {
      score -= 0.04;
      reasons.add('recent failure streak=${profile.currentFailureStreak}');
    }
    if (profile.coachFeedbackCount >= 3 && profile.coachHelpfulRate < 0.4) {
      score -= 0.03;
      reasons.add('coach feedback has been mixed');
    }

    final repeatedTired = (profile.reflectionThemeCounts['tired'] ?? 0) >= 2;
    if (repeatedTired && timeBlock == 'night') {
      score -= 0.04;
      reasons.add('night sessions often mention tired');
    }

    return _ScoreResult(
      score: score.clamp(0.05, 0.95),
      reasons: reasons,
      sampleCount: categoryStat?.attempts ?? 0,
    );
  }

  double _smoothedRate(LocalSuccessStat stat, {required double prior}) {
    return (stat.successes + prior * 4) / (stat.attempts + 4);
  }

  String _confidenceLabel({
    required double score,
    required LocalPersonalizationProfile profile,
    required int sampleCount,
  }) {
    if (profile.totalSessions < 5 || sampleCount < 3) return 'low';
    if (score >= 0.68 && sampleCount >= 6) return 'high';
    return 'medium';
  }
}

class _ScoredCategory {
  const _ScoredCategory({
    required this.category,
    required this.durationBucket,
    required this.score,
    required this.reasons,
    required this.sampleCount,
  });

  final FocusCategory category;
  final String durationBucket;
  final double score;
  final List<String> reasons;
  final int sampleCount;
}

class _ScoreResult {
  const _ScoreResult({
    required this.score,
    required this.reasons,
    required this.sampleCount,
  });

  final double score;
  final List<String> reasons;
  final int sampleCount;
}
