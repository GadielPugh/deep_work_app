import 'dart:math' as math;

import 'package:deep_work/services/feature_engineering/focus_feature_engineering.dart';

import 'session_success_predictor.dart';

/// Rule-based baseline predictor (Phase 2).
///
/// This is intentionally simple, deterministic, and unit-test friendly.
class RuleBasedSessionSuccessPredictor implements SessionSuccessPredictor {
  RuleBasedSessionSuccessPredictor({
    this.minProbability = 0.05,
    this.maxProbability = 0.95,
  });

  final double minProbability;
  final double maxProbability;

  @override
  SessionSuccessPrediction predictSuccessProbability({
    required FocusCandidateFeatures features,
  }) {
    final rollingCatSuccess = features.rolling7dSuccessRateForCategory; // 0..1
    final hourSuccess = features.hourSuccessRateForCategoryAtHour; // 0..1

    // Blend category-level success with hour-specific success.
    double p = 0.45 * rollingCatSuccess + 0.55 * hourSuccess;

    final avgDur = features.avgDurationMinutesForCategory;
    if (avgDur > 0) {
      final durationFit = 1 - (features.sessionDurationMinutes - avgDur).abs() / avgDur;
      final clampedFit = durationFit.clamp(0.0, 1.0);

      // Adjust probability by duration fit, where `1.0` keeps p unchanged.
      p = p * (0.65 + 0.35 * clampedFit);
    } else {
      // Not enough history; keep p as-is.
    }

    // Penalize very short gaps (fatigue) and very large gaps (context switch).
    final timeSincePrev = features.timeSincePreviousSessionMinutes;
    if (timeSincePrev != null) {
      if (timeSincePrev < 15) {
        p -= 0.08;
      } else if (timeSincePrev > 24 * 60) {
        p -= 0.05;
      }
    }

    // Light regularization to avoid extreme 0/1 outputs on sparse data.
    p = math.max(minProbability, math.min(maxProbability, p));

    final reasons = <String>[
      'rolling category success=${(rollingCatSuccess * 100).round()}%',
      'hour success=${(hourSuccess * 100).round()}%',
    ];

    if (avgDur > 0) {
      final durationFit = 1 - (features.sessionDurationMinutes - avgDur).abs() / avgDur;
      reasons.add('duration fit=${durationFit.clamp(0.0, 1.0).toStringAsFixed(2)}');
    }
    if (timeSincePrev != null) {
      reasons.add('time since prev=${timeSincePrev.round()}m');
    }

    return SessionSuccessPrediction(
      successProbability: p,
      reasons: reasons,
    );
  }
}

// TODO(LiteRT):
// Implement `LiteRtSessionSuccessPredictor` in this folder (or similar) that
// adapts a native LiteRT model invocation to the `SessionSuccessPredictor`
// interface. The Insights UI/state would then swap implementations via a
// central factory (e.g., `AppServices`) without changing consumers.

