import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/services/prediction/exported_json_logistic_regression_predictor.dart';
import 'package:deep_work/services/prediction/ml_shadow_mode_service.dart';
import 'package:deep_work/services/storage/local_shadow_prediction_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MlShadowModeService', () {
    test('scores and stores a shadow decision without UI involvement', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalShadowPredictionStorageService();
      final predictor =
          ExportedJsonLogisticRegressionSessionSuccessPredictor.fromJsonString(
            _mockArtifactJson,
          );
      final service = MlShadowModeService(
        predictorLoader: () async => predictor,
        storage: storage,
      );

      final probability = await service.recordCoachDecision(
        message: const FocusCoachMessage(
          title: 'Coach',
          body: 'Try Coding now.',
          actionText: 'Try 25 min of Coding',
          confidenceLabel: 'Try now',
          recommendedCategory: 'Coding',
          recommendedDurationMinutes: 25,
          type: FocusCoachMessageType.positive,
        ),
        now: DateTime(2026, 1, 1, 9),
        sessions: const [],
      );

      expect(probability, isNotNull);
      expect(probability!, inInclusiveRange(0, 1));

      var entries = await storage.getEntries();
      expect(entries, hasLength(1));
      expect(entries.single.heuristicRecommendationCategory, 'Coding');
      expect(entries.single.laterSessionSucceeded, isNull);

      await service.markMostRecentPendingOutcome(
        resolvedAt: DateTime(2026, 1, 1, 9, 25),
        outcome: CompletionStatus.yes,
        completedSessionCategoryId: 'coding',
      );

      entries = await storage.getEntries();
      expect(entries.single.laterSessionSucceeded, isTrue);
      expect(entries.single.completedSessionCategoryId, 'coding');
    });
  });
}

const _mockArtifactJson = '''
{
  "schema_version": 1,
  "model_id": "test_shadow_logistic_regression",
  "model_type": "logistic_regression",
  "parameters": {
    "intercept": -0.2,
    "coefficients": [
      {"feature": "recent_category_success_rate", "coefficient": 0.9},
      {"feature": "category=Coding", "coefficient": 0.4},
      {"feature": "time_block=morning", "coefficient": 0.25},
      {"feature": "duration_bucket=standard", "coefficient": 0.2}
    ]
  },
  "feature_metadata": {
    "numeric_features": [
      {"name": "recent_category_success_rate", "mean": 0.5, "scale": 0.25}
    ],
    "categorical_features": [
      {"name": "category", "values": ["Coding", "Writing"], "encoding": "one_hot"},
      {"name": "time_block", "values": ["morning", "afternoon", "evening", "night"], "encoding": "one_hot"},
      {"name": "duration_bucket", "values": ["short", "standard", "long", "extended"], "encoding": "one_hot"}
    ]
  }
}
''';
