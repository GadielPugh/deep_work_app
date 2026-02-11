import 'package:deep_work/sessionReflection.dart';
import 'package:deep_work/session_type.dart';

class Session {
  const Session({
    required this.intention,
    required this.durationMinutes,
    required this.outcome,
    required this.dateTime,
    required this.sessionType,
  });

  final String intention;
  final int durationMinutes;
  final CompletionStatus outcome;
  final DateTime dateTime;
  final SessionType sessionType;
}
