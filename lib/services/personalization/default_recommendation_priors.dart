class DefaultRecommendationPriors {
  const DefaultRecommendationPriors();

  double categoryTimePrior({
    required String categoryId,
    required String categoryName,
    required String timeBlock,
  }) {
    final key = _normalize('$categoryId $categoryName');
    var score = 0.52;

    if (key.contains('coding') || key.contains('work')) {
      if (timeBlock == 'morning') score += 0.08;
      if (timeBlock == 'afternoon') score += 0.05;
      if (timeBlock == 'night') score -= 0.06;
    }
    if (key.contains('reading')) {
      if (timeBlock == 'morning') score += 0.04;
      if (timeBlock == 'night') score -= 0.08;
    }
    if (key.contains('writing')) {
      if (timeBlock == 'morning') score += 0.05;
      if (timeBlock == 'evening') score += 0.02;
    }
    if (key.contains('review')) {
      if (timeBlock == 'afternoon') score += 0.03;
      if (timeBlock == 'night') score -= 0.03;
    }

    return score.clamp(0.1, 0.9);
  }

  String defaultDurationBucket({
    required String categoryId,
    required String categoryName,
    required int totalSessions,
  }) {
    if (totalSessions < 3) return 'short';

    final key = _normalize('$categoryId $categoryName');
    if (key.contains('reading') || key.contains('review')) return 'short';
    return 'standard';
  }

  int durationMinutesForBucket(String bucket) {
    switch (bucket) {
      case 'short':
        return 15;
      case 'standard':
        return 25;
      case 'long':
        return 40;
      case 'extended':
        return 55;
      default:
        return 20;
    }
  }

  double durationBucketAdjustment({
    required String bucket,
    required int totalSessions,
  }) {
    if (totalSessions < 3 && bucket == 'short') return 0.06;
    if (totalSessions < 3 && bucket != 'short') return -0.05;
    if (bucket == 'extended') return -0.04;
    return 0.0;
  }

  String _normalize(String value) => value.trim().toLowerCase();
}
