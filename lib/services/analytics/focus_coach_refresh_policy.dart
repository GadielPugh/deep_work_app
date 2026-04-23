import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/services/analytics/focus_coach_message_service.dart';

enum FocusCoachRefreshTrigger {
  pageOpened,
  appResumed,
  sessionDataChanged,
  timeBlockChanged,
  dayChanged,
}

class FocusCoachVisibleState {
  const FocusCoachVisibleState({required this.message, required this.shownAt});

  final FocusCoachMessage message;
  final DateTime shownAt;
}

class FocusCoachMeaningSignature {
  const FocusCoachMeaningSignature({
    required this.messageType,
    required this.recommendedCategory,
    required this.durationBucket,
    required this.currentTimeBlock,
    required this.betterLaterKey,
    required this.confidenceLabel,
    required this.isActionable,
  });

  final FocusCoachMessageType messageType;
  final String recommendedCategory;
  final int? durationBucket;
  final String currentTimeBlock;
  final String betterLaterKey;
  final String confidenceLabel;
  final bool isActionable;

  String get key => [
    messageType.name,
    recommendedCategory,
    durationBucket?.toString() ?? 'none',
    currentTimeBlock,
    betterLaterKey,
    confidenceLabel,
    isActionable ? 'actionable' : 'fallback',
  ].join('|');
}

class FocusCoachRefreshDecision {
  const FocusCoachRefreshDecision({
    required this.shouldReplaceVisible,
    required this.isMeaningfulChange,
    required this.isStrongChange,
    required this.currentSignature,
    required this.candidateSignature,
  });

  final bool shouldReplaceVisible;
  final bool isMeaningfulChange;
  final bool isStrongChange;
  final FocusCoachMeaningSignature? currentSignature;
  final FocusCoachMeaningSignature candidateSignature;
}

class FocusCoachRefreshPolicy {
  const FocusCoachRefreshPolicy({
    this.normalCooldown = const Duration(minutes: 45),
    FocusCoachMessageService coachMessageService =
        const FocusCoachMessageService(),
  }) : _coachMessageService = coachMessageService;

  final Duration normalCooldown;
  final FocusCoachMessageService _coachMessageService;

  bool shouldRecompute({
    required FocusCoachRefreshTrigger trigger,
    required DateTime now,
    DateTime? lastComputedAt,
  }) {
    switch (trigger) {
      case FocusCoachRefreshTrigger.pageOpened:
      case FocusCoachRefreshTrigger.appResumed:
      case FocusCoachRefreshTrigger.sessionDataChanged:
      case FocusCoachRefreshTrigger.timeBlockChanged:
      case FocusCoachRefreshTrigger.dayChanged:
        return true;
    }
  }

  FocusCoachRefreshTrigger? timeBasedTrigger({
    required DateTime? lastComputedAt,
    required DateTime now,
  }) {
    if (lastComputedAt == null) return null;
    if (!_isSameDay(lastComputedAt, now)) {
      return FocusCoachRefreshTrigger.dayChanged;
    }
    if (timeBlockFor(now) != timeBlockFor(lastComputedAt)) {
      return FocusCoachRefreshTrigger.timeBlockChanged;
    }
    return null;
  }

  DateTime nextRefreshBoundary(DateTime now) {
    final localNow = now.toLocal();
    DateTime? nextBoundary;

    for (final dayOffset in [0, 1]) {
      final baseDay = DateTime(
        localNow.year,
        localNow.month,
        localNow.day + dayOffset,
      );
      for (final hour in const [0, 5, 12, 17, 22]) {
        final candidate = DateTime(
          baseDay.year,
          baseDay.month,
          baseDay.day,
          hour,
        );
        if (!candidate.isAfter(localNow)) continue;
        if (nextBoundary == null || candidate.isBefore(nextBoundary)) {
          nextBoundary = candidate;
        }
      }
    }

    return nextBoundary ?? localNow.add(const Duration(hours: 1));
  }

  FocusCoachVisibleState createVisibleState({
    required FocusCoachMessage message,
    required DateTime shownAt,
  }) {
    return FocusCoachVisibleState(message: message, shownAt: shownAt);
  }

  FocusCoachMeaningSignature buildSignature({
    required FocusCoachMessage message,
    required DateTime now,
  }) {
    return FocusCoachMeaningSignature(
      messageType: message.type,
      recommendedCategory: (message.recommendedCategory ?? '')
          .trim()
          .toLowerCase(),
      durationBucket: message.recommendedDurationMinutes,
      currentTimeBlock: timeBlockFor(now),
      betterLaterKey: _betterLaterKey(message),
      confidenceLabel: message.confidenceLabel,
      isActionable: message.isActionable,
    );
  }

  FocusCoachRefreshDecision decideReplacement({
    FocusCoachVisibleState? currentVisible,
    required FocusCoachMessage candidate,
    required DateTime now,
  }) {
    final candidateSignature = buildSignature(message: candidate, now: now);
    if (currentVisible == null) {
      return FocusCoachRefreshDecision(
        shouldReplaceVisible: true,
        isMeaningfulChange: true,
        isStrongChange: true,
        currentSignature: null,
        candidateSignature: candidateSignature,
      );
    }

    final currentSignature = buildSignature(
      message: currentVisible.message,
      now: currentVisible.shownAt,
    );

    if (currentSignature.key == candidateSignature.key) {
      return FocusCoachRefreshDecision(
        shouldReplaceVisible: false,
        isMeaningfulChange: false,
        isStrongChange: false,
        currentSignature: currentSignature,
        candidateSignature: candidateSignature,
      );
    }

    final isStrongChange = _isStrongChange(
      current: currentSignature,
      candidate: candidateSignature,
    );
    if (isStrongChange) {
      return FocusCoachRefreshDecision(
        shouldReplaceVisible: true,
        isMeaningfulChange: true,
        isStrongChange: true,
        currentSignature: currentSignature,
        candidateSignature: candidateSignature,
      );
    }

    final cooldownElapsed = !now.isBefore(
      currentVisible.shownAt.add(normalCooldown),
    );
    return FocusCoachRefreshDecision(
      shouldReplaceVisible: cooldownElapsed,
      isMeaningfulChange: true,
      isStrongChange: false,
      currentSignature: currentSignature,
      candidateSignature: candidateSignature,
    );
  }

  String timeBlockFor(DateTime time) {
    return _coachMessageService.timeBlockForHour(time.toLocal().hour);
  }

  bool _isStrongChange({
    required FocusCoachMeaningSignature current,
    required FocusCoachMeaningSignature candidate,
  }) {
    if (current.recommendedCategory != candidate.recommendedCategory) {
      return true;
    }
    if (current.messageType != candidate.messageType) {
      return true;
    }
    if (current.currentTimeBlock != candidate.currentTimeBlock) {
      return true;
    }
    if (current.isActionable != candidate.isActionable) {
      return true;
    }
    if (current.betterLaterKey != candidate.betterLaterKey &&
        (current.betterLaterKey != 'none' ||
            candidate.betterLaterKey != 'none')) {
      return true;
    }
    return false;
  }

  String _betterLaterKey(FocusCoachMessage message) {
    final timeBlock = message.betterLaterTimeBlock?.trim().toLowerCase();
    if (timeBlock != null && timeBlock.isNotEmpty) return timeBlock;
    return message.betterLaterHint == null ? 'none' : 'present';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final left = a.toLocal();
    final right = b.toLocal();
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}
