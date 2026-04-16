import 'package:deep_work/models/analytics/insights_analytics_dtos.dart';
import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/session_model.dart';

import 'reflection_tag_extractor.dart';

/// Local-only heuristics to extract reflection themes and clusters.
///
/// This is a Phase 3 foundation; later we can plug in:
/// - a future embedding-based similarity strategy
/// - or an on-device LiteRT/native text model
/// while keeping the same service API.
class ReflectionAnalyzerService {
  ReflectionAnalyzerService({
    required this.tagExtractor,
  });

  final ReflectionTagExtractor tagExtractor;

  /// Top recurring distraction themes from reflection text.
  ///
  /// By default, only considers "failure-ish" sessions (anything other than
  /// `CompletionStatus.yes`). This aligns with common ML targets: failure
  /// indicators.
  List<RecurringThemeDto> extractRecurringDistractionThemes({
    required List<Session> sessions,
    Set<ReflectionTag>? distractionTags,
    bool onlyFailures = true,
    int topN = 3,
  }) {
    final tagsToCount =
        distractionTags ?? ReflectionTagExtractor.defaultDistractionTags;

    final counts = <String, int>{};

    for (final s in sessions) {
      if (onlyFailures && s.outcome == CompletionStatus.yes) continue;
      final reflection = s.reflection;
      if (reflection == null || reflection.trim().isEmpty) continue;

      final extracted = tagExtractor.extractTags(reflection);
      final unique = extracted.toSet();
      for (final tag in unique) {
        if (!tagsToCount.contains(tag)) continue;
        final key = tag.name;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(topN)
        .map((e) => RecurringThemeDto(theme: e.key, count: e.value))
        .toList();
  }

  /// Groups similar reflections using a simple heuristic:
  /// - Extract tags
  /// - Extract top keywords
  /// - Use `sortedTags + keywords` as a cluster key
  ///
  /// This is intentionally lightweight and deterministic.
  List<ReflectionClusterDto> clusterReflections({
    required List<Session> sessions,
    int maxClusters = 6,
  }) {
    final countsByKey = <String, int>{};
    final labelsByKey = <String, String>{};

    for (final s in sessions) {
      final reflection = s.reflection;
      if (reflection == null || reflection.trim().isEmpty) continue;

      final extractedTags = tagExtractor.extractTags(reflection);
      final keywords = _topKeywords(reflection, limit: 3);

      final sortedTagNames = extractedTags.map((t) => t.name).toList()..sort();
      final signature = '${sortedTagNames.join(',')}|${keywords.join(',')}';

      countsByKey[signature] = (countsByKey[signature] ?? 0) + 1;

      labelsByKey[signature] ??= _labelForCluster(sortedTagNames, keywords);
    }

    final entries = countsByKey.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries
        .take(maxClusters)
        .map((e) => ReflectionClusterDto(
              label: labelsByKey[e.key] ?? 'Reflection cluster',
              count: e.value,
            ))
        .toList();
  }

  /// Summarizes common failure reasons from reflection text.
  ///
  /// This stays heuristic-based for now, but the signature is intentionally
  /// stable so the internals can later be replaced with an embedding-based
  /// or LiteRT text model approach.
  FailureReasonSummaryDto summarizeCommonFailureReasons({
    required List<Session> sessions,
    Set<ReflectionTag>? distractionTags,
    bool onlyFailures = true,
    int topDistractionThemes = 3,
    int topClusters = 2,
  }) {
    final themes = extractRecurringDistractionThemes(
      sessions: sessions,
      distractionTags: distractionTags,
      onlyFailures: onlyFailures,
      topN: topDistractionThemes,
    );

    final clusters = clusterReflections(
      sessions: sessions,
      maxClusters: topClusters,
    );

    if (themes.isEmpty && clusters.isEmpty) {
      return const FailureReasonSummaryDto(
        title: 'Common failure reasons',
        keyReasons: ['No failure reflections yet'],
      );
    }

    final reasons = <String>[];
    for (final t in themes) {
      reasons.add('${t.theme} appears ${t.count} time(s) in failure reflections');
    }
    for (final c in clusters) {
      reasons.add('${c.label} shows up ${c.count} time(s)');
    }

    return FailureReasonSummaryDto(
      title: 'Common failure reasons',
      keyReasons: reasons,
    );
  }

  /// Future LiteRT/native plug-in point:
  /// Replace `_topKeywords` and signature building with an embedding similarity
  /// approach, then map clusters back into `ReflectionClusterDto`.
  String _labelForCluster(List<String> sortedTagNames, List<String> keywords) {
    final distractionNames = sortedTagNames
        .where((t) => ReflectionTagExtractor.defaultDistractionTags.any((d) => d.name == t))
        .toList();
    if (distractionNames.isNotEmpty) return 'Distraction: ${distractionNames.join(', ')}';
    if (keywords.isNotEmpty) return 'Theme: ${keywords.first}';
    return 'Reflection cluster';
  }

  static final _stopwords = <String>{
    'the',
    'a',
    'an',
    'and',
    'or',
    'but',
    'to',
    'of',
    'in',
    'on',
    'for',
    'with',
    'without',
    'at',
    'from',
    'by',
    'it',
    'is',
    'was',
    'were',
    'be',
    'am',
    'are',
    'i',
    'me',
    'my',
    'you',
    'your',
    'we',
    'they',
    'them',
    'this',
    'that',
    'these',
    'those',
    'as',
    'so',
    'if',
    'then',
    'just',
    'very',
    'into',
    'out',
    'up',
    'down',
    'about',
  };

  List<String> _topKeywords(String text, {required int limit}) {
    final normalized = text.toLowerCase();
    final tokens = normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty && t.length >= 3)
        .where((t) => !_stopwords.contains(t))
        .toList();

    final counts = <String, int>{};
    for (final t in tokens) {
      counts[t] = (counts[t] ?? 0) + 1;
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(limit).map((e) => e.key).toList();
  }
}

