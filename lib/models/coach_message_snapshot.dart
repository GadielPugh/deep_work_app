import 'dart:convert';

import 'package:deep_work/models/focus_coach_message.dart';

class CoachMessageSnapshot {
  const CoachMessageSnapshot({
    required this.createdAt,
    required this.title,
    required this.body,
    required this.actionText,
    required this.coachMessageType,
    required this.confidenceLabel,
    this.recommendedCategory,
    this.recommendedDurationMinutes,
    this.betterLaterHint,
  });

  final DateTime createdAt;
  final String title;
  final String body;
  final String actionText;
  final FocusCoachMessageType coachMessageType;
  final String confidenceLabel;
  final String? recommendedCategory;
  final int? recommendedDurationMinutes;
  final String? betterLaterHint;

  factory CoachMessageSnapshot.fromMessage(
    FocusCoachMessage message, {
    DateTime? createdAt,
  }) {
    return CoachMessageSnapshot(
      createdAt: createdAt ?? DateTime.now(),
      title: message.title,
      body: message.body,
      actionText: message.actionText,
      coachMessageType: message.type,
      confidenceLabel: message.confidenceLabel,
      recommendedCategory: message.recommendedCategory,
      recommendedDurationMinutes: message.recommendedDurationMinutes,
      betterLaterHint: message.betterLaterHint,
    );
  }

  String get signature => jsonEncode({
    'title': title,
    'body': body,
    'actionText': actionText,
    'coachMessageType': coachMessageType.name,
    'confidenceLabel': confidenceLabel,
    'recommendedCategory': recommendedCategory,
    'recommendedDurationMinutes': recommendedDurationMinutes,
    'betterLaterHint': betterLaterHint,
  });

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'title': title,
      'body': body,
      'actionText': actionText,
      'coachMessageType': coachMessageType.name,
      'confidenceLabel': confidenceLabel,
      'recommendedCategory': recommendedCategory,
      'recommendedDurationMinutes': recommendedDurationMinutes,
      'betterLaterHint': betterLaterHint,
    };
  }

  factory CoachMessageSnapshot.fromJson(Map<String, dynamic> json) {
    return CoachMessageSnapshot(
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      actionText: (json['actionText'] ?? '').toString(),
      coachMessageType: _messageTypeFromString(
        (json['coachMessageType'] ?? '').toString(),
      ),
      confidenceLabel: (json['confidenceLabel'] ?? '').toString(),
      recommendedCategory: json['recommendedCategory']?.toString(),
      recommendedDurationMinutes: (json['recommendedDurationMinutes'] as num?)
          ?.toInt(),
      betterLaterHint: json['betterLaterHint']?.toString(),
    );
  }

  static FocusCoachMessageType _messageTypeFromString(String raw) {
    for (final type in FocusCoachMessageType.values) {
      if (type.name == raw) return type;
    }
    return FocusCoachMessageType.neutral;
  }
}
