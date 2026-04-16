import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/insights_data.dart';

import 'insight_card.dart';

class PredictionWarningSection extends StatelessWidget {
  const PredictionWarningSection({super.key, required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    if (data.predictionWarning != null) {
      final w = data.predictionWarning!;
      return InsightCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: CupertinoColors.systemOrange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: CupertinoColors.label,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        w.message,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          color: CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        w.isCautiousFallback
                            ? 'Cautious fallback: ${w.recommendedCategoryName} • ${w.recommendedDurationMinutes} min • ${w.successProbabilityLabel}'
                            : 'Try: ${w.recommendedCategoryName} • ${w.recommendedDurationMinutes} min • ${w.successProbabilityLabel}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${w.confidence.label} • samples n=${w.sampleCount}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: CupertinoColors.tertiaryLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Why this may be a weak spot:',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 10),
            for (final r in w.riskFactors.take(6)) ...[
              Text(
                '• $r',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      );
    }

    // No warning, but we can explicitly show "not enough data" state.
    if (!data.predictionWarningConfidence.isTrusted) {
      final reason = data.predictionWarningConfidence.reason;
      return InsightCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prediction warning',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              reason,
              style: const TextStyle(
                fontSize: 14.5,
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Limited data • n=${data.predictionWarningConfidence.sampleCount}',
              style: const TextStyle(
                fontSize: 11.5,
                color: CupertinoColors.tertiaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

