import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

class InsightsTab extends StatelessWidget {
  const InsightsTab({super.key, this.data});

  /// Pass real values here later (ex: from DB).
  final InsightsData? data;

  @override
  Widget build(BuildContext context) {
    final d = data ?? InsightsData.mock();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Insights'),
            border: null,
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Your productivity patterns',
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: CupertinoIcons.clock,
                          iconColor: CupertinoColors.systemBlue,
                          value: '${d.avgDailyFocusMinutes}m',
                          label: 'Avg daily focus',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          icon: CupertinoIcons.scope,
                          iconColor: CupertinoColors.systemGreen,
                          value: '${d.successRatePercent}%',
                          label: 'Success rate',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              CupertinoIcons.chart_bar_alt_fill,
                              size: 18,
                              color: CupertinoColors.secondaryLabel,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Weekly Focus Time',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: CupertinoColors.label,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 220,
                          child: _WeeklyBarChart(
                            values: d.weeklyFocusMinutes,
                            labels: d.weekdayLabels,
                            barColor: CupertinoColors.activeBlue,
                            maxY: d.weeklyMaxY,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Focus by Type',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.label,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: SizedBox(
                            width: 190,
                            height: 190,
                            child: _DonutChart(
                              segments: d.focusByType,
                              thickness: 26,
                              gapDegrees: 2.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _LegendGrid(items: d.focusByType),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PeakPerformanceCard(
                    title: d.peakPerformanceTitle,
                    message: d.peakPerformanceMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

  /// Minutes per weekday.
  final List<int> weeklyFocusMinutes;
  final List<String> weekdayLabels;

  /// Used to keep the chart stable while data changes.
  final int weeklyMaxY;

  final List<FocusTypeSegment> focusByType;

  final String peakPerformanceTitle;
  final String peakPerformanceMessage;

  factory InsightsData.mock() {
    return InsightsData(
      avgDailyFocusMinutes: 101,
      successRatePercent: 75,
      weeklyFocusMinutes: const [120, 90, 150, 105, 135, 60, 45],
      weekdayLabels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      weeklyMaxY: 160,
      focusByType: const [
        FocusTypeSegment(
          label: 'Reading',
          value: 8,
          color: CupertinoColors.activeBlue,
        ),
        FocusTypeSegment(
          label: 'Writing',
          value: 5,
          color: CupertinoColors.systemPurple,
        ),
        FocusTypeSegment(
          label: 'Coding',
          value: 6,
          color: CupertinoColors.systemGreen,
        ),
        FocusTypeSegment(
          label: 'Review',
          value: 4,
          color: Color(0xFFE6A23C),
        ),
        FocusTypeSegment(
          label: 'Other',
          value: 2,
          color: CupertinoColors.systemGrey,
        ),
      ],
      peakPerformanceTitle: 'Peak Performance',
      peakPerformanceMessage:
          'You focus best in the morning.\nConsider scheduling your most\nimportant work during this time.',
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

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              height: 1.0,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.maxY,
  });

  final List<int> values;
  final List<String> labels;
  final Color barColor;
  final int maxY;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _WeeklyBarChartPainter(
            values: values,
            labels: labels,
            barColor: barColor,
            maxY: maxY,
          ),
        );
      },
    );
  }
}

class _WeeklyBarChartPainter extends CustomPainter {
  _WeeklyBarChartPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.maxY,
  });

  final List<int> values;
  final List<String> labels;
  final Color barColor;
  final int maxY;

  @override
  void paint(Canvas canvas, Size size) {
    final leftGutter = 32.0;
    final bottomGutter = 26.0;
    final topGutter = 10.0;

    final chartRect = Rect.fromLTWH(
      leftGutter,
      topGutter,
      size.width - leftGutter,
      size.height - topGutter - bottomGutter,
    );

    final gridPaint = Paint()
      ..color = CupertinoColors.systemGrey4.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const yTicks = [0, 40, 80, 120, 160];
    for (final tick in yTicks) {
      final t = tick / maxY;
      final y = chartRect.bottom - (chartRect.height * t);

      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: '$tick',
        style: const TextStyle(
          fontSize: 12,
          color: CupertinoColors.secondaryLabel,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartRect.left - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    final n = math.min(values.length, labels.length);
    if (n == 0) return;

    final slotW = chartRect.width / n;
    final barW = math.max(10.0, math.min(28.0, slotW * 0.52));

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final v = values[i].clamp(0, maxY);
      final h = chartRect.height * (v / maxY);

      final cx = chartRect.left + (slotW * (i + 0.5));
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          cx - barW / 2,
          chartRect.bottom - h,
          barW,
          h,
        ),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
        bottomLeft: const Radius.circular(10),
        bottomRight: const Radius.circular(10),
      );
      canvas.drawRRect(rect, barPaint);

      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          fontSize: 12,
          color: CupertinoColors.secondaryLabel,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(cx - textPainter.width / 2, chartRect.bottom + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyBarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.barColor != barColor ||
        oldDelegate.maxY != maxY;
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.segments,
    required this.thickness,
    required this.gapDegrees,
  });

  final List<FocusTypeSegment> segments;
  final double thickness;
  final double gapDegrees;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutChartPainter(
        segments: segments,
        thickness: thickness,
        gapDegrees: gapDegrees,
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.segments,
    required this.thickness,
    required this.gapDegrees,
  });

  final List<FocusTypeSegment> segments;
  final double thickness;
  final double gapDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<int>(0, (sum, s) => sum + math.max(0, s.value));
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius - thickness / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;

    final gap = gapDegrees * (math.pi / 180);
    var start = -math.pi / 2;

    for (final s in segments) {
      final v = math.max(0, s.value);
      if (v == 0) continue;

      final sweep = (v / total) * (math.pi * 2);
      final sweepWithGap = math.max(0.0, sweep - gap);

      paint.color = s.color;
      canvas.drawArc(rect, start, sweepWithGap, false, paint);

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.thickness != thickness ||
        oldDelegate.gapDegrees != gapDegrees;
  }
}

class _LegendGrid extends StatelessWidget {
  const _LegendGrid({required this.items});

  final List<FocusTypeSegment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final left = <FocusTypeSegment>[];
    final right = <FocusTypeSegment>[];
    for (var i = 0; i < items.length; i++) {
      (i.isEven ? left : right).add(items[i]);
    }

    return Row(
      children: [
        Expanded(child: _LegendColumn(items: left)),
        const SizedBox(width: 16),
        Expanded(child: _LegendColumn(items: right)),
      ],
    );
  }
}

class _LegendColumn extends StatelessWidget {
  const _LegendColumn({required this.items});

  final List<FocusTypeSegment> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items) ...[
          _LegendRow(item: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.item});

  final FocusTypeSegment item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: item.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.label,
            style: const TextStyle(
              fontSize: 16,
              color: CupertinoColors.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${item.value}',
          style: const TextStyle(
            fontSize: 16,
            color: CupertinoColors.secondaryLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PeakPerformanceCard extends StatelessWidget {
  const _PeakPerformanceCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.lightbulb,
              color: CupertinoColors.activeBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
