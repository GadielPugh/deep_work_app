import 'package:deep_work/models/analytics/insight_confidence_dtos.dart';

/// Central place for "minimum data" and confidence gating rules.
///
/// Widgets should not hardcode numeric thresholds; they should rely on the
/// confidence decision computed here.
class InsightConfidenceService {
  const InsightConfidenceService();

  InsightConfidenceDto confidenceForBestWorstHours({
    required int categorySampleCount,
    int hideBelow = 5,
  }) {
    if (categorySampleCount < hideBelow) {
      return InsightConfidenceDto(
        level: InsightConfidenceLevel.low,
        sampleCount: categorySampleCount,
        isTrusted: false,
        reason: 'Not enough consistent data yet.',
      );
    }

    if (categorySampleCount < hideBelow + 5) {
      return InsightConfidenceDto(
        level: InsightConfidenceLevel.medium,
        sampleCount: categorySampleCount,
        isTrusted: true,
        reason: 'Early pattern only; confidence is still limited.',
      );
    }

    return InsightConfidenceDto(
      level: InsightConfidenceLevel.high,
      sampleCount: categorySampleCount,
      isTrusted: true,
      reason: 'Pattern looks reasonably stable.',
    );
  }

  InsightConfidenceDto confidenceForPredictionWarning({
    required int totalSessionCount,
    int hideBelow = 10,
  }) {
    if (totalSessionCount < hideBelow) {
      return InsightConfidenceDto(
        level: InsightConfidenceLevel.low,
        sampleCount: totalSessionCount,
        isTrusted: false,
        reason: 'Not enough sessions yet for a trustworthy warning.',
      );
    }

    if (totalSessionCount < hideBelow + 15) {
      return InsightConfidenceDto(
        level: InsightConfidenceLevel.medium,
        sampleCount: totalSessionCount,
        isTrusted: true,
        reason: 'Limited data; this is an early pattern.',
      );
    }

    return InsightConfidenceDto(
      level: InsightConfidenceLevel.high,
      sampleCount: totalSessionCount,
      isTrusted: true,
      reason: 'Enough history for a more stable warning.',
    );
  }

  bool hasMeaningfulHourSeparation({
    required double bestSuccessRatePercent,
    required double worstSuccessRatePercent,
    required int bestHourSampleCount,
    required int worstHourSampleCount,
    double minGapPercent = 15,
  }) {
    if (bestHourSampleCount <= 0 || worstHourSampleCount <= 0) return false;
    final gap = (bestSuccessRatePercent - worstSuccessRatePercent).abs();
    return gap >= minGapPercent;
  }

  bool shouldShowLikelyCauseTheme({
    required int themeCount,
    int minCount = 2,
  }) {
    return themeCount >= minCount;
  }

  bool isRecommendationCategoryEligible({
    required int sampleCount,
    required double successProbability,
    required bool allCategoriesPoor,
    int minCategorySampleCount = 3,
  }) {
    if (sampleCount < minCategorySampleCount) return false;
    if (!allCategoriesPoor && successProbability <= 0) return false;
    return true;
  }

  bool isPredictionWarningValid({
    required InsightConfidenceDto confidence,
    required bool hasEligibleRecommendation,
    required bool hasMeaningfulProbabilitySignal,
  }) {
    return confidence.isTrusted &&
        hasEligibleRecommendation &&
        hasMeaningfulProbabilitySignal;
  }
}

