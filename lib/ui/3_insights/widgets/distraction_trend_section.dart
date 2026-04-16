import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import 'package:deep_work/models/insights_data.dart';

import 'insight_card.dart';

class DistractionTrendSection extends StatelessWidget {
  const DistractionTrendSection({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final trend = data.distractionTrend;
    if (trend == null) {
      return const SizedBox.shrink();
    }

    final series = trend.series;
    if (series.values.isEmpty || series.maxY <= 0) {
      return const InsightCard(
        child: Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text(
            'Not enough reflections yet.',
            style: TextStyle(
              fontSize: 14.5,
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distraction trend',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Reflection-based signal only. Use it as an early pattern, not a certainty.',
            style: TextStyle(
              fontSize: 11.5,
              color: CupertinoColors.tertiaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: _TrendLineChart(
              labels: series.labels,
              values: series.values,
              maxY: series.maxY,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({
    required this.labels,
    required this.values,
    required this.maxY,
  });

  final List<String> labels;
  final List<double> values;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _TrendLineChartPainter(
            labels: labels,
            values: values,
            maxY: maxY,
          ),
        );
      },
    );
  }
}

class _TrendLineChartPainter extends CustomPainter {
  _TrendLineChartPainter({
    required this.labels,
    required this.values,
    required this.maxY,
  });

  final List<String> labels;
  final List<double> values;
  final double maxY;

  @override
  void paint(Canvas canvas, Size size) {
    final leftGutter = 36.0;
    final bottomGutter = 22.0;
    final topGutter = 8.0;
    final rightGutter = 10.0;

    final chartRect = Rect.fromLTWH(
      leftGutter,
      topGutter,
      size.width - leftGutter - rightGutter,
      size.height - topGutter - bottomGutter,
    );

    final gridPaint = Paint()
      ..color = CupertinoColors.systemGrey4.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 3 horizontal grid lines.
    for (var i = 0; i <= 3; i++) {
      final t = i / 3;
      final y = chartRect.bottom - chartRect.height * t;
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
    }

    final valueColor = CupertinoColors.systemOrange;
    final linePaint = Paint()
      ..color = valueColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = valueColor
      ..style = PaintingStyle.fill;

    final n = math.min(values.length, labels.length);
    if (n <= 1) return;

    final slotW = chartRect.width / (n - 1);

    final path = Path();
    for (var i = 0; i < n; i++) {
      final v = values[i].clamp(0, maxY);
      final t = maxY == 0 ? 0.0 : (v / maxY);
      final x = chartRect.left + slotW * i;
      final y = chartRect.bottom - chartRect.height * t;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    // Dots + start/end labels.
    for (var i = 0; i < n; i++) {
      final v = values[i].clamp(0, maxY);
      final t = maxY == 0 ? 0.0 : (v / maxY);
      final x = chartRect.left + slotW * i;
      final y = chartRect.bottom - chartRect.height * t;
      canvas.drawCircle(Offset(x, y), 3.2, dotPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final labelStyle = const TextStyle(
      fontSize: 11,
      color: CupertinoColors.secondaryLabel,
      fontWeight: FontWeight.w600,
    );

    if (labels.isNotEmpty) {
      final startLabel = labels.first;
      final endLabel = labels.last;

      textPainter.text = TextSpan(text: startLabel, style: labelStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartRect.left, chartRect.bottom + 4),
      );

      textPainter.text = TextSpan(text: endLabel, style: labelStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartRect.right - textPainter.width, chartRect.bottom + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.maxY != maxY;
  }
}

