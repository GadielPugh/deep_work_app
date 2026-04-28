import 'dart:convert';
import 'dart:math' as math;

import 'package:deep_work/services/feature_engineering/focus_feature_engineering.dart';
import 'package:flutter/services.dart';

import 'session_success_predictor.dart';

class ExportedJsonLogisticRegressionSessionSuccessPredictor
    implements SessionSuccessPredictor {
  const ExportedJsonLogisticRegressionSessionSuccessPredictor._({
    required _JsonLogisticRegressionModel model,
    this.artifactAssetPath,
  }) : _model = model;

  factory ExportedJsonLogisticRegressionSessionSuccessPredictor.fromJsonString(
    String source, {
    String? artifactAssetPath,
  }) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Model artifact must be a JSON object.');
    }
    return ExportedJsonLogisticRegressionSessionSuccessPredictor._(
      model: _JsonLogisticRegressionModel.fromJson(decoded),
      artifactAssetPath: artifactAssetPath,
    );
  }

  factory ExportedJsonLogisticRegressionSessionSuccessPredictor.fromJsonMap(
    Map<String, dynamic> json, {
    String? artifactAssetPath,
  }) {
    return ExportedJsonLogisticRegressionSessionSuccessPredictor._(
      model: _JsonLogisticRegressionModel.fromJson(json),
      artifactAssetPath: artifactAssetPath,
    );
  }

  static Future<ExportedJsonLogisticRegressionSessionSuccessPredictor>
  fromAsset({required String artifactAssetPath, AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(artifactAssetPath);
    return ExportedJsonLogisticRegressionSessionSuccessPredictor.fromJsonString(
      source,
      artifactAssetPath: artifactAssetPath,
    );
  }

  final _JsonLogisticRegressionModel _model;
  final String? artifactAssetPath;

  @override
  SessionSuccessPrediction predictSuccessProbability({
    required FocusCandidateFeatures features,
  }) {
    final probability = _model.predict(features);
    return SessionSuccessPrediction(
      successProbability: probability,
      reasons: [
        'model=${_model.modelId}',
        if (artifactAssetPath != null) 'artifact=$artifactAssetPath',
      ],
    );
  }
}

class _JsonLogisticRegressionModel {
  const _JsonLogisticRegressionModel({
    required this.modelId,
    required this.intercept,
    required this.coefficients,
    required this.numericFeatures,
    required this.categoricalValues,
  });

  factory _JsonLogisticRegressionModel.fromJson(Map<String, dynamic> json) {
    final modelType = json['model_type'];
    if (modelType != 'logistic_regression') {
      throw FormatException('Unsupported model_type: $modelType');
    }

    final parameters = _readMap(json['parameters'], 'parameters');
    final coefficientRows = _readList(
      parameters['coefficients'],
      'parameters.coefficients',
    );
    final coefficients = coefficientRows.map((row) {
      final map = _readMap(row, 'coefficient');
      return _Coefficient(
        feature: _readString(map['feature'], 'coefficient.feature'),
        value: _readDouble(map['coefficient'], 'coefficient.coefficient'),
      );
    }).toList();

    final featureMetadata = _readMap(
      json['feature_metadata'],
      'feature_metadata',
    );
    final numericRows = _readList(
      featureMetadata['numeric_features'],
      'feature_metadata.numeric_features',
    );
    final numericFeatures = <String, _NumericFeature>{};
    for (final row in numericRows) {
      final map = _readMap(row, 'numeric_feature');
      final name = _readString(map['name'], 'numeric_feature.name');
      numericFeatures[name] = _NumericFeature(
        mean: _readDouble(map['mean'], 'numeric_feature.mean'),
        scale: _readDouble(map['scale'], 'numeric_feature.scale'),
      );
    }

    final categoricalRows = _readList(
      featureMetadata['categorical_features'],
      'feature_metadata.categorical_features',
    );
    final categoricalValues = <String, List<String>>{};
    for (final row in categoricalRows) {
      final map = _readMap(row, 'categorical_feature');
      final name = _readString(map['name'], 'categorical_feature.name');
      final values = _readList(
        map['values'],
        'categorical_feature.values',
      ).map((value) => value.toString()).toList();
      categoricalValues[name] = values;
    }

    return _JsonLogisticRegressionModel(
      modelId:
          json['model_id']?.toString() ?? 'exported_json_logistic_regression',
      intercept: _readDouble(parameters['intercept'], 'parameters.intercept'),
      coefficients: coefficients,
      numericFeatures: numericFeatures,
      categoricalValues: categoricalValues,
    );
  }

  final String modelId;
  final double intercept;
  final List<_Coefficient> coefficients;
  final Map<String, _NumericFeature> numericFeatures;
  final Map<String, List<String>> categoricalValues;

  double predict(FocusCandidateFeatures features) {
    final rawFeatures = _rawFeatureValues(features);

    var score = intercept;
    for (final coefficient in coefficients) {
      score +=
          coefficient.value *
          _transformedValue(
            featureName: coefficient.feature,
            rawFeatures: rawFeatures,
          );
    }

    return _sigmoid(score).clamp(0.0, 1.0);
  }

  Map<String, Object> _rawFeatureValues(FocusCandidateFeatures features) {
    return {
      'category': features.categoryId,
      'time_block': _timeBlock(features.hourOfDay),
      'day_of_week': _dayOfWeek(features.dayOfWeek),
      'duration_bucket': _durationBucket(features.sessionDurationMinutes),
      'latest_coach_message_type': 'none',
      'latest_coach_confidence_label': 'none',
      'duration_minutes': features.sessionDurationMinutes.toDouble(),
      'recent_success_rate': features.rolling7dSuccessRateForCategory,
      'recent_session_count': 0.0,
      'recent_category_success_rate': features.rolling7dSuccessRateForCategory,
      'recent_category_session_count': 0.0,
      'current_streak': 0.0,
      'current_success_streak': 0.0,
      'current_failure_streak': 0.0,
      'recent_coach_helpful_rate': 0.5,
      'recent_coach_feedback_count': 0.0,
      'coach_recommended_same_category': 0.0,
      'coach_recommended_duration_delta_minutes': 0.0,
      'recent_tag_flow': 0.0,
      'recent_tag_quiet': 0.0,
      'recent_tag_low_energy': 0.0,
      'recent_tag_phone': 0.0,
      'recent_tag_interruption': 0.0,
      'recent_tag_unclear': 0.0,
    };
  }

  double _transformedValue({
    required String featureName,
    required Map<String, Object> rawFeatures,
  }) {
    final separatorIndex = featureName.indexOf('=');
    if (separatorIndex != -1) {
      final name = featureName.substring(0, separatorIndex);
      final expected = featureName.substring(separatorIndex + 1);
      final rawValue = rawFeatures[name]?.toString();
      if (rawValue == null) return 0.0;
      return rawValue.toLowerCase() == expected.toLowerCase() ? 1.0 : 0.0;
    }

    final value = rawFeatures[featureName];
    final numericValue = value is num ? value.toDouble() : 0.0;
    final metadata = numericFeatures[featureName];
    if (metadata == null) return numericValue;

    final scale = metadata.scale.abs() < 1e-9 ? 1.0 : metadata.scale;
    return (numericValue - metadata.mean) / scale;
  }

  double _sigmoid(double value) {
    if (value >= 0) {
      final z = math.exp(-value);
      return 1.0 / (1.0 + z);
    }
    final z = math.exp(value);
    return z / (1.0 + z);
  }

  String _timeBlock(int hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  String _dayOfWeek(int dayOfWeek) {
    const names = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final index = (dayOfWeek - 1).clamp(0, names.length - 1);
    return names[index];
  }

  String _durationBucket(int durationMinutes) {
    if (durationMinutes <= 15) return 'short';
    if (durationMinutes <= 30) return 'standard';
    if (durationMinutes <= 45) return 'long';
    return 'extended';
  }
}

class _Coefficient {
  const _Coefficient({required this.feature, required this.value});

  final String feature;
  final double value;
}

class _NumericFeature {
  const _NumericFeature({required this.mean, required this.scale});

  final double mean;
  final double scale;
}

Map<String, dynamic> _readMap(Object? value, String path) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$path must be a JSON object.');
}

List<Object?> _readList(Object? value, String path) {
  if (value is List) return value.cast<Object?>();
  throw FormatException('$path must be a JSON list.');
}

String _readString(Object? value, String path) {
  if (value is String) return value;
  throw FormatException('$path must be a string.');
}

double _readDouble(Object? value, String path) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('$path must be a number.');
}
