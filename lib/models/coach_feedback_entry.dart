import 'package:deep_work/models/focus_coach_message.dart';

class CoachFeedbackEntry {
  const CoachFeedbackEntry({
    required this.id,
    required this.createdAt,
    required this.coachMessageType,
    required this.confidenceLabel,
    required this.wasHelpful,
    this.recommendedCategory,
    this.recommendedDurationMinutes,
    this.optionalReason,
  });

  final String id;
  final DateTime createdAt;
  final FocusCoachMessageType coachMessageType;
  final String? recommendedCategory;
  final int? recommendedDurationMinutes;
  final String confidenceLabel;
  final bool wasHelpful;
  final String? optionalReason;

  factory CoachFeedbackEntry.fromMessage({
    required FocusCoachMessage message,
    required bool wasHelpful,
    String? optionalReason,
    DateTime? createdAt,
  }) {
    final created = createdAt ?? DateTime.now();
    return CoachFeedbackEntry(
      id: 'coach_feedback_${created.microsecondsSinceEpoch}',
      createdAt: created,
      coachMessageType: message.type,
      recommendedCategory: message.recommendedCategory,
      recommendedDurationMinutes: message.recommendedDurationMinutes,
      confidenceLabel: message.confidenceLabel,
      wasHelpful: wasHelpful,
      optionalReason: optionalReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'coachMessageType': coachMessageType.name,
      'recommendedCategory': recommendedCategory,
      'recommendedDurationMinutes': recommendedDurationMinutes,
      'confidenceLabel': confidenceLabel,
      'wasHelpful': wasHelpful,
      'optionalReason': optionalReason,
    };
  }

  factory CoachFeedbackEntry.fromJson(Map<String, dynamic> json) {
    return CoachFeedbackEntry(
      id: (json['id'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      coachMessageType: _messageTypeFromString(
        (json['coachMessageType'] ?? '').toString(),
      ),
      recommendedCategory: json['recommendedCategory']?.toString(),
      recommendedDurationMinutes: (json['recommendedDurationMinutes'] as num?)
          ?.toInt(),
      confidenceLabel: (json['confidenceLabel'] ?? '').toString(),
      wasHelpful: json['wasHelpful'] == true,
      optionalReason: json['optionalReason']?.toString(),
    );
  }

  static FocusCoachMessageType _messageTypeFromString(String raw) {
    for (final type in FocusCoachMessageType.values) {
      if (type.name == raw) return type;
    }
    return FocusCoachMessageType.neutral;
  }
}
