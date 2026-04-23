import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deep_work/services/storage/local_session_storage_web_service.dart';

void main() {
  late LocalSessionStorageWebService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = LocalSessionStorageWebService();
  });

  test('loads empty state when browser storage has no sessions', () async {
    final sessions = await service.getAllSessions();

    expect(sessions, isEmpty);
  });

  test('inserts sessions and keeps newest first ordering', () async {
    await service.insertSession(
      intention: 'Read chapter',
      category: 'reading',
      startedAt: DateTime.utc(2026, 4, 20, 8),
      stoppedAt: DateTime.utc(2026, 4, 20, 8, 25),
      durationSeconds: 1500,
      outcome: 'yes',
    );
    await service.insertSession(
      intention: 'Write draft',
      category: 'writing',
      startedAt: DateTime.utc(2026, 4, 21, 9),
      stoppedAt: DateTime.utc(2026, 4, 21, 9, 30),
      durationSeconds: 1800,
      outcome: 'partially',
      reflection: 'Phone notifications were distracting',
    );

    final sessions = await service.getAllSessions();

    expect(sessions, hasLength(2));
    expect(sessions.first.intention, 'Write draft');
    expect(sessions.first.categoryId, 'writing');
    expect(sessions.first.reflection, 'Phone notifications were distracting');
    expect(sessions.first.id, 2);
    expect(sessions.last.id, 1);
  });

  test('deletes a stored session by id', () async {
    final firstId = await service.insertSession(
      intention: 'Read chapter',
      category: 'reading',
      startedAt: DateTime.utc(2026, 4, 20, 8),
      stoppedAt: DateTime.utc(2026, 4, 20, 8, 25),
      durationSeconds: 1500,
      outcome: 'yes',
    );
    await service.insertSession(
      intention: 'Write draft',
      category: 'writing',
      startedAt: DateTime.utc(2026, 4, 21, 9),
      stoppedAt: DateTime.utc(2026, 4, 21, 9, 30),
      durationSeconds: 1800,
      outcome: 'partially',
    );

    await service.deleteSession(firstId);
    final sessions = await service.getAllSessions();

    expect(sessions, hasLength(1));
    expect(sessions.single.intention, 'Write draft');
  });

  test('exports rows with the expected schema fields', () async {
    await service.insertSession(
      intention: 'Code feature',
      category: 'coding',
      startedAt: DateTime.utc(2026, 4, 21, 13),
      stoppedAt: DateTime.utc(2026, 4, 21, 13, 45),
      durationSeconds: 2700,
      outcome: 'yes',
      reflection: 'Quiet room helped',
    );

    final rows = await service.getAllRowsForExport();

    expect(rows, hasLength(1));
    expect(
      rows.single.keys,
      containsAll(<String>[
        'id',
        'intention',
        'category',
        'started_at_ms',
        'stopped_at_ms',
        'duration_seconds',
        'outcome',
        'reflection',
        'created_at_ms',
      ]),
    );
    expect(rows.single['category'], 'coding');
    expect(rows.single['reflection'], 'Quiet room helped');
  });
}
