import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deep_work/models/coach_feedback_entry.dart';
import 'package:deep_work/models/coach_message_snapshot.dart';
import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/services/storage/local_coach_storage_service.dart';

void main() {
  late LocalCoachStorageService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = LocalCoachStorageService();
  });

  test('saves coach feedback locally', () async {
    const message = FocusCoachMessage(
      title: 'This looks like a good time for Coding.',
      body: 'A short session could work well right now.',
      actionText: 'Try 25 min of Coding',
      confidenceLabel: 'Try now',
      type: FocusCoachMessageType.positive,
      recommendedCategory: 'Coding',
      recommendedDurationMinutes: 25,
    );

    final entry = CoachFeedbackEntry.fromMessage(
      message: message,
      wasHelpful: false,
      optionalReason: 'wrong time',
      createdAt: DateTime(2026, 4, 17, 9, 30),
    );

    await service.saveFeedback(entry);
    final saved = await service.getFeedbackEntries();

    expect(saved, hasLength(1));
    expect(saved.first.wasHelpful, isFalse);
    expect(saved.first.optionalReason, 'wrong time');
    expect(saved.first.recommendedCategory, 'Coding');
    expect(saved.first.recommendedDurationMinutes, 25);
  });

  test('saves coach snapshots locally', () async {
    const message = FocusCoachMessage(
      title: 'Right now, Writing looks like your best option.',
      body: 'This may not be your strongest time, so keep it short.',
      actionText: 'Try 20 min of Writing',
      confidenceLabel: 'Keep it simple',
      type: FocusCoachMessageType.warning,
      recommendedCategory: 'Writing',
      recommendedDurationMinutes: 20,
      betterLaterHint: 'You may do better with this tomorrow morning.',
    );

    final snapshot = CoachMessageSnapshot.fromMessage(
      message,
      createdAt: DateTime(2026, 4, 17, 23),
    );

    await service.saveMessageSnapshot(snapshot);
    final saved = await service.getMessageSnapshots();

    expect(saved, hasLength(1));
    expect(saved.first.coachMessageType, FocusCoachMessageType.warning);
    expect(
      saved.first.betterLaterHint,
      'You may do better with this tomorrow morning.',
    );
    expect(saved.first.recommendedCategory, 'Writing');
  });

  test('snapshot signature stays stable across timestamps', () {
    const message = FocusCoachMessage(
      title: 'I need a little more data',
      body: 'Try adding a few more sessions and reflections.',
      actionText: 'Add a few more sessions',
      confidenceLabel: 'Best next step',
      type: FocusCoachMessageType.notEnoughData,
    );

    final first = CoachMessageSnapshot.fromMessage(
      message,
      createdAt: DateTime(2026, 4, 17, 10),
    );
    final second = CoachMessageSnapshot.fromMessage(
      message,
      createdAt: DateTime(2026, 4, 17, 11),
    );

    expect(first.signature, second.signature);
  });
}
