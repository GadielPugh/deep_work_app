import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/models/ml/shadow_prediction_log_entry.dart';
import 'package:deep_work/services/feature_engineering/focus_feature_engineering.dart';
import 'package:deep_work/services/storage/local_shadow_prediction_storage_service.dart';
import 'package:deep_work/session_model.dart';

import 'session_success_predictor.dart';

class MlShadowModeService {
  MlShadowModeService({
    required Future<SessionSuccessPredictor> Function() predictorLoader,
    required LocalShadowPredictionStorageService storage,
    FocusFeatureEngineeringService? featureEngineeringService,
  }) : _predictorLoader = predictorLoader,
       _storage = storage,
       _featureEngineeringService =
           featureEngineeringService ?? FocusFeatureEngineeringService();

  final Future<SessionSuccessPredictor> Function() _predictorLoader;
  final LocalShadowPredictionStorageService _storage;
  final FocusFeatureEngineeringService _featureEngineeringService;

  SessionSuccessPredictor? _predictor;

  Future<double?> recordCoachDecision({
    required FocusCoachMessage message,
    required DateTime now,
    required List<Session> sessions,
  }) async {
    try {
      final predictor = await _loadPredictor();
      final features = _featureEngineeringService.buildCandidateFeatures(
        now: now,
        sessions: sessions,
        categoryId: message.recommendedCategory ?? 'unknown',
        sessionDurationMinutes: message.recommendedDurationMinutes ?? 25,
      );
      final prediction = predictor.predictSuccessProbability(
        features: features,
      );
      final entry = ShadowPredictionLogEntry.fromCoachDecision(
        message: message,
        mlSuccessProbability: prediction.successProbability,
        createdAt: now,
      );
      await _storage.saveEntry(entry);
      return prediction.successProbability;
    } catch (_) {
      return null;
    }
  }

  Future<void> markMostRecentPendingOutcome({
    required DateTime resolvedAt,
    required CompletionStatus outcome,
    String? completedSessionCategoryId,
  }) async {
    await _storage.markMostRecentPendingOutcome(
      resolvedAt: resolvedAt,
      completedSessionCategoryId: completedSessionCategoryId,
      laterSessionSucceeded: outcome == CompletionStatus.yes,
    );
  }

  Future<SessionSuccessPredictor> _loadPredictor() async {
    final cached = _predictor;
    if (cached != null) return cached;

    final loaded = await _predictorLoader();
    _predictor = loaded;
    return loaded;
  }
}
