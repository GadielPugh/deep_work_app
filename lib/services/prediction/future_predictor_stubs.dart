import 'package:deep_work/services/feature_engineering/focus_feature_engineering.dart';

import 'session_success_predictor.dart';

/// Placeholder for a logistic regression predictor.
///
/// Later this would use learned weights (local-only) and apply them to
/// structured features from `FocusCandidateFeatures`.
class LogisticRegressionSessionSuccessPredictor
    implements SessionSuccessPredictor {
  @override
  SessionSuccessPrediction predictSuccessProbability({
    required FocusCandidateFeatures features,
  }) {
    throw UnimplementedError(
      'LogisticRegressionSessionSuccessPredictor is a placeholder (Phase 2).',
    );
  }
}

/// Placeholder for a decision tree predictor.
///
/// Later this would use a pre-trained decision tree (local-only).
class DecisionTreeSessionSuccessPredictor
    implements SessionSuccessPredictor {
  @override
  SessionSuccessPrediction predictSuccessProbability({
    required FocusCandidateFeatures features,
  }) {
    throw UnimplementedError(
      'DecisionTreeSessionSuccessPredictor is a placeholder (Phase 2).',
    );
  }
}

/// Placeholder for a LiteRT/native inference adapter.
///
/// TODO(android):
/// Wire a native LiteRT model invocation behind the `SessionSuccessPredictor`
/// interface using a MethodChannel (or similar) and return the inferred
/// probability back to Dart.
class LiteRtSessionSuccessPredictor implements SessionSuccessPredictor {
  @override
  SessionSuccessPrediction predictSuccessProbability({
    required FocusCandidateFeatures features,
  }) {
    throw UnimplementedError(
      'LiteRtSessionSuccessPredictor is a placeholder (Phase 2).',
    );
  }
}

