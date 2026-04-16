import 'package:deep_work/models/analytics/predictor_evaluation_dtos.dart';
import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/services/feature_engineering/focus_feature_engineering.dart';

import 'session_success_predictor.dart';

class PredictorEvaluationService {
  PredictorEvaluationService({
    required this.featureEngineeringService,
    required this.successPredictor,
    this.rollingWindowDaysForBaselines = 7,
    this.classificationThreshold = 0.5,
    this.numCalibrationBuckets = 10,
  });

  final FocusFeatureEngineeringService featureEngineeringService;
  final SessionSuccessPredictor successPredictor;

  /// Rolling window used by naive baselines.
  final int rollingWindowDaysForBaselines;

  /// Probability threshold used for precision/recall/F1.
  final double classificationThreshold;

  /// Buckets for calibration reporting (fixed width buckets in [0..1]).
  final int numCalibrationBuckets;

  PredictorEvaluationSummaryDto evaluate({
    required List<Session> sessions,
    required List<FocusCategory> categories,
  }) {
    final sortedAsc = [...sessions]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final byCategoryIds = categories.map((c) => c.id).toSet();

    final ruleAccOverall = _BinaryClassificationAccumulator(
      classificationThreshold: classificationThreshold,
      numCalibrationBuckets: numCalibrationBuckets,
    );
    final baselineRollAccOverall = _BinaryClassificationAccumulator(
      classificationThreshold: classificationThreshold,
      numCalibrationBuckets: numCalibrationBuckets,
    );
    final baselineGlobalAccOverall = _BinaryClassificationAccumulator(
      classificationThreshold: classificationThreshold,
      numCalibrationBuckets: numCalibrationBuckets,
    );

    final ruleAccByCategory = <String, _BinaryClassificationAccumulator>{};
    final baselineRollAccByCategory = <String, _BinaryClassificationAccumulator>{};
    final baselineGlobalAccByCategory = <String, _BinaryClassificationAccumulator>{};

    for (final cId in byCategoryIds) {
      ruleAccByCategory[cId] = _BinaryClassificationAccumulator(
        classificationThreshold: classificationThreshold,
        numCalibrationBuckets: numCalibrationBuckets,
      );
      baselineRollAccByCategory[cId] = _BinaryClassificationAccumulator(
        classificationThreshold: classificationThreshold,
        numCalibrationBuckets: numCalibrationBuckets,
      );
      baselineGlobalAccByCategory[cId] = _BinaryClassificationAccumulator(
        classificationThreshold: classificationThreshold,
        numCalibrationBuckets: numCalibrationBuckets,
      );
    }

    // Chronological evaluation: for each session, only use prior sessions
    // to build features / compute baselines.
    for (var i = 0; i < sortedAsc.length; i++) {
      final prior = sortedAsc.take(i).toList();
      final current = sortedAsc[i];
      final actual = current.outcome == CompletionStatus.yes ? 1 : 0;

      // ---- Rule-based predictor ----
      final candidateFeatures = featureEngineeringService.buildCandidateFeatures(
        now: current.dateTime,
        sessions: prior,
        categoryId: current.categoryId,
        sessionDurationMinutes: current.durationMinutes,
        intentionLength: current.intention.trim().length,
        reflectionLength: current.reflection?.trim().length ?? 0,
      );

      final rulePred = successPredictor.predictSuccessProbability(
        features: candidateFeatures,
      );

      ruleAccOverall.add(predictedProbability: rulePred.successProbability, actual: actual);

      final catId = current.categoryId;
      ruleAccByCategory.putIfAbsent(
        catId,
        () => _BinaryClassificationAccumulator(
          classificationThreshold: classificationThreshold,
          numCalibrationBuckets: numCalibrationBuckets,
        ),
      ).add(predictedProbability: rulePred.successProbability, actual: actual);

      // ---- Baseline 1: rolling category success rate only ----
      final baselineRollPred = _rollingCategorySuccessRateOnly(
        priorSessions: prior,
        candidateCategoryId: current.categoryId,
        candidateNow: current.dateTime,
        windowDays: rollingWindowDaysForBaselines,
      );

      baselineRollAccOverall.add(
        predictedProbability: baselineRollPred,
        actual: actual,
      );

      baselineRollAccByCategory.putIfAbsent(
        catId,
        () => _BinaryClassificationAccumulator(
          classificationThreshold: classificationThreshold,
          numCalibrationBuckets: numCalibrationBuckets,
        ),
      ).add(predictedProbability: baselineRollPred, actual: actual);

      // ---- Baseline 2: global success rate only ----
      final baselineGlobalPred = _globalSuccessRateOnly(
        priorSessions: prior,
      );

      baselineGlobalAccOverall.add(
        predictedProbability: baselineGlobalPred,
        actual: actual,
      );

      baselineGlobalAccByCategory.putIfAbsent(
        catId,
        () => _BinaryClassificationAccumulator(
          classificationThreshold: classificationThreshold,
          numCalibrationBuckets: numCalibrationBuckets,
        ),
      ).add(predictedProbability: baselineGlobalPred, actual: actual);
    }

    final ruleResult = PredictorEvaluationResultDto(
      predictorId: 'rule_based',
      overall: ruleAccOverall.toMetricsDto(),
      byCategory: _accMapToDto(ruleAccByCategory),
    );

    final baselineRollResult = PredictorEvaluationResultDto(
      predictorId: 'baseline_rolling_category',
      overall: baselineRollAccOverall.toMetricsDto(),
      byCategory: _accMapToDto(baselineRollAccByCategory),
    );

    final baselineGlobalResult = PredictorEvaluationResultDto(
      predictorId: 'baseline_global_success',
      overall: baselineGlobalAccOverall.toMetricsDto(),
      byCategory: _accMapToDto(baselineGlobalAccByCategory),
    );

    return PredictorEvaluationSummaryDto(
      ruleBased: ruleResult,
      baselineRollingCategoryOnly: baselineRollResult,
      baselineGlobalOnly: baselineGlobalResult,
    );
  }

  double _globalSuccessRateOnly({required List<Session> priorSessions}) {
    if (priorSessions.isEmpty) return 0.5;
    final total = priorSessions.length;
    final yes = priorSessions.where((s) => s.outcome == CompletionStatus.yes).length;
    return yes / total;
  }

  double _rollingCategorySuccessRateOnly({
    required List<Session> priorSessions,
    required String candidateCategoryId,
    required DateTime candidateNow,
    required int windowDays,
  }) {
    if (priorSessions.isEmpty) return 0.5;

    final localNow = candidateNow.toLocal();
    final windowStart = localNow.subtract(Duration(days: windowDays));

    final inWindow = priorSessions.where((s) {
      final local = s.dateTime.toLocal();
      return s.categoryId == candidateCategoryId &&
          local.isAfter(windowStart) &&
          local.isBefore(localNow);
    }).toList();

    if (inWindow.isEmpty) return 0.5;

    final total = inWindow.length;
    final yes = inWindow.where((s) => s.outcome == CompletionStatus.yes).length;
    return yes / total;
  }

  Map<String, BinaryClassificationMetricsDto> _accMapToDto(
    Map<String, _BinaryClassificationAccumulator> map,
  ) {
    final out = <String, BinaryClassificationMetricsDto>{};
    map.forEach((k, v) {
      out[k] = v.toMetricsDto();
    });
    return out;
  }
}

class _BinaryClassificationAccumulator {
  _BinaryClassificationAccumulator({
    required this.classificationThreshold,
    required this.numCalibrationBuckets,
  });

  final double classificationThreshold;
  final int numCalibrationBuckets;

  int _total = 0;
  int _tp = 0;
  int _fp = 0;
  int _tn = 0;
  int _fn = 0;
  double _brierSum = 0.0;

  final List<_CalibrationBucketAccumulator> _buckets = [];

  void _ensureBuckets() {
    if (_buckets.isNotEmpty) return;
    for (var i = 0; i < numCalibrationBuckets; i++) {
      _buckets.add(_CalibrationBucketAccumulator());
    }
  }

  void add({required double predictedProbability, required int actual}) {
    _ensureBuckets();

    final p = predictedProbability.clamp(0.0, 1.0);
    _total++;
    _brierSum += (p - actual) * (p - actual);

    final predictedPositive = p >= classificationThreshold;
    if (actual == 1) {
      if (predictedPositive) {
        _tp++;
      } else {
        _fn++;
      }
    } else {
      if (predictedPositive) {
        _fp++;
      } else {
        _tn++;
      }
    }

    final bucketIndex = (p * numCalibrationBuckets).floor().clamp(0, numCalibrationBuckets - 1);
    _buckets[bucketIndex].add(p: p, actual: actual);
  }

  BinaryClassificationMetricsDto toMetricsDto() {
    _ensureBuckets();
    final acc = _total == 0 ? 0.0 : (_tp + _tn) / _total;

    final precision = (_tp + _fp) == 0 ? 0.0 : _tp / (_tp + _fp);
    final recall = (_tp + _fn) == 0 ? 0.0 : _tp / (_tp + _fn);
    final f1 = (precision + recall) == 0 ? 0.0 : 2 * precision * recall / (precision + recall);

    final brier = _total == 0 ? 0.0 : _brierSum / _total;

    final bucketDtos = <CalibrationBucketDto>[];
    for (var i = 0; i < numCalibrationBuckets; i++) {
      final b = _buckets[i];
      final start = i / numCalibrationBuckets;
      final end = (i + 1) / numCalibrationBuckets;
      bucketDtos.add(
        CalibrationBucketDto(
          rangeStart: start,
          rangeEnd: end,
          count: b.count,
          avgPredictedProbability: b.count == 0 ? 0.0 : b.sumPredicted / b.count,
          observedSuccessRate: b.count == 0 ? 0.0 : b.sumActual / b.count,
        ),
      );
    }

    return BinaryClassificationMetricsDto(
      totalCount: _total,
      accuracy: acc,
      precision: precision,
      recall: recall,
      f1: f1,
      brierScore: brier,
      calibrationBuckets: bucketDtos,
    );
  }
}

class _CalibrationBucketAccumulator {
  int count = 0;
  double sumPredicted = 0.0;
  int sumActual = 0;

  void add({required double p, required int actual}) {
    count++;
    sumPredicted += p;
    sumActual += actual;
  }
}

