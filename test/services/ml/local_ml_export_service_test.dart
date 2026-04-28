import 'dart:convert';
import 'dart:io';

import 'package:deep_work/models/coach_feedback_entry.dart';
import 'package:deep_work/models/coach_message_snapshot.dart';
import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/models/ml/shadow_prediction_log_entry.dart';
import 'package:deep_work/services/ml/local_ml_export_service.dart';
import 'package:deep_work/services/storage/local_coach_storage_service.dart';
import 'package:deep_work/services/storage/local_shadow_prediction_storage_service.dart';
import 'package:deep_work/services/storage/session_storage_service.dart';
import 'package:deep_work/session_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocalMlExportService', () {
    test(
      'builds serializable ML export payload with expected schema',
      () async {
        SharedPreferences.setMockInitialValues({});
        final coachStorage = LocalCoachStorageService();
        final shadowStorage = LocalShadowPredictionStorageService();
        final sessionStorage = _RowsOnlySessionStorage([
          {
            'id': 7,
            'intention': 'Write tests',
            'category': 'Coding',
            'started_at_ms': 1767265800000,
            'stopped_at_ms': 1767267300000,
            'duration_seconds': 1500,
            'outcome': 'yes',
            'reflection': 'good flow',
            'created_at_ms': 1767267600000,
          },
        ]);

        const message = FocusCoachMessage(
          title: 'This looks like a good time for Coding.',
          body: 'A short session could work well right now.',
          actionText: 'Try 25 min of Coding',
          confidenceLabel: 'Try now',
          type: FocusCoachMessageType.positive,
          recommendedCategory: 'Coding',
          recommendedDurationMinutes: 25,
        );
        await coachStorage.saveFeedback(
          CoachFeedbackEntry.fromMessage(
            message: message,
            wasHelpful: true,
            createdAt: DateTime.utc(2026, 1, 1, 8),
          ),
        );
        await coachStorage.saveMessageSnapshot(
          CoachMessageSnapshot.fromMessage(
            message,
            createdAt: DateTime.utc(2026, 1, 1, 7, 55),
          ),
        );
        await shadowStorage.saveEntry(
          ShadowPredictionLogEntry.fromCoachDecision(
            message: message,
            mlSuccessProbability: 0.72,
            createdAt: DateTime.utc(2026, 1, 1, 7, 56),
          ),
        );

        final service = LocalMlExportService(
          sessionStorage: sessionStorage,
          coachStorage: coachStorage,
          shadowPredictionStorage: shadowStorage,
        );
        final bundle = await service.buildExportBundle(
          createdAt: DateTime.utc(2026, 1, 2),
        );

        expect(bundle.sessions.single['session_id'], '7');
        expect(bundle.sessions.single['started_at_ms'], 1767265800000);
        expect(bundle.sessions.single['outcome'], 'yes');
        expect(bundle.coachFeedback.single['createdAt'], isA<int>());
        expect(bundle.coachSnapshots.single['coachMessageType'], 'positive');
        expect(
          bundle.shadowPredictions.single['mlSuccessProbability'],
          inInclusiveRange(0, 1),
        );
        expect(bundle.manifest()['counts']['sessions'], 1);

        expect(() => jsonEncode(bundle.sessions.single), returnsNormally);
        expect(() => jsonEncode(bundle.manifest()), returnsNormally);
      },
    );

    test('writes JSONL files and tolerates missing optional data', () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'deep_work_ml_export_test_',
      );
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      final service = LocalMlExportService(
        sessionStorage: _RowsOnlySessionStorage([
          {
            'id': 9,
            'intention': 'Read',
            'category': 'Reading',
            'outcome': 'partially',
          },
        ]),
        coachStorage: LocalCoachStorageService(),
        shadowPredictionStorage: LocalShadowPredictionStorageService(),
      );

      final result = await service.exportToDirectory(
        directory,
        createdAt: DateTime.utc(2026, 1, 2),
      );

      expect(result.files['sessions']!.existsSync(), isTrue);
      expect(result.files['coachFeedback']!.existsSync(), isTrue);
      expect(result.files['coachSnapshots']!.existsSync(), isTrue);
      expect(result.files['shadowPredictions']!.existsSync(), isTrue);
      expect(result.files['manifest']!.existsSync(), isTrue);

      final sessionLine = result.files['sessions']!.readAsLinesSync().single;
      final session = jsonDecode(sessionLine) as Map<String, dynamic>;
      expect(session['session_id'], '9');
      expect(session['started_at_ms'], 0);
      expect(session['duration_seconds'], 0);
      expect(session['reflection'], isNull);

      final manifest =
          jsonDecode(result.files['manifest']!.readAsStringSync())
              as Map<String, dynamic>;
      expect(manifest['schemaVersion'], 1);
      expect(manifest['counts']['coachFeedback'], 0);
    });
  });
}

class _RowsOnlySessionStorage implements SessionStorageService {
  _RowsOnlySessionStorage(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  Future<void> deleteSession(int id) async {}

  @override
  Future<List<Session>> getAllSessions() async => const [];

  @override
  Future<List<Map<String, dynamic>>> getAllRowsForExport() async => rows;

  @override
  Future<int> insertSession({
    required String intention,
    required String category,
    required DateTime startedAt,
    required DateTime stoppedAt,
    required int durationSeconds,
    required String outcome,
    String? reflection,
  }) async {
    return 0;
  }
}
