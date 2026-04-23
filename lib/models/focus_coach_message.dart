enum FocusCoachMessageType {
  warning,
  suggestion,
  positive,
  neutral,
  notEnoughData,
}

class FocusCoachMessage {
  const FocusCoachMessage({
    required this.title,
    required this.body,
    required this.actionText,
    required this.confidenceLabel,
    required this.type,
    this.reasonLine,
    this.recommendedCategory,
    this.recommendedDurationMinutes,
    this.betterLaterHint,
    this.betterLaterTimeBlock,
  });

  final String title;
  final String body;
  final String actionText;
  final String confidenceLabel;
  final String? reasonLine;
  final String? recommendedCategory;
  final int? recommendedDurationMinutes;
  final String? betterLaterHint;
  final String? betterLaterTimeBlock;
  final FocusCoachMessageType type;

  bool get isActionable =>
      type == FocusCoachMessageType.warning ||
      type == FocusCoachMessageType.suggestion ||
      type == FocusCoachMessageType.positive;
}
