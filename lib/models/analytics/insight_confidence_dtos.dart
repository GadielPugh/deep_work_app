/// Confidence/trust metadata for insight cards.
///
/// This is computed in services (not widgets) so the UI can safely decide
/// whether to show or hide metrics based on sample sizes.
enum InsightConfidenceLevel {
  low,
  medium,
  high,
}

class InsightConfidenceDto {
  const InsightConfidenceDto({
    required this.level,
    required this.sampleCount,
    required this.isTrusted,
    required this.reason,
  });

  final InsightConfidenceLevel level;
  final int sampleCount;
  final bool isTrusted;
  final String reason;

  String get label {
    return switch (level) {
      InsightConfidenceLevel.low => 'Low confidence',
      InsightConfidenceLevel.medium => 'Medium confidence',
      InsightConfidenceLevel.high => 'High confidence',
    };
  }
}

