import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/insights_data.dart';
import 'package:deep_work/state/categories_state.dart';

import 'insight_card.dart';

class CategorySuccessDurationSection extends StatelessWidget {
  const CategorySuccessDurationSection({super.key, required this.data});

  final InsightsData data;

  String _categoryLabel(String categoryId) {
    return CategoriesState.instance.byId(categoryId)?.name ?? categoryId;
  }

  @override
  Widget build(BuildContext context) {
    final successList = [...data.successRateByCategory]
      ..sort((a, b) => b.successRatePercent.compareTo(a.successRatePercent));
    final durationList = [...data.avgDurationByCategory]
      ..sort((a, b) => b.avgDurationMinutes.compareTo(a.avgDurationMinutes));

    if (successList.isEmpty && durationList.isEmpty) {
      return const InsightCard(
        child: Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text(
            'Not enough sessions yet.',
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
            'Success & Duration by Category',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 14),
          if (successList.isNotEmpty) ...[
            const Text(
              'Success rate',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 10),
            for (final e in successList.take(4)) ...[
              _SuccessRow(
                label: _categoryLabel(e.categoryId),
                successRatePercent: e.successRatePercent,
                sampleCount: e.count,
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 14),
          if (durationList.isNotEmpty) ...[
            const Text(
              'Average duration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 10),
            for (final e in durationList.take(4)) ...[
              _DurationRow(
                label: _categoryLabel(e.categoryId),
                avgDurationMinutes: e.avgDurationMinutes,
                sampleCount: e.count,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  const _SuccessRow({
    required this.label,
    required this.successRatePercent,
    required this.sampleCount,
  });

  final String label;
  final double successRatePercent;
  final int sampleCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CupertinoColors.label,
                      ),
                    ),
                  ),
                  Text(
                    '${successRatePercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'n=$sampleCount',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.tertiaryLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _MetricBar(
                value: (successRatePercent / 100).clamp(0.0, 1.0),
                color: CupertinoColors.systemGreen,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.label,
    required this.avgDurationMinutes,
    required this.sampleCount,
  });

  final String label;
  final double avgDurationMinutes;
  final int sampleCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: CupertinoColors.label,
                      ),
                    ),
                  ),
                  Text(
                    '${avgDurationMinutes.toStringAsFixed(0)}m',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'n=$sampleCount',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.tertiaryLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _MetricBar(
                value: (avgDurationMinutes / 90).clamp(0.0, 1.0),
                color: CupertinoColors.activeBlue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: CupertinoColors.systemGrey5),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

