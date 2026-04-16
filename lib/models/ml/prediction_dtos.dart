// Prediction-related DTOs consumed by the Flutter UI.
import 'package:deep_work/models/analytics/insight_confidence_dtos.dart';

class CurrentFocusRecommendationDto {
  const CurrentFocusRecommendationDto({
    required this.categoryId,
    required this.categoryName,
    required this.recommendedDurationMinutes,
    required this.successProbability,
    required this.sampleCount,
    this.isCautiousFallback = false,
  });

  final String categoryId;
  final String categoryName;
  final int recommendedDurationMinutes;
  final double successProbability;
  final int sampleCount;
  final bool isCautiousFallback;
}

class PredictionWarningDto {
  const PredictionWarningDto({
    required this.title,
    required this.message,
    required this.successProbability,
    required this.recommendedCategoryId,
    required this.recommendedCategoryName,
    required this.recommendedDurationMinutes,
    required this.riskFactors,
    int? sampleCount,
    bool? isCautiousFallback,
    InsightConfidenceDto? confidence,
  }) : _sampleCount = sampleCount,
       _isCautiousFallback = isCautiousFallback,
       _confidence = confidence;

  /// Probability in the range [0..1].
  final double successProbability;
  final String title;
  final String message;
  final String recommendedCategoryId;
  final String recommendedCategoryName;
  final int recommendedDurationMinutes;
  final List<String> riskFactors;
  // Nullable backing fields keep the DTO resilient across hot reloads after
  // new properties are added during iterative development.
  final int? _sampleCount;
  final bool? _isCautiousFallback;
  final InsightConfidenceDto? _confidence;

  int get sampleCount => _sampleCount ?? 0;

  bool get isCautiousFallback => _isCautiousFallback ?? false;

  InsightConfidenceDto get confidence =>
      _confidence ??
      const InsightConfidenceDto(
        level: InsightConfidenceLevel.low,
        sampleCount: 0,
        isTrusted: false,
        reason: 'Not enough data yet.',
      );

  String get successProbabilityLabel =>
      '${(successProbability * 100).round()}%';
}
