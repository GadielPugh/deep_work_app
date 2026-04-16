import 'package:deep_work/models/analytics/insight_confidence_dtos.dart';
import 'package:deep_work/models/analytics/predictor_evaluation_dtos.dart';

class InsightsDebugInfoDto {
  const InsightsDebugInfoDto({
    required this.totalSessionCount,
    required this.predictionConfidence,
    required this.predictedSuccessProbability,
    required this.predictionReasons,
    required this.evaluationSummary,
    required this.ruleBeatsBaselines,
  });

  final int totalSessionCount;
  final InsightConfidenceDto predictionConfidence;
  final double predictedSuccessProbability;
  final List<String> predictionReasons;
  final PredictorEvaluationSummaryDto evaluationSummary;
  final bool ruleBeatsBaselines;
}

