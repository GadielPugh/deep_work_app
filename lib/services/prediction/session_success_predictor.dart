import 'package:deep_work/services/feature_engineering/focus_feature_engineering.dart';

/// Output of a success-probability predictor.
class SessionSuccessPrediction {
  const SessionSuccessPrediction({
    required this.successProbability,
    required this.reasons,
  });

  /// Probability in the range [0..1].
  final double successProbability;

  /// Human-readable contributors (useful for explainability UI).
  final List<String> reasons;
}

/// Prediction interface for session success probability.
///
/// This is the seam where future predictors (LiteRT/native, logistic regression,
/// decision tree) can be plugged in without changing UI/state consumers.
abstract class SessionSuccessPredictor {
  SessionSuccessPrediction predictSuccessProbability({
    required FocusCandidateFeatures features,
  });
}

