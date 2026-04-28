import 'exported_json_logistic_regression_predictor.dart';
import 'rule_based_success_predictor.dart';
import 'session_success_predictor.dart';

enum SessionSuccessPredictorBackend {
  ruleBased,
  exportedJsonLogisticRegression,
}

class SessionSuccessPredictorConfig {
  const SessionSuccessPredictorConfig({
    this.backend = SessionSuccessPredictorBackend.ruleBased,
    this.exportedModelAssetPath = 'ml/artifacts/session_success_model.json',
  });

  final SessionSuccessPredictorBackend backend;
  final String exportedModelAssetPath;
}

class SessionSuccessPredictorFactory {
  const SessionSuccessPredictorFactory();

  SessionSuccessPredictor create(SessionSuccessPredictorConfig config) {
    switch (config.backend) {
      case SessionSuccessPredictorBackend.ruleBased:
        return RuleBasedSessionSuccessPredictor();
      case SessionSuccessPredictorBackend.exportedJsonLogisticRegression:
        throw StateError(
          'Exported JSON predictors must be loaded with createAsync().',
        );
    }
  }

  Future<SessionSuccessPredictor> createAsync(
    SessionSuccessPredictorConfig config,
  ) async {
    switch (config.backend) {
      case SessionSuccessPredictorBackend.ruleBased:
        return RuleBasedSessionSuccessPredictor();
      case SessionSuccessPredictorBackend.exportedJsonLogisticRegression:
        return ExportedJsonLogisticRegressionSessionSuccessPredictor.fromAsset(
          artifactAssetPath: config.exportedModelAssetPath,
        );
    }
  }
}
