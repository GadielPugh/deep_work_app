// ignore_for_file: file_names

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/models/coach_feedback_entry.dart';
import 'package:deep_work/models/coach_message_snapshot.dart';
import 'package:deep_work/models/focus_coach_message.dart';
import 'package:deep_work/models/insights_data.dart';
import 'package:deep_work/services/analytics/focus_coach_message_service.dart';
import 'package:deep_work/services/app_services.dart';
import 'package:deep_work/state/categories_state.dart';
import 'package:deep_work/state/insights_page_state.dart';
import 'package:deep_work/state/sessions_state.dart';
import 'package:deep_work/ui/3_insights/widgets/dev_insights_debug_section.dart';
import 'package:deep_work/ui/3_insights/widgets/insight_card.dart';

class InsightsTab extends StatefulWidget {
  const InsightsTab({super.key});

  @override
  State<InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<InsightsTab> {
  final _state = InsightsPageState.instance;
  final _coachMessageService = const FocusCoachMessageService();

  bool _showDetails = false;
  String? _lastSavedCoachSnapshotSignature;
  String? _lastSavedShadowDecisionSignature;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    _state.load();
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isLoading =
        !SessionsState.instance.isLoaded || !CategoriesState.instance.isLoaded;
    final data = _state.data;
    final categories = CategoriesState.instance.categories;
    final now = DateTime.now();
    final coachMessage = _coachMessageService.buildMessage(
      data: data,
      categories: categories,
      now: now,
    );
    final coachSnapshot = CoachMessageSnapshot.fromMessage(coachMessage);

    if (!isLoading) {
      _scheduleCoachSnapshotSave(coachSnapshot);
      _scheduleMlShadowLog(
        message: coachMessage,
        now: now,
        sessionsCount: SessionsState.instance.sessions.length,
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Insights'),
            border: null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: isLoading
                  ? const _InsightsLoadingState()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'One clear coaching note based on your recent focus sessions.',
                          style: TextStyle(
                            fontSize: 16,
                            color: CupertinoColors.secondaryLabel,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _CoachCard(message: coachMessage),
                        const SizedBox(height: 10),
                        _CoachFeedbackBar(
                          key: ValueKey(coachSnapshot.signature),
                          message: coachMessage,
                        ),
                        const SizedBox(height: 12),
                        _DetailsToggle(
                          expanded: _showDetails,
                          onPressed: () {
                            setState(() {
                              _showDetails = !_showDetails;
                            });
                          },
                        ),
                        if (_showDetails) ...[
                          const SizedBox(height: 12),
                          _DetailsCard(
                            data: data,
                            categories: categories,
                            coachMessageService: _coachMessageService,
                          ),
                          if (data.debugInfo != null) ...[
                            const SizedBox(height: 12),
                            DevInsightsDebugSection(debugInfo: data.debugInfo!),
                          ],
                          const SizedBox(height: 16),
                        ] else
                          const SizedBox(height: 16),
                        _OverviewStatsRow(data: data),
                        const SizedBox(height: 16),
                        _WeeklyFocusCard(data: data),
                        const SizedBox(height: 16),
                        _FocusByTypeCard(data: data),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleCoachSnapshotSave(CoachMessageSnapshot snapshot) {
    final signature = snapshot.signature;
    if (_lastSavedCoachSnapshotSignature == signature) return;

    _lastSavedCoachSnapshotSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_persistCoachSnapshot(snapshot));
    });
  }

  Future<void> _persistCoachSnapshot(CoachMessageSnapshot snapshot) async {
    try {
      await AppServices.coachStorage.saveMessageSnapshot(snapshot);
    } catch (_) {
      if (_lastSavedCoachSnapshotSignature == snapshot.signature) {
        _lastSavedCoachSnapshotSignature = null;
      }
      // Keep the coach UI resilient even if local persistence is unavailable.
    }
  }

  void _scheduleMlShadowLog({
    required FocusCoachMessage message,
    required DateTime now,
    required int sessionsCount,
  }) {
    final signature =
        '${CoachMessageSnapshot.fromMessage(message, createdAt: now).signature}|$sessionsCount';
    if (_lastSavedShadowDecisionSignature == signature) return;

    _lastSavedShadowDecisionSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_recordMlShadowDecision(message: message, now: now));
    });
  }

  Future<void> _recordMlShadowDecision({
    required FocusCoachMessage message,
    required DateTime now,
  }) async {
    try {
      await AppServices.mlShadowModeService.recordCoachDecision(
        message: message,
        now: now,
        sessions: SessionsState.instance.sessions,
      );
    } catch (_) {
      // Shadow mode must never affect the live coach experience.
    }
  }
}

class _InsightsLoadingState extends StatelessWidget {
  const _InsightsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            CupertinoActivityIndicator(radius: 12),
            SizedBox(height: 12),
            Text(
              'Preparing your coach note...',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.message});

  final FocusCoachMessage message;

  @override
  Widget build(BuildContext context) {
    final style = _CoachCardStyle.fromType(message.type);

    return InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: style.tintColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, size: 24, color: style.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Coach',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.title,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: CupertinoColors.label,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message.body,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              color: CupertinoColors.label,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: style.tintColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.confidenceLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: style.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message.actionText,
                  style: const TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (message.reasonLine != null) ...[
            const SizedBox(height: 12),
            Text(
              message.reasonLine!,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachFeedbackBar extends StatefulWidget {
  const _CoachFeedbackBar({super.key, required this.message});

  final FocusCoachMessage message;

  @override
  State<_CoachFeedbackBar> createState() => _CoachFeedbackBarState();
}

class _CoachFeedbackBarState extends State<_CoachFeedbackBar> {
  static const _notHelpfulReasons = [
    'wrong time',
    'wrong category',
    'wrong duration',
    'message unclear',
    'not enough context',
  ];

  bool _isSaving = false;
  bool? _wasHelpful;
  String? _statusText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Was this helpful?',
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _FeedbackPillButton(
              label: 'Helpful',
              icon: CupertinoIcons.hand_thumbsup,
              selected: _wasHelpful == true,
              color: CupertinoColors.systemGreen,
              onPressed: _isSaving || _wasHelpful != null
                  ? null
                  : _submitHelpful,
            ),
            const SizedBox(width: 10),
            _FeedbackPillButton(
              label: 'Not helpful',
              icon: CupertinoIcons.hand_thumbsdown,
              selected: _wasHelpful == false,
              color: CupertinoColors.systemOrange,
              onPressed: _isSaving || _wasHelpful != null
                  ? null
                  : _showNotHelpfulSheet,
            ),
          ],
        ),
        if (_statusText != null) ...[
          const SizedBox(height: 8),
          Text(
            _statusText!,
            style: const TextStyle(
              fontSize: 13.5,
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submitHelpful() async {
    await _saveFeedback(wasHelpful: true);
  }

  Future<void> _showNotHelpfulSheet() async {
    final selectedReason = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('What felt off?'),
          message: const Text('Pick the closest reason.'),
          actions: [
            for (final reason in _notHelpfulReasons)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(context).pop(reason);
                },
                child: Text(_sheetLabel(reason)),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (!mounted || selectedReason == null) return;
    await _saveFeedback(wasHelpful: false, optionalReason: selectedReason);
  }

  Future<void> _saveFeedback({
    required bool wasHelpful,
    String? optionalReason,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final entry = CoachFeedbackEntry.fromMessage(
        message: widget.message,
        wasHelpful: wasHelpful,
        optionalReason: optionalReason,
      );
      await AppServices.coachStorage.saveFeedback(entry);
      try {
        await AppServices.personalizationProfileService.recordCoachFeedback(
          entry,
        );
      } catch (_) {
        // Personalization updates must never interrupt feedback capture.
      }

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _wasHelpful = wasHelpful;
        _statusText = wasHelpful
            ? 'Thanks. That helps.'
            : 'Thanks. I\'ll use that to improve the coach.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _statusText = 'Feedback was not saved. Please try again.';
      });
    }
  }

  String _sheetLabel(String reason) {
    if (reason.isEmpty) return reason;
    return reason[0].toUpperCase() + reason.substring(1);
  }
}

class _FeedbackPillButton extends StatelessWidget {
  const _FeedbackPillButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected
        ? color.withValues(alpha: 0.14)
        : CupertinoColors.systemGrey6;
    final foregroundColor = selected ? color : CupertinoColors.label;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.35)
                : CupertinoColors.systemGrey4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsToggle extends StatelessWidget {
  const _DetailsToggle({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Row(
        children: [
          Text(
            expanded ? 'Hide details' : 'See details',
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.activeBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
            size: 15,
            color: CupertinoColors.activeBlue,
          ),
        ],
      ),
    );
  }
}

class _OverviewStatsRow extends StatelessWidget {
  const _OverviewStatsRow({required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: CupertinoIcons.clock,
            iconColor: CupertinoColors.systemBlue,
            value: '${data.avgDailyFocusMinutes}m',
            label: 'Avg daily focus',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatCard(
            icon: CupertinoIcons.scope,
            iconColor: CupertinoColors.systemGreen,
            value: '${data.successRatePercent}%',
            label: 'Success rate',
          ),
        ),
      ],
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
    return InsightCard(
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

class _WeeklyFocusCard extends StatelessWidget {
  const _WeeklyFocusCard({required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    return InsightCard(
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
              values: data.weeklyFocusMinutes,
              labels: data.weekdayLabels,
              barColor: CupertinoColors.activeBlue,
              maxY: data.weeklyMaxY,
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
    final leftGutter = 34.0;
    final bottomGutter = 30.0;
    final rightGutter = 10.0;
    final topGutter = 10.0;

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

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final yTicks = [0, math.max(0, maxY)];

    for (final tick in yTicks) {
      final t = maxY == 0 ? 0.0 : (tick / maxY);
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
        Offset(
          chartRect.left - textPainter.width - 8,
          y - textPainter.height / 2,
        ),
      );
    }

    final count = math.min(values.length, labels.length);
    if (count == 0) return;

    final slotWidth = chartRect.width / count;
    final barWidth = math.max(10.0, math.min(28.0, slotWidth * 0.52));
    final barPaint = Paint()..color = barColor;

    for (var i = 0; i < count; i++) {
      final value = values[i].clamp(0, math.max(1, maxY));
      final barHeight = maxY <= 0 ? 0.0 : chartRect.height * (value / maxY);
      final centerX = chartRect.left + (slotWidth * (i + 0.5));

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth / 2,
          chartRect.bottom - barHeight,
          barWidth,
          barHeight <= 0 ? 6 : barHeight,
        ),
        const Radius.circular(10),
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
        Offset(centerX - textPainter.width / 2, chartRect.bottom + 6),
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

class _FocusByTypeCard extends StatelessWidget {
  const _FocusByTypeCard({required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    return InsightCard(
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
                segments: data.focusByType,
                thickness: 26,
                gapDegrees: 2.4,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _LegendGrid(items: data.focusByType),
        ],
      ),
    );
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
    final total = segments.fold<int>(
      0,
      (sum, segment) => sum + math.max(0, segment.value),
    );
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - thickness / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;

    final gap = gapDegrees * (math.pi / 180);
    var start = -math.pi / 2;

    for (final segment in segments) {
      final value = math.max(0, segment.value);
      if (value == 0) continue;

      final sweep = (value / total) * (math.pi * 2);
      final sweepWithGap = math.max(0.0, sweep - gap);

      paint.color = segment.color;
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
          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
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

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.data,
    required this.categories,
    required this.coachMessageService,
  });

  final InsightsData data;
  final List<FocusCategory> categories;
  final FocusCoachMessageService coachMessageService;

  @override
  Widget build(BuildContext context) {
    final details = _buildDetails();

    return InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < details.length; i++) ...[
            _DetailRow(detail: details[i]),
            if (i != details.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  List<_CoachDetail> _buildDetails() {
    final details = <_CoachDetail>[];
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };

    final currentRecommendation = data.currentRecommendation;
    if (currentRecommendation != null) {
      final categoryName = currentRecommendation.categoryName.isNotEmpty
          ? currentRecommendation.categoryName
          : (categoryNames[currentRecommendation.categoryId] ??
                currentRecommendation.categoryId);
      details.add(
        _CoachDetail(
          label: 'Try now',
          text:
              '${currentRecommendation.recommendedDurationMinutes} minutes of $categoryName.',
        ),
      );
    }

    final trustedHours =
        data.bestWorstHoursByCategory
            .where((entry) => entry.confidence.isTrusted && entry.isConsistent)
            .toList()
          ..sort((a, b) => b.sampleCount.compareTo(a.sampleCount));
    if (trustedHours.isNotEmpty) {
      final preferredCategoryId =
          data.currentRecommendation?.categoryId ??
          data.predictionWarning?.recommendedCategoryId;
      var best = trustedHours.first;
      if (preferredCategoryId != null) {
        for (final candidate in trustedHours) {
          if (candidate.categoryId == preferredCategoryId) {
            best = candidate;
            break;
          }
        }
      }
      final categoryName = categoryNames[best.categoryId] ?? best.categoryId;
      final timeBlockDescription = coachMessageService.describeTimeBlock(
        best.bestHour,
      );
      details.add(
        _CoachDetail(
          label: 'Time block',
          text: '$categoryName is usually stronger $timeBlockDescription.',
        ),
      );
    }

    if (data.recurringDistractionThemes.isNotEmpty) {
      final theme = data.recurringDistractionThemes.first;
      if (theme.count >= 3) {
        details.add(
          _CoachDetail(
            label: 'Blocker',
            text:
                'Recent reflections sometimes mention ${_normalizeTheme(theme.theme).toLowerCase()}.',
          ),
        );
      }
    }

    final streaks = data.streaks;
    if (streaks != null && streaks.currentSuccessStreak > 0) {
      final sessionWord = streaks.currentSuccessStreak == 1
          ? 'session'
          : 'sessions';
      details.add(
        _CoachDetail(
          label: 'Streak',
          text:
              '${streaks.currentSuccessStreak} successful $sessionWord in a row.',
        ),
      );
    }

    if (details.isEmpty) {
      details.add(
        const _CoachDetail(
          label: 'Still learning',
          text:
              'Add a few more sessions and short reflections, and I will look for a clearer pattern.',
        ),
      );
    }

    return details;
  }

  String _normalizeTheme(String theme) {
    final normalized = theme.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (normalized.isEmpty) return 'A distraction';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.detail});

  final _CoachDetail detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            detail.label,
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            detail.text,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.35,
              color: CupertinoColors.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachDetail {
  const _CoachDetail({required this.label, required this.text});

  final String label;
  final String text;
}

class _CoachCardStyle {
  const _CoachCardStyle({
    required this.color,
    required this.tintColor,
    required this.icon,
  });

  final Color color;
  final Color tintColor;
  final IconData icon;

  factory _CoachCardStyle.fromType(FocusCoachMessageType type) {
    return switch (type) {
      FocusCoachMessageType.warning => _CoachCardStyle(
        color: CupertinoColors.systemOrange,
        tintColor: CupertinoColors.systemOrange.withValues(alpha: 0.14),
        icon: CupertinoIcons.exclamationmark_triangle_fill,
      ),
      FocusCoachMessageType.suggestion => _CoachCardStyle(
        color: CupertinoColors.activeBlue,
        tintColor: CupertinoColors.activeBlue.withValues(alpha: 0.12),
        icon: CupertinoIcons.lightbulb,
      ),
      FocusCoachMessageType.positive => _CoachCardStyle(
        color: CupertinoColors.systemGreen,
        tintColor: CupertinoColors.systemGreen.withValues(alpha: 0.12),
        icon: CupertinoIcons.check_mark_circled_solid,
      ),
      FocusCoachMessageType.neutral => _CoachCardStyle(
        color: CupertinoColors.systemGrey,
        tintColor: CupertinoColors.systemGrey4,
        icon: CupertinoIcons.info,
      ),
      FocusCoachMessageType.notEnoughData => _CoachCardStyle(
        color: CupertinoColors.systemGrey,
        tintColor: CupertinoColors.systemGrey5,
        icon: CupertinoIcons.clock,
      ),
    };
  }
}
