/// Offline predictor evaluation DTOs (local-only, deterministic).

class CalibrationBucketDto {
  const CalibrationBucketDto({
    required this.rangeStart,
    required this.rangeEnd,
    required this.count,
    required this.avgPredictedProbability,
    required this.observedSuccessRate,
  });

  final double rangeStart;
  final double rangeEnd;
  final int count;
  final double avgPredictedProbability;
  final double observedSuccessRate;
}

class BinaryClassificationMetricsDto {
  const BinaryClassificationMetricsDto({
    required this.totalCount,
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1,
    required this.brierScore,
    required this.calibrationBuckets,
  });

  final int totalCount;
  final double accuracy;
  final double precision;
  final double recall;
  final double f1;
  final double brierScore;
  final List<CalibrationBucketDto> calibrationBuckets;
}

class PredictorEvaluationResultDto {
  const PredictorEvaluationResultDto({
    required this.predictorId,
    required this.overall,
    required this.byCategory,
  });

  final String predictorId;
  final BinaryClassificationMetricsDto overall;
  final Map<String, BinaryClassificationMetricsDto> byCategory;
}

class PredictorEvaluationSummaryDto {
  const PredictorEvaluationSummaryDto({
    required this.ruleBased,
    required this.baselineRollingCategoryOnly,
    required this.baselineGlobalOnly,
  });

  final PredictorEvaluationResultDto ruleBased;
  final PredictorEvaluationResultDto baselineRollingCategoryOnly;
  final PredictorEvaluationResultDto baselineGlobalOnly;
}

