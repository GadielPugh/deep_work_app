import 'package:deep_work/models/focus_coach_message.dart';

class ShadowPredictionLogEntry {
  const ShadowPredictionLogEntry({
    required this.id,
    required this.createdAt,
    required this.heuristicMessageType,
    required this.mlSuccessProbability,
    this.heuristicRecommendationCategory,
    this.heuristicRecommendedDurationMinutes,
    this.resolvedAt,
    this.completedSessionCategoryId,
    this.laterSessionSucceeded,
  });

  final String id;
  final DateTime createdAt;
  final FocusCoachMessageType heuristicMessageType;
  final String? heuristicRecommendationCategory;
  final int? heuristicRecommendedDurationMinutes;
  final double mlSuccessProbability;
  final DateTime? resolvedAt;
  final String? completedSessionCategoryId;
  final bool? laterSessionSucceeded;

  factory ShadowPredictionLogEntry.fromCoachDecision({
    required FocusCoachMessage message,
    required double mlSuccessProbability,
    DateTime? createdAt,
  }) {
    final created = createdAt ?? DateTime.now();
    return ShadowPredictionLogEntry(
      id: 'ml_shadow_${created.microsecondsSinceEpoch}',
      createdAt: created,
      heuristicMessageType: message.type,
      heuristicRecommendationCategory: message.recommendedCategory,
      heuristicRecommendedDurationMinutes: message.recommendedDurationMinutes,
      mlSuccessProbability: mlSuccessProbability.clamp(0.0, 1.0),
    );
  }

  ShadowPredictionLogEntry copyWithOutcome({
    required DateTime resolvedAt,
    required bool laterSessionSucceeded,
    String? completedSessionCategoryId,
  }) {
    return ShadowPredictionLogEntry(
      id: id,
      createdAt: createdAt,
      heuristicMessageType: heuristicMessageType,
      heuristicRecommendationCategory: heuristicRecommendationCategory,
      heuristicRecommendedDurationMinutes: heuristicRecommendedDurationMinutes,
      mlSuccessProbability: mlSuccessProbability,
      resolvedAt: resolvedAt,
      completedSessionCategoryId: completedSessionCategoryId,
      laterSessionSucceeded: laterSessionSucceeded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'heuristicMessageType': heuristicMessageType.name,
      'heuristicRecommendationCategory': heuristicRecommendationCategory,
      'heuristicRecommendedDurationMinutes':
          heuristicRecommendedDurationMinutes,
      'mlSuccessProbability': mlSuccessProbability,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'completedSessionCategoryId': completedSessionCategoryId,
      'laterSessionSucceeded': laterSessionSucceeded,
    };
  }

  factory ShadowPredictionLogEntry.fromJson(Map<String, dynamic> json) {
    return ShadowPredictionLogEntry(
      id: (json['id'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      heuristicMessageType: _messageTypeFromString(
        (json['heuristicMessageType'] ?? '').toString(),
      ),
      heuristicRecommendationCategory: json['heuristicRecommendationCategory']
          ?.toString(),
      heuristicRecommendedDurationMinutes:
          (json['heuristicRecommendedDurationMinutes'] as num?)?.toInt(),
      mlSuccessProbability:
          (json['mlSuccessProbability'] as num?)?.toDouble().clamp(0.0, 1.0) ??
          0.0,
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.tryParse(json['resolvedAt'].toString()),
      completedSessionCategoryId: json['completedSessionCategoryId']
          ?.toString(),
      laterSessionSucceeded: json['laterSessionSucceeded'] as bool?,
    );
  }

  static FocusCoachMessageType _messageTypeFromString(String raw) {
    for (final type in FocusCoachMessageType.values) {
      if (type.name == raw) return type;
    }
    return FocusCoachMessageType.neutral;
  }
}
