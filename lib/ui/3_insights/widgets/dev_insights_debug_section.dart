import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/analytics/insights_debug_info_dtos.dart';
import 'package:deep_work/models/analytics/predictor_evaluation_dtos.dart';

import 'insight_card.dart';

class DevInsightsDebugSection extends StatefulWidget {
  const DevInsightsDebugSection({super.key, required this.debugInfo});

  final InsightsDebugInfoDto debugInfo;

  @override
  State<DevInsightsDebugSection> createState() => _DevInsightsDebugSectionState();
}

class _DevInsightsDebugSectionState extends State<DevInsightsDebugSection> {
  bool _expanded = false;

  String _pct(double p) => '${(p * 100).toStringAsFixed(0)}%';

  String _score(double v) => v.toStringAsFixed(3);

  @override
  Widget build(BuildContext context) {
    final d = widget.debugInfo;

    final ruleOverall = d.evaluationSummary.ruleBased.overall;
    final baselineRollOverall =
        d.evaluationSummary.baselineRollingCategoryOnly.overall;
    final baselineGlobalOverall = d.evaluationSummary.baselineGlobalOnly.overall;

    final ruleByCategoryEntries = d.evaluationSummary.ruleBased.byCategory.entries
        .toList()
      ..sort((a, b) => b.value.totalCount.compareTo(a.value.totalCount));

    return InsightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.chevron_right_circle,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dev debug: predictor evaluation',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.label,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Hide' : 'Show'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_expanded) ...[
            Text(
              'Rule vs baselines (Brier): ${d.ruleBeatsBaselines ? 'better than or equal to' : 'not better than'} baselines',
              style: const TextStyle(
                fontSize: 12.5,
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            Text(
              'Sessions: n=${d.totalSessionCount} • Prediction confidence: ${d.predictionConfidence.label} (n=${d.predictionConfidence.sampleCount})',
              style: const TextStyle(
                fontSize: 12.5,
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Predicted success probability: ${_pct(d.predictedSuccessProbability)}',
              style: const TextStyle(
                fontSize: 14.5,
                color: CupertinoColors.label,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Top predictor reasons:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 6),
            for (final r in d.predictionReasons.take(5)) ...[
              Text(
                '• $r',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 12),
            const Text(
              'Offline evaluation (no future leakage)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 10),
            _EvalBlock(
              title: 'Rule-based',
              overall: ruleOverall,
            ),
            const SizedBox(height: 10),
            _EvalBlock(
              title: 'Baseline: rolling category',
              overall: baselineRollOverall,
            ),
            const SizedBox(height: 10),
            _EvalBlock(
              title: 'Baseline: global success',
              overall: baselineGlobalOverall,
            ),
            const SizedBox(height: 12),
            if (ruleByCategoryEntries.isNotEmpty) ...[
              const Text(
                'By-category (rule-based, top 3 by samples)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 10),
              for (final e in ruleByCategoryEntries.take(3)) ...[
                Text(
                  '${e.key}: n=${e.value.totalCount}, F1=${_score(e.value.f1)}, Brier=${_score(e.value.brierScore)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _EvalBlock extends StatelessWidget {
  const _EvalBlock({
    required this.title,
    required this.overall,
  });

  final String title;
  final BinaryClassificationMetricsDto overall;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: CupertinoColors.label,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Acc=${overall.accuracy.toStringAsFixed(2)} • P=${overall.precision.toStringAsFixed(2)} • R=${overall.recall.toStringAsFixed(2)} • F1=${overall.f1.toStringAsFixed(2)} • Brier=${overall.brierScore.toStringAsFixed(3)} • n=${overall.totalCount}',
          style: const TextStyle(
            fontSize: 13.5,
            color: CupertinoColors.secondaryLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

