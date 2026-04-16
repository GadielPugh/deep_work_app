import 'package:flutter/foundation.dart';

import 'package:deep_work/models/insights_data.dart';
import 'package:deep_work/state/categories_state.dart';
import 'package:deep_work/state/sessions_state.dart';
import 'package:deep_work/services/analytics/insights_analytics_service.dart';

/// State Management for the Insights page.
///
/// - Receives events: load
/// - Uses [SessionsState] for session list
/// - Computes chart and stats data from sessions
class InsightsPageState extends ChangeNotifier {
  InsightsPageState._() {
    SessionsState.instance.addListener(_onSessionsChanged);
    CategoriesState.instance.addListener(_onSessionsChanged);
  }

  static final InsightsPageState instance = InsightsPageState._();

  final InsightsAnalyticsService _analyticsService = InsightsAnalyticsService();

  void _onSessionsChanged() {
    _compute();
  }

  InsightsData _data = InsightsData.empty();

  InsightsData get data => _data;

  Future<void> load() async {
    if (!SessionsState.instance.isLoaded) {
      await SessionsState.instance.load();
    }
    if (!CategoriesState.instance.isLoaded) {
      await CategoriesState.instance.load();
    }
    _compute();
  }

  void _compute() {
    if (!SessionsState.instance.isLoaded || !CategoriesState.instance.isLoaded) return;

    final sessions = SessionsState.instance.sessions;
    final categories = CategoriesState.instance.categories;

    _data = _analyticsService.computeInsightsData(
      sessions: sessions,
      categories: categories,
      now: DateTime.now(),
      includeDebugEvaluation: kDebugMode,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    SessionsState.instance.removeListener(_onSessionsChanged);
    CategoriesState.instance.removeListener(_onSessionsChanged);
    super.dispose();
  }
}
