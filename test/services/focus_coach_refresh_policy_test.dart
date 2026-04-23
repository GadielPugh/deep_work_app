import 'package:flutter_test/flutter_test.dart';

import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/services/analytics/focus_coach_refresh_policy.dart';

void main() {
  const policy = FocusCoachRefreshPolicy();

  group('FocusCoachRefreshPolicy', () {
    test('recompute can happen without replacing the visible coach', () {
      final currentVisible = policy.createVisibleState(
        message: _message(
          title: 'This looks like a good time for Coding.',
          body: 'A short session could work well right now.',
        ),
        shownAt: DateTime(2026, 4, 17, 11),
      );

      final shouldRecompute = policy.shouldRecompute(
        trigger: FocusCoachRefreshTrigger.sessionDataChanged,
        lastComputedAt: DateTime(2026, 4, 17, 11),
        now: DateTime(2026, 4, 17, 11, 20),
      );
      final decision = policy.decideReplacement(
        currentVisible: currentVisible,
        candidate: _message(
          title: 'Coding still looks like a good fit.',
          body: 'You could keep this one short and focused.',
        ),
        now: DateTime(2026, 4, 17, 11, 20),
      );

      expect(shouldRecompute, isTrue);
      expect(decision.shouldReplaceVisible, isFalse);
    });

    test('same signature coach does not replace visible coach', () {
      final currentVisible = policy.createVisibleState(
        message: _message(),
        shownAt: DateTime(2026, 4, 17, 11),
      );

      final decision = policy.decideReplacement(
        currentVisible: currentVisible,
        candidate: _message(
          title: 'Coding is still a good option.',
          body: 'This could still be a good short session.',
          reasonLine: 'Nothing major has changed.',
        ),
        now: DateTime(2026, 4, 17, 11, 25),
      );

      expect(decision.isMeaningfulChange, isFalse);
      expect(decision.shouldReplaceVisible, isFalse);
    });

    test('category change replaces visible coach immediately', () {
      final currentVisible = policy.createVisibleState(
        message: _message(recommendedCategory: 'Coding'),
        shownAt: DateTime(2026, 4, 17, 11),
      );

      final decision = policy.decideReplacement(
        currentVisible: currentVisible,
        candidate: _message(
          title: 'This looks like a good time for Writing.',
          actionText: 'Try 25 min of Writing',
          recommendedCategory: 'Writing',
        ),
        now: DateTime(2026, 4, 17, 11, 10),
      );

      expect(decision.isStrongChange, isTrue);
      expect(decision.shouldReplaceVisible, isTrue);
    });

    test('message type change replaces visible coach immediately', () {
      final currentVisible = policy.createVisibleState(
        message: _message(type: FocusCoachMessageType.positive),
        shownAt: DateTime(2026, 4, 17, 11),
      );

      final decision = policy.decideReplacement(
        currentVisible: currentVisible,
        candidate: _message(
          type: FocusCoachMessageType.warning,
          confidenceLabel: 'Keep it simple',
        ),
        now: DateTime(2026, 4, 17, 11, 10),
      );

      expect(decision.isStrongChange, isTrue);
      expect(decision.shouldReplaceVisible, isTrue);
    });

    test('time block change replaces visible coach immediately', () {
      final currentVisible = policy.createVisibleState(
        message: _message(),
        shownAt: DateTime(2026, 4, 17, 10, 30),
      );

      final decision = policy.decideReplacement(
        currentVisible: currentVisible,
        candidate: _message(),
        now: DateTime(2026, 4, 17, 12, 5),
      );

      expect(decision.isStrongChange, isTrue);
      expect(decision.shouldReplaceVisible, isTrue);
    });

    test('weak internal changes do not replace visible coach', () {
      final currentVisible = policy.createVisibleState(
        message: _message(
          body: 'A short session could work well right now.',
          reasonLine: 'You have been steady lately.',
        ),
        shownAt: DateTime(2026, 4, 17, 11),
      );

      final decision = policy.decideReplacement(
        currentVisible: currentVisible,
        candidate: _message(
          body: 'This still looks okay for a short session.',
          reasonLine: 'You have stayed fairly steady.',
        ),
        now: DateTime(2026, 4, 17, 11, 12),
      );

      expect(decision.shouldReplaceVisible, isFalse);
      expect(decision.isMeaningfulChange, isFalse);
    });

    test('cooldown prevents unnecessary churn for minor changes', () {
      final currentVisible = policy.createVisibleState(
        message: _message(confidenceLabel: 'A good next step'),
        shownAt: DateTime(2026, 4, 17, 11),
      );

      final decision = policy.decideReplacement(
        currentVisible: currentVisible,
        candidate: _message(confidenceLabel: 'Best next step'),
        now: DateTime(2026, 4, 17, 11, 20),
      );

      expect(decision.isStrongChange, isFalse);
      expect(decision.isMeaningfulChange, isTrue);
      expect(decision.shouldReplaceVisible, isFalse);
    });

    test('strong changes bypass cooldown', () {
      final currentVisible = policy.createVisibleState(
        message: _message(
          type: FocusCoachMessageType.warning,
          confidenceLabel: 'Keep it simple',
          betterLaterHint: 'You may do better with this tomorrow morning.',
          betterLaterTimeBlock: 'morning',
        ),
        shownAt: DateTime(2026, 4, 17, 23),
      );

      final decision = policy.decideReplacement(
        currentVisible: currentVisible,
        candidate: _message(
          type: FocusCoachMessageType.warning,
          confidenceLabel: 'Keep it simple',
          betterLaterHint: null,
          betterLaterTimeBlock: null,
        ),
        now: DateTime(2026, 4, 17, 23, 10),
      );

      expect(decision.isStrongChange, isTrue);
      expect(decision.shouldReplaceVisible, isTrue);
    });

    test('time based trigger detects day and block changes', () {
      expect(
        policy.timeBasedTrigger(
          lastComputedAt: DateTime(2026, 4, 17, 23, 30),
          now: DateTime(2026, 4, 18, 0, 5),
        ),
        FocusCoachRefreshTrigger.dayChanged,
      );
      expect(
        policy.timeBasedTrigger(
          lastComputedAt: DateTime(2026, 4, 17, 11, 55),
          now: DateTime(2026, 4, 17, 12, 1),
        ),
        FocusCoachRefreshTrigger.timeBlockChanged,
      );
    });
  });
}

FocusCoachMessage _message({
  String title = 'This looks like a good time for Coding.',
  String body = 'A short session could work well right now.',
  String actionText = 'Try 25 min of Coding',
  String confidenceLabel = 'Try now',
  FocusCoachMessageType type = FocusCoachMessageType.positive,
  String? reasonLine,
  String? recommendedCategory = 'Coding',
  int? recommendedDurationMinutes = 25,
  String? betterLaterHint,
  String? betterLaterTimeBlock,
}) {
  return FocusCoachMessage(
    title: title,
    body: body,
    actionText: actionText,
    confidenceLabel: confidenceLabel,
    type: type,
    reasonLine: reasonLine,
    recommendedCategory: recommendedCategory,
    recommendedDurationMinutes: recommendedDurationMinutes,
    betterLaterHint: betterLaterHint,
    betterLaterTimeBlock: betterLaterTimeBlock,
  );
}
