import 'package:flutter/cupertino.dart';

/// Data for Insights page (charts, stats). Computed from sessions.
class InsightsData {
  const InsightsData({
    required this.avgDailyFocusMinutes,
    required this.successRatePercent,
    required this.weeklyFocusMinutes,
    required this.weekdayLabels,
    required this.weeklyMaxY,
    required this.focusByType,
    required this.peakPerformanceTitle,
    required this.peakPerformanceMessage,
  });

  final int avgDailyFocusMinutes;
  final int successRatePercent;
  final List<int> weeklyFocusMinutes;
  final List<String> weekdayLabels;
  final int weeklyMaxY;
  final List<FocusTypeSegment> focusByType;
  final String peakPerformanceTitle;
  final String peakPerformanceMessage;

  /// Fallback when no sessions yet
  factory InsightsData.empty() {
    return InsightsData(
      avgDailyFocusMinutes: 0,
      successRatePercent: 0,
      weeklyFocusMinutes: const [0, 0, 0, 0, 0, 0, 0],
      weekdayLabels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      weeklyMaxY: 60,
      focusByType: [],
      peakPerformanceTitle: 'Peak Performance',
      peakPerformanceMessage:
          'Complete focus sessions to see insights about your productivity patterns.',
    );
  }
}

class FocusTypeSegment {
  const FocusTypeSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}
