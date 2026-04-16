import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/models/insights_data.dart';
import 'package:deep_work/state/categories_state.dart';
import 'package:deep_work/state/sessions_state.dart';

/// State Management for the Insights page.
///
/// - Receives events: load
/// - Uses [SessionsState] for session list
/// - Computes chart and stats data from sessions
class InsightsPageState extends ChangeNotifier {
  InsightsPageState._() {
    SessionsState.instance.addListener(_onSessionsChanged);
    CategoriesState.instance.addListener(_onSessionsChanged);
  }

  static final InsightsPageState instance = InsightsPageState._();

  void _onSessionsChanged() {
    _compute();
  }

  InsightsData _data = InsightsData.empty();

  InsightsData get data => _data;

  Future<void> load() async {
    if (!SessionsState.instance.isLoaded) {
      await SessionsState.instance.load();
    }
    if (!CategoriesState.instance.isLoaded) {
      await CategoriesState.instance.load();
    }
    _compute();
  }

  void _compute() {
    final sessions = SessionsState.instance.sessions;
    if (sessions.isEmpty) {
      _data = InsightsData.empty();
      notifyListeners();
      return;
    }

    // Avg daily focus (last 7 days)
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekSessions = sessions
        .where((s) => s.dateTime.isAfter(weekAgo))
        .toList();
    final daysWithSessions = <DateTime>{};
    var totalMinutes = 0;
    for (final s in weekSessions) {
      final d = DateTime(s.dateTime.year, s.dateTime.month, s.dateTime.day);
      daysWithSessions.add(d);
      totalMinutes += s.durationMinutes;
    }
    final days = daysWithSessions.isEmpty ? 1 : daysWithSessions.length;
    final avgDaily = (totalMinutes / days).round();

    // Success rate
    var completed = 0;
    for (final s in weekSessions) {
      if (s.outcome == CompletionStatus.yes) completed++;
    }
    final successRate = weekSessions.isEmpty ? 0 : (completed * 100 / weekSessions.length).round();

    // Weekly focus (Mon–Sun)
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final values = List<int>.filled(7, 0);
    for (final s in weekSessions) {
      // weekday: 1=Mon, 7=Sun
      var w = s.dateTime.weekday - 1;
      if (w < 0) w = 0;
      if (w > 6) w = 6;
      values[w] += s.durationMinutes;
    }
    final maxY = values.isEmpty ? 60 : values.reduce((a, b) => a > b ? a : b);
    final weeklyMaxY = ((maxY / 40).ceil() * 40).clamp(40, 200);

    // Focus by type
    // Focus by type (all-time)
    final byType = <String, int>{};
    for (final s in sessions) {
      byType[s.categoryId] = (byType[s.categoryId] ?? 0) + 1;
    }
    final categories = CategoriesState.instance.categories;
    const palette = <Color>[
      CupertinoColors.activeBlue,
      CupertinoColors.systemPurple,
      CupertinoColors.systemGreen,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPink,
      CupertinoColors.systemTeal,
      CupertinoColors.systemGrey,
    ];
    final focusByType = <FocusTypeSegment>[];
    var colorIndex = 0;
    for (final e in byType.entries) {
      if (e.value > 0) {
        FocusCategory? category;
        for (final c in categories) {
          if (c.id == e.key) {
            category = c;
            break;
          }
        }
        focusByType.add(FocusTypeSegment(
          label: category?.name ?? e.key,
          value: e.value,
          color: palette[colorIndex++ % palette.length],
        ));
      }
    }

    // Peak performance (simplified: assume morning if most sessions before noon)
    var morning = 0;
    var afternoon = 0;
    for (final s in weekSessions) {
      if (s.dateTime.hour < 12) morning++; else afternoon++;
    }
    final peakTitle = 'Peak Performance';
    final peakMessage = morning >= afternoon
        ? 'You focus best in the morning.\nConsider scheduling your most\nimportant work during this time.'
        : 'You focus best in the afternoon.\nConsider scheduling your most\nimportant work during this time.';

    _data = InsightsData(
      avgDailyFocusMinutes: avgDaily,
      successRatePercent: successRate,
      weeklyFocusMinutes: values,
      weekdayLabels: labels,
      weeklyMaxY: weeklyMaxY,
      focusByType: focusByType.isEmpty
          ? [FocusTypeSegment(label: 'No data', value: 0, color: CupertinoColors.systemGrey)]
          : focusByType,
      peakPerformanceTitle: peakTitle,
      peakPerformanceMessage: peakMessage,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    SessionsState.instance.removeListener(_onSessionsChanged);
    CategoriesState.instance.removeListener(_onSessionsChanged);
    super.dispose();
  }
}
