/// Simple chart-friendly DTOs.
///
/// Keep these in pure Dart (no Flutter widgets) so they are unit-test friendly.
class ChartSeriesDouble {
  const ChartSeriesDouble({
    required this.labels,
    required this.values,
    required this.maxY,
  });

  final List<String> labels;
  final List<double> values;
  final double maxY;

  factory ChartSeriesDouble.empty() {
    return const ChartSeriesDouble(
      labels: [],
      values: [],
      maxY: 0,
    );
  }
}

