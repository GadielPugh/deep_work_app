import 'dart:io';

import 'package:deep_work/services/feature_engineering/focus_feature_engineering.dart';
import 'package:deep_work/services/prediction/exported_json_logistic_regression_predictor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExportedJsonLogisticRegressionSessionSuccessPredictor', () {
    test('loads exported JSON format and scores a valid sample', () {
      final predictor =
          ExportedJsonLogisticRegressionSessionSuccessPredictor.fromJsonString(
            _mockArtifactJson,
          );

      final prediction = predictor.predictSuccessProbability(
        features: const FocusCandidateFeatures(
          hourOfDay: 9,
          dayOfWeek: DateTime.monday,
          isWeekend: false,
          sessionDurationMinutes: 25,
          intentionLength: 12,
          reflectionLength: 0,
          categoryId: 'Coding',
          timeSincePreviousSessionMinutes: 120,
          rolling7dSuccessRateForCategory: 0.7,
          hourSuccessRateForCategoryAtHour: 0.65,
          avgDurationMinutesForCategory: 25,
          avgDurationMinutesForCategorySuccess: 25,
          avgDurationMinutesForCategoryFailure: 20,
        ),
      );

      expect(prediction.successProbability, greaterThanOrEqualTo(0));
      expect(prediction.successProbability, lessThanOrEqualTo(1));
      expect(prediction.reasons, contains('model=test_logistic_regression'));
    });

    test('loads the chosen exported artifact and scores a valid sample', () {
      final artifact = File('ml/artifacts/session_success_model.json');
      expect(artifact.existsSync(), isTrue);

      final predictor =
          ExportedJsonLogisticRegressionSessionSuccessPredictor.fromJsonString(
            artifact.readAsStringSync(),
          );

      final prediction = predictor.predictSuccessProbability(
        features: const FocusCandidateFeatures(
          hourOfDay: 10,
          dayOfWeek: DateTime.tuesday,
          isWeekend: false,
          sessionDurationMinutes: 30,
          intentionLength: 0,
          reflectionLength: 0,
          categoryId: 'Coding',
          timeSincePreviousSessionMinutes: 90,
          rolling7dSuccessRateForCategory: 0.55,
          hourSuccessRateForCategoryAtHour: 0.55,
          avgDurationMinutesForCategory: 25,
          avgDurationMinutesForCategorySuccess: 25,
          avgDurationMinutesForCategoryFailure: 20,
        ),
      );

      expect(prediction.successProbability, inInclusiveRange(0, 1));
    });
  });
}

const _mockArtifactJson = '''
{
  "schema_version": 1,
  "model_id": "test_logistic_regression",
  "model_type": "logistic_regression",
  "parameters": {
    "intercept": -0.2,
    "coefficients": [
      {"feature": "duration_minutes", "coefficient": 0.15},
      {"feature": "recent_category_success_rate", "coefficient": 0.9},
      {"feature": "category=Coding", "coefficient": 0.4},
      {"feature": "time_block=morning", "coefficient": 0.25},
      {"feature": "day_of_week=monday", "coefficient": 0.1},
      {"feature": "duration_bucket=standard", "coefficient": 0.2},
      {"feature": "latest_coach_message_type=none", "coefficient": -0.05}
    ]
  },
  "feature_metadata": {
    "numeric_features": [
      {"name": "duration_minutes", "mean": 25.0, "scale": 10.0},
      {"name": "recent_category_success_rate", "mean": 0.5, "scale": 0.25}
    ],
    "categorical_features": [
      {"name": "category", "values": ["Coding", "Writing"], "encoding": "one_hot"},
      {"name": "time_block", "values": ["morning", "afternoon", "evening", "night"], "encoding": "one_hot"},
      {"name": "day_of_week", "values": ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"], "encoding": "one_hot"},
      {"name": "duration_bucket", "values": ["short", "standard", "long", "extended"], "encoding": "one_hot"},
      {"name": "latest_coach_message_type", "values": ["none", "positive", "neutral", "warning"], "encoding": "one_hot"}
    ]
  }
}
''';
