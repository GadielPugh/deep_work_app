import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/insights_data.dart';
import 'package:deep_work/state/categories_state.dart';

import 'insight_card.dart';

class StreaksSummarySection extends StatelessWidget {
  const StreaksSummarySection({super.key, required this.data});

  final InsightsData data;

  String _categoryLabel(String categoryId) {
    return CategoriesState.instance.byId(categoryId)?.name ?? categoryId;
  }

  @override
  Widget build(BuildContext context) {
    final streaks = data.streaks;
    if (streaks == null) {
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

    final topCats = streaks.currentCategorySuccessStreaks.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCatsNonZero = topCats.where((e) => e.value > 0).take(3).toList();

    if (streaks.currentSuccessStreak == 0 &&
        streaks.maxSuccessStreak == 0 &&
        topCatsNonZero.isEmpty) {
      return const InsightCard(
        child: Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text(
            'Pattern not stable yet.',
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
            'Streaks',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                label: 'Current',
                value: '${streaks.currentSuccessStreak}',
                color: CupertinoColors.systemGreen,
              ),
              const SizedBox(width: 14),
              _MiniStat(
                label: 'Max',
                value: '${streaks.maxSuccessStreak}',
                color: CupertinoColors.activeBlue,
              ),
            ],
          ),
          if (topCatsNonZero.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Current category streaks',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 10),
            for (final e in topCatsNonZero) ...[
              _CategoryStreakRow(
                label: _categoryLabel(e.key),
                streak: e.value,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryStreakRow extends StatelessWidget {
  const _CategoryStreakRow({
    required this.label,
    required this.streak,
  });

  final String label;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          'x$streak',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: CupertinoColors.systemGreen,
          ),
        ),
      ],
    );
  }
}

