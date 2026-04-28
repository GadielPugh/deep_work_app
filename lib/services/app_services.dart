import 'package:deep_work/services/storage/local_session_storage_service.dart';
import 'package:deep_work/services/storage/local_coach_storage_service.dart';
import 'package:deep_work/services/storage/local_shadow_prediction_storage_service.dart';
import 'package:deep_work/services/storage/session_storage_service.dart';
import 'package:deep_work/services/ml/local_ml_export_service.dart';
import 'package:deep_work/services/personalization/local_personalization_profile_service.dart';
import 'package:deep_work/services/prediction/ml_shadow_mode_service.dart';
import 'package:deep_work/services/prediction/session_success_predictor.dart';
import 'package:deep_work/services/prediction/session_success_predictor_factory.dart';

/// Central place for app-wide services.
///
/// Swap [sessionStorage] for [FakeSessionStorageService] in tests.
final class AppServices {
  AppServices._();

  static SessionStorageService sessionStorage = LocalSessionStorageService();
  static LocalCoachStorageService coachStorage = LocalCoachStorageService();
  static LocalShadowPredictionStorageService shadowPredictionStorage =
      LocalShadowPredictionStorageService();
  static LocalPersonalizationProfileService personalizationProfileService =
      LocalPersonalizationProfileService();

  static SessionSuccessPredictorConfig sessionSuccessPredictorConfig =
      const SessionSuccessPredictorConfig();
  static const SessionSuccessPredictorFactory sessionSuccessPredictorFactory =
      SessionSuccessPredictorFactory();

  static SessionSuccessPredictor get sessionSuccessPredictor =>
      sessionSuccessPredictorFactory.create(sessionSuccessPredictorConfig);

  static LocalMlExportService get localMlExportService => LocalMlExportService(
    sessionStorage: sessionStorage,
    coachStorage: coachStorage,
    shadowPredictionStorage: shadowPredictionStorage,
  );

  /// Dev hook for exporting local history into ML-ready JSONL files.
  ///
  /// Intended to be called from a debugger, dev-only button, or temporary local
  /// tooling. This is deliberately not wired into the production UI.
  static Future<MlExportResult> exportMlTrainingDataForDebug() {
    return localMlExportService.exportToDefaultDirectory();
  }

  static MlShadowModeService mlShadowModeService = MlShadowModeService(
    predictorLoader: () => sessionSuccessPredictorFactory.createAsync(
      const SessionSuccessPredictorConfig(
        backend: SessionSuccessPredictorBackend.exportedJsonLogisticRegression,
      ),
    ),
    storage: shadowPredictionStorage,
  );
}
