import 'dart:math' as math;

import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/services/storage/session_storage_service.dart';

/// Deterministic fake session generator for development/testing.
class FakeSessionsGenerator {
  static const defaultCategoryIds = <String>[
    'reading',
    'writing',
    'coding',
    'review',
    'work',
    'other',
  ];

  static List<Session> generate({
    int count = 60,
    int seed = 42,
    DateTime? now,
    List<String> categoryIds = defaultCategoryIds,
    bool includeReflection = true,
  }) {
    final rng = math.Random(seed);
    final localNow = (now ?? DateTime.now()).toLocal();

    final intentions = <String>[
      'Complete chapter 3',
      'Write essay introduction',
      'Refactor the focus timer logic',
      'Review yesterday notes',
      'Plan tomorrow tasks',
      'Solve practice problems',
      'Draft project outline',
      'Deep work: top priority',
    ];

    final results = <Session>[];

    for (var i = 0; i < count; i++) {
      final dayOffset = rng.nextInt(30); // last 30 days
      final baseDate = localNow.subtract(Duration(days: dayOffset));

      final hour = rng.nextInt(16) + 6; // 06..21
      final minute = rng.nextInt(60);

      final dtLocal = DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
      final startedAtUtc = dtLocal.toUtc();

      final durationMinutes = (rng.nextInt(61) + 15); // 15..75
      final stoppedAtUtc = startedAtUtc.add(Duration(minutes: durationMinutes));

      final categoryId = categoryIds[rng.nextInt(categoryIds.length)];
      final intention = intentions[rng.nextInt(intentions.length)];

      // Add an hour-based success pattern so best-hours analytics is visible.
      final hourBoost = switch (hour) {
        9 || 10 || 11 => 0.15,
        13 || 14 => 0.06,
        6 || 7 || 8 => 0.02,
        18 || 19 => -0.02,
        _ => -0.03,
      };

      final categoryBase = switch (categoryId) {
        'coding' => 0.58,
        'reading' => 0.56,
        'writing' => 0.52,
        'review' => 0.54,
        'work' => 0.55,
        _ => 0.50,
      };

      var successProb = categoryBase + hourBoost + (rng.nextDouble() - 0.5) * 0.12;
      successProb = successProb.clamp(0.05, 0.95);

      final roll = rng.nextDouble();
      late final CompletionStatus outcome;
      if (roll < successProb) {
        outcome = CompletionStatus.yes;
      } else if (roll < successProb + (1 - successProb) * 0.45) {
        outcome = CompletionStatus.partially;
      } else {
        outcome = CompletionStatus.no;
      }

      final reflection = includeReflection ? _buildReflection(rng: rng, outcome: outcome) : null;

      results.add(
        Session(
          id: null,
          intention: intention,
          durationMinutes: durationMinutes,
          outcome: outcome,
          dateTime: startedAtUtc,
          categoryId: categoryId,
          reflection: reflection,
          startedAt: startedAtUtc,
          stoppedAt: stoppedAtUtc,
        ),
      );
    }

    results.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return results;
  }

  static Future<void> seedIntoStorage(
    SessionStorageService storage, {
    int count = 60,
    int seed = 42,
    DateTime? now,
    List<String> categoryIds = defaultCategoryIds,
    bool includeReflection = true,
  }) async {
    final sessions = generate(
      count: count,
      seed: seed,
      now: now,
      categoryIds: categoryIds,
      includeReflection: includeReflection,
    );

    // Non-destructive: inserts additional sessions.
    for (final s in sessions) {
      await storage.insertSession(
        intention: s.intention,
        category: s.categoryId,
        startedAt: s.startedAt ?? s.dateTime,
        stoppedAt: s.stoppedAt ?? s.dateTime.add(Duration(minutes: s.durationMinutes)),
        durationSeconds: s.durationMinutes * 60,
        outcome: s.outcome.name,
        reflection: s.reflection,
      );
    }
  }

  static String _buildReflection({
    required math.Random rng,
    required CompletionStatus outcome,
  }) {
    final templatesYes = <String>[
      'I felt focused and stayed in flow. Motivation and a calm environment helped. I also felt happy.',
      'Deep work went well; I stayed focused. It was a good session and I felt grateful.',
      'I had strong discipline and stayed focused for the whole time. The work felt joyful and motivating.',
    ];

    final templatesPartially = <String>[
      'I stayed focused, but phone notifications interrupted me. I felt tired and slightly stressed.',
      'Progress was okay; noise in the background made it harder, but I maintained motivation. I still felt focused.',
      'I was mostly on track, yet doomscrolling made me procrastinate. Stress from work was present.',
    ];

    final templatesNo = <String>[
      'Phone notifications were distracting, and I felt exhausted. Stress overwhelmed me, and I struggled to stay focused.',
      'Noise and traffic made it hard. I started studying but then procrastinated and doomscrolling took over. I felt tired.',
      'I tried to work, but my attention kept drifting to my phone. I felt overwhelmed and burnt out.',
    ];

    final list = switch (outcome) {
      CompletionStatus.yes => templatesYes,
      CompletionStatus.partially => templatesPartially,
      CompletionStatus.no => templatesNo,
    };

    // Add a small random suffix so clusters vary.
    final suffixes = <String>[
      ' Next time I will start earlier.',
      ' I should block distractions first.',
      ' I need a calmer setup.',
      ' I can do better with a tighter plan.',
      ' I want to return to flow.',
    ];

    return '${list[rng.nextInt(list.length)]}${suffixes[rng.nextInt(suffixes.length)]}';
  }
}

