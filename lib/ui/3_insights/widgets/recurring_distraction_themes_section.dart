import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/insights_data.dart';

import 'insight_card.dart';

class RecurringDistractionThemesSection extends StatelessWidget {
  const RecurringDistractionThemesSection({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final themes = data.recurringDistractionThemes;

    if (themes.isEmpty) {
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
            'Recurring distraction themes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Recent failed sessions sometimes mention:',
            style: TextStyle(
              fontSize: 11.5,
              color: CupertinoColors.tertiaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (final t in themes) ...[
            _ThemeRow(theme: t.theme, count: t.count),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.theme, required this.count});

  final String theme;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          CupertinoIcons.sparkles,
          size: 18,
          color: CupertinoColors.systemOrange,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            theme,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.label,
            ),
          ),
        ),
        Text(
          'n=$count',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.tertiaryLabel,
          ),
        ),
      ],
    );
  }
}

