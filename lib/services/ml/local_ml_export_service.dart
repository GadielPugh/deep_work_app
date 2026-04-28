import 'dart:convert';
import 'dart:io';

import 'package:deep_work/models/coach_feedback_entry.dart';
import 'package:deep_work/models/coach_message_snapshot.dart';
import 'package:deep_work/models/ml/shadow_prediction_log_entry.dart';
import 'package:deep_work/services/storage/local_coach_storage_service.dart';
import 'package:deep_work/services/storage/local_shadow_prediction_storage_service.dart';
import 'package:deep_work/services/storage/session_storage_service.dart';
import 'package:path_provider/path_provider.dart';

class MlExportBundle {
  const MlExportBundle({
    required this.createdAt,
    required this.sessions,
    required this.coachFeedback,
    required this.coachSnapshots,
    required this.shadowPredictions,
  });

  final DateTime createdAt;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> coachFeedback;
  final List<Map<String, dynamic>> coachSnapshots;
  final List<Map<String, dynamic>> shadowPredictions;

  Map<String, dynamic> manifest() {
    return {
      'schemaVersion': 1,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'files': {
        'sessions': 'sessions.jsonl',
        'coachFeedback': 'coach_feedback.jsonl',
        'coachSnapshots': 'coach_snapshots.jsonl',
        'shadowPredictions': 'shadow_predictions.jsonl',
      },
      'counts': {
        'sessions': sessions.length,
        'coachFeedback': coachFeedback.length,
        'coachSnapshots': coachSnapshots.length,
        'shadowPredictions': shadowPredictions.length,
      },
    };
  }
}

class MlExportResult {
  const MlExportResult({
    required this.directory,
    required this.files,
    required this.manifest,
  });

  final Directory directory;
  final Map<String, File> files;
  final Map<String, dynamic> manifest;
}

class LocalMlExportService {
  const LocalMlExportService({
    required SessionStorageService sessionStorage,
    required LocalCoachStorageService coachStorage,
    required LocalShadowPredictionStorageService shadowPredictionStorage,
  }) : _sessionStorage = sessionStorage,
       _coachStorage = coachStorage,
       _shadowPredictionStorage = shadowPredictionStorage;

  final SessionStorageService _sessionStorage;
  final LocalCoachStorageService _coachStorage;
  final LocalShadowPredictionStorageService _shadowPredictionStorage;

  Future<MlExportBundle> buildExportBundle({DateTime? createdAt}) async {
    final sessionRows = await _sessionStorage.getAllRowsForExport();
    final feedbackEntries = await _coachStorage.getFeedbackEntries();
    final coachSnapshots = await _coachStorage.getMessageSnapshots();
    final shadowEntries = await _shadowPredictionStorage.getEntries();

    return MlExportBundle(
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
      sessions: sessionRows.map(_sessionRowToJson).toList(growable: false),
      coachFeedback: feedbackEntries
          .map(_coachFeedbackToJson)
          .toList(growable: false),
      coachSnapshots: coachSnapshots
          .map(_coachSnapshotToJson)
          .toList(growable: false),
      shadowPredictions: shadowEntries
          .map(_shadowEntryToJson)
          .toList(growable: false),
    );
  }

  Future<MlExportResult> exportToDefaultDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final now = DateTime.now().toUtc();
    final directory = Directory(
      '${base.path}/ml_exports/deep_work_ml_export_${_fileTimestamp(now)}',
    );
    return exportToDirectory(directory, createdAt: now);
  }

  Future<MlExportResult> exportToDirectory(
    Directory directory, {
    DateTime? createdAt,
  }) async {
    final bundle = await buildExportBundle(createdAt: createdAt);
    await directory.create(recursive: true);

    final files = <String, File>{
      'sessions': File('${directory.path}/sessions.jsonl'),
      'coachFeedback': File('${directory.path}/coach_feedback.jsonl'),
      'coachSnapshots': File('${directory.path}/coach_snapshots.jsonl'),
      'shadowPredictions': File('${directory.path}/shadow_predictions.jsonl'),
      'manifest': File('${directory.path}/manifest.json'),
    };

    await _writeJsonl(files['sessions']!, bundle.sessions);
    await _writeJsonl(files['coachFeedback']!, bundle.coachFeedback);
    await _writeJsonl(files['coachSnapshots']!, bundle.coachSnapshots);
    await _writeJsonl(files['shadowPredictions']!, bundle.shadowPredictions);
    final manifest = bundle.manifest();
    await files['manifest']!.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );

    return MlExportResult(
      directory: directory,
      files: files,
      manifest: manifest,
    );
  }

  Map<String, dynamic> _sessionRowToJson(Map<String, dynamic> row) {
    final startedAtMs =
        _intValue(row['started_at_ms']) ??
        _dateTimeMs(row['startedAt']) ??
        _dateTimeMs(row['dateTime']) ??
        0;
    final stoppedAtMs =
        _intValue(row['stopped_at_ms']) ??
        _dateTimeMs(row['stoppedAt']) ??
        startedAtMs;
    final durationSeconds =
        _intValue(row['duration_seconds']) ??
        (_intValue(row['durationMinutes']) ?? 0) * 60;

    return {
      'session_id': _stringValue(row['id'] ?? row['session_id']),
      'intention': _stringValue(row['intention']),
      'category': _stringValue(row['category'] ?? row['categoryId']),
      'started_at_ms': startedAtMs,
      'stopped_at_ms': stoppedAtMs,
      'duration_seconds': durationSeconds,
      'outcome': _stringValue(row['outcome']),
      'reflection': row['reflection']?.toString(),
      'created_at_ms': _intValue(row['created_at_ms']) ?? startedAtMs,
    };
  }

  Map<String, dynamic> _coachFeedbackToJson(CoachFeedbackEntry entry) {
    return {
      'id': entry.id,
      'createdAt': entry.createdAt.toUtc().millisecondsSinceEpoch,
      'coachMessageType': entry.coachMessageType.name,
      'recommendedCategory': entry.recommendedCategory,
      'recommendedDurationMinutes': entry.recommendedDurationMinutes,
      'confidenceLabel': entry.confidenceLabel,
      'wasHelpful': entry.wasHelpful,
      'optionalReason': entry.optionalReason,
    };
  }

  Map<String, dynamic> _coachSnapshotToJson(CoachMessageSnapshot snapshot) {
    return {
      'createdAt': snapshot.createdAt.toUtc().millisecondsSinceEpoch,
      'title': snapshot.title,
      'body': snapshot.body,
      'actionText': snapshot.actionText,
      'coachMessageType': snapshot.coachMessageType.name,
      'confidenceLabel': snapshot.confidenceLabel,
      'recommendedCategory': snapshot.recommendedCategory,
      'recommendedDurationMinutes': snapshot.recommendedDurationMinutes,
      'betterLaterHint': snapshot.betterLaterHint,
    };
  }

  Map<String, dynamic> _shadowEntryToJson(ShadowPredictionLogEntry entry) {
    return {
      'id': entry.id,
      'createdAt': entry.createdAt.toUtc().millisecondsSinceEpoch,
      'heuristicMessageType': entry.heuristicMessageType.name,
      'heuristicRecommendationCategory': entry.heuristicRecommendationCategory,
      'heuristicRecommendedDurationMinutes':
          entry.heuristicRecommendedDurationMinutes,
      'mlSuccessProbability': entry.mlSuccessProbability,
      'resolvedAt': entry.resolvedAt?.toUtc().millisecondsSinceEpoch,
      'completedSessionCategoryId': entry.completedSessionCategoryId,
      'laterSessionSucceeded': entry.laterSessionSucceeded,
    };
  }

  Future<void> _writeJsonl(File file, List<Map<String, dynamic>> rows) async {
    final sink = file.openWrite();
    try {
      for (final row in rows) {
        sink.writeln(jsonEncode(row));
      }
    } finally {
      await sink.close();
    }
  }

  String _fileTimestamp(DateTime value) {
    return value
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll('.', '')
        .replaceAll('Z', 'Z');
  }

  int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int? _dateTimeMs(Object? value) {
    if (value is DateTime) return value.toUtc().millisecondsSinceEpoch;
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc().millisecondsSinceEpoch;
    }
    return null;
  }

  String _stringValue(Object? value) {
    return value?.toString() ?? '';
  }
}
