import 'package:flutter/foundation.dart';

import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/state/sessions_state.dart';

/// State Management for the Home page.
///
/// - Receives events: load
/// - Uses [SessionsState] for session list
/// - Computes "Today's Focus" metrics from sessions
class HomePageState extends ChangeNotifier {
  HomePageState._() {
    SessionsState.instance.addListener(_onSessionsChanged);
  }

  static final HomePageState instance = HomePageState._();

  void _onSessionsChanged() {
    _computeMetrics();
  }

  int _focusTimeTodayMinutes = 0;
  int _sessionCountToday = 0;
  int _completedPercentToday = 0;

  int get focusTimeTodayMinutes => _focusTimeTodayMinutes;
  int get sessionCountToday => _sessionCountToday;
  int get completedPercentToday => _completedPercentToday;

  /// Event: ensure sessions are loaded
  Future<void> load() async {
    if (!SessionsState.instance.isLoaded) {
      await SessionsState.instance.load();
    } else {
      _computeMetrics();
    }
  }

  void _computeMetrics() {
    final sessions = SessionsState.instance.sessions;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int totalMinutes = 0;
    int todayCount = 0;
    int completed = 0;

    for (final s in sessions) {
      final sessionDate = DateTime(s.dateTime.year, s.dateTime.month, s.dateTime.day);
      if (sessionDate == today) {
        totalMinutes += s.durationMinutes;
        todayCount++;
        if (s.outcome == CompletionStatus.yes) completed++;
      }
    }

    _focusTimeTodayMinutes = totalMinutes;
    _sessionCountToday = todayCount;
    _completedPercentToday = todayCount > 0 ? (completed * 100 / todayCount).round() : 0;
    notifyListeners();
  }
}
