/// Extracts structured distraction/intensity tags from free-text reflections.
///
/// This is intentionally heuristic-based for now (Phase 3 foundation).
/// Later, the tag extraction can be swapped with an embedding/text model
/// without changing consumers by keeping the public API stable.
library reflection_tag_extractor;

enum ReflectionTag {
  tired,
  phone,
  stress,
  school,
  noise,
  motivation,
  procrastination,
  happy,
  focused,
}

class ReflectionTagRule {
  const ReflectionTagRule({
    required this.tag,
    required this.patterns,
  });

  final ReflectionTag tag;
  final List<RegExp> patterns;
}

/// Simple keyword-based tag extractor.
class ReflectionTagExtractor {
  ReflectionTagExtractor({
    List<ReflectionTagRule>? rules,
  }) : _rules = rules ?? _defaultRules;

  final List<ReflectionTagRule> _rules;

  static const Set<ReflectionTag> defaultDistractionTags = {
    ReflectionTag.tired,
    ReflectionTag.phone,
    ReflectionTag.stress,
    ReflectionTag.school,
    ReflectionTag.noise,
    ReflectionTag.procrastination,
  };

  /// Returns extracted tags (unique, in insertion order).
  List<ReflectionTag> extractTags(String text) {
    final normalized = text.toLowerCase();
    final out = <ReflectionTag>[];
    for (final rule in _rules) {
      final matches = rule.patterns.any((p) => p.hasMatch(normalized));
      if (matches) out.add(rule.tag);
    }
    return out;
  }

  static final List<ReflectionTagRule> _defaultRules = [
    ReflectionTagRule(
      tag: ReflectionTag.tired,
      patterns: [
        RegExp(r'\btired\b', caseSensitive: false),
        RegExp(r'\bexhausted\b', caseSensitive: false),
        RegExp(r'\bsleepy\b', caseSensitive: false),
        RegExp(r'\bfatigue\b', caseSensitive: false),
        RegExp(r'\bdrained\b', caseSensitive: false),
        RegExp(r'\bburnt\s*out\b', caseSensitive: false),
      ],
    ),
    ReflectionTagRule(
      tag: ReflectionTag.phone,
      patterns: [
        RegExp(r'\bphone\b', caseSensitive: false),
        RegExp(r'\bscroll(ing)?\b', caseSensitive: false),
        RegExp(r'\bnotification(s)?\b', caseSensitive: false),
        RegExp(r'\bmessage(s)?\b', caseSensitive: false),
      ],
    ),
    ReflectionTagRule(
      tag: ReflectionTag.stress,
      patterns: [
        RegExp(r'\bstress\b', caseSensitive: false),
        RegExp(r'\bstressed\b', caseSensitive: false),
        RegExp(r'\banxious\b', caseSensitive: false),
        RegExp(r'\banxiety\b', caseSensitive: false),
        RegExp(r'\boverwhelmed\b', caseSensitive: false),
        RegExp(r'\bpanic\b', caseSensitive: false),
      ],
    ),
    ReflectionTagRule(
      tag: ReflectionTag.school,
      patterns: [
        RegExp(r'\bschool\b', caseSensitive: false),
        RegExp(r'\bclass\b', caseSensitive: false),
        RegExp(r'\bhomework\b', caseSensitive: false),
        RegExp(r'\bassignment(s)?\b', caseSensitive: false),
        RegExp(r'\bexam(s)?\b', caseSensitive: false),
        RegExp(r'\bstudy(ing)?\b', caseSensitive: false),
      ],
    ),
    ReflectionTagRule(
      tag: ReflectionTag.noise,
      patterns: [
        RegExp(r'\bnoise\b', caseSensitive: false),
        RegExp(r'\bnoisy\b', caseSensitive: false),
        RegExp(r'\btraffic\b', caseSensitive: false),
        RegExp(r'\bconstruction\b', caseSensitive: false),
        RegExp(r'\btraffic\b', caseSensitive: false),
      ],
    ),
    ReflectionTagRule(
      tag: ReflectionTag.motivation,
      patterns: [
        RegExp(r'\bmotivation\b', caseSensitive: false),
        RegExp(r'\binspired\b', caseSensitive: false),
        RegExp(r'\bdiscipline\b', caseSensitive: false),
      ],
    ),
    ReflectionTagRule(
      tag: ReflectionTag.procrastination,
      patterns: [
        RegExp(r'\bprocrast(inate|ination)?\b', caseSensitive: false),
        RegExp(r'\bavo(i|id|iding|ids|idance)\b', caseSensitive: false),
        RegExp(r'\blater\b', caseSensitive: false),
        RegExp(r'\bdoom(scroll(ing)?)?\b', caseSensitive: false),
      ],
    ),
    ReflectionTagRule(
      tag: ReflectionTag.happy,
      patterns: [
        RegExp(r'\bhappy\b', caseSensitive: false),
        RegExp(r'\bjoy\b', caseSensitive: false),
        RegExp(r'\bgrateful\b', caseSensitive: false),
      ],
    ),
    ReflectionTagRule(
      tag: ReflectionTag.focused,
      patterns: [
        RegExp(r'\bfocused\b', caseSensitive: false),
        RegExp(r'\bdeep\s*work\b', caseSensitive: false),
        RegExp(r'\bflow\b', caseSensitive: false),
        RegExp(r'\bconcentrat', caseSensitive: false),
      ],
    ),
  ];
}

