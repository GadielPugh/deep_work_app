import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/analytics/insights_analytics_dtos.dart';
import 'package:deep_work/models/insights_data.dart';
import 'package:deep_work/state/categories_state.dart';

import 'insight_card.dart';

class BestWorstHoursSection extends StatelessWidget {
  const BestWorstHoursSection({super.key, required this.data});

  final InsightsData data;

  String _hourLabel(int hour) {
    final h = hour.clamp(0, 23);
    return '${h.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    final trusted = data.bestWorstHoursByCategory
        .where((e) => e.confidence.isTrusted)
        .toList();

    if (trusted.isEmpty) {
      return InsightCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Best & Worst Hours',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.bestWorstHoursByCategory.isNotEmpty
                  ? data.bestWorstHoursByCategory.first.confidence.reason
                  : 'Not enough sessions yet.',
              style: const TextStyle(
                fontSize: 14.5,
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    trusted.sort((a, b) => b.bestSuccessRatePercent.compareTo(a.bestSuccessRatePercent));

    return InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Best & Worst Hours',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 14),
          for (final e in trusted.take(4)) ...[
            _CategoryExtremaRow(extrema: e, hourLabel: _hourLabel),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CategoryExtremaRow extends StatelessWidget {
  const _CategoryExtremaRow({
    required this.extrema,
    required this.hourLabel,
  });

  final CategoryHourExtremaDto extrema;
  final String Function(int hour) hourLabel;

  @override
  Widget build(BuildContext context) {
    final categoryLabel =
        CategoriesState.instance.byId(extrema.categoryId)?.name ?? extrema.categoryId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          categoryLabel,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: CupertinoColors.label,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Best: ${hourLabel(extrema.bestHour)} (${extrema.bestSuccessRatePercent.toStringAsFixed(0)}%) • Worst: ${hourLabel(extrema.worstHour)} (${extrema.worstSuccessRatePercent.toStringAsFixed(0)}%)',
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.25,
            color: CupertinoColors.secondaryLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${extrema.confidence.label} • n=${extrema.sampleCount} • best hour n=${extrema.bestHourSampleCount}, worst hour n=${extrema.worstHourSampleCount}',
          style: const TextStyle(
            fontSize: 11.5,
            color: CupertinoColors.tertiaryLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

