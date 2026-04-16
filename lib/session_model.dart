import 'package:deep_work/models/completion_status.dart';

class Session {
  const Session({
    this.id,
    required this.intention,
    required this.durationMinutes,
    required this.outcome,
    required this.dateTime,
    required this.categoryId,
    this.reflection,
    this.startedAt,
    this.stoppedAt,
  });

  /// Set when loaded from database.
  final int? id;
  final String intention;
  final int durationMinutes;
  final CompletionStatus outcome;
  final DateTime dateTime;
  final String categoryId;
  /// What helped or distracted (from reflection screen).
  final String? reflection;
  /// When focus timer was started (UTC). Set when saving to DB.
  final DateTime? startedAt;
  /// When focus timer was stopped (UTC). Set when saving to DB.
  final DateTime? stoppedAt;
}
