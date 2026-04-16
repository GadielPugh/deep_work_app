import 'package:flutter/foundation.dart';

import 'package:deep_work/models/completion_status.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/state/sessions_state.dart';

/// State Management for the History/Sessions page.
///
/// - Receives events: load, setFilterType, setFilterCompletion, setSearch
/// - Uses [SessionsState] for session list
/// - Exposes filtered list to UI
class SessionsPageState extends ChangeNotifier {
  SessionsPageState._() {
    SessionsState.instance.addListener(_onSessionsChanged);
  }

  static SessionsPageState? _instance;
  static SessionsPageState get instance {
    _instance ??= SessionsPageState._();
    return _instance!;
  }

  void _onSessionsChanged() {
    _applyFilters();
  }

  String? _filterCategoryId;
  CompletionStatus? _filterCompletion;
  String _searchQuery = '';

  List<Session> _filteredSessions = [];

  String? get filterCategoryId => _filterCategoryId;
  CompletionStatus? get filterCompletion => _filterCompletion;
  String get searchQuery => _searchQuery;
  List<Session> get filteredSessions => _filteredSessions;

  /// Event: load sessions (delegates to SessionsState)
  Future<void> load() async {
    if (SessionsState.instance.isLoaded) {
      _applyFilters();
    } else {
      await SessionsState.instance.load();
    }
  }

  /// Event: set session type filter
  void setFilterCategoryId(String? categoryId) {
    _filterCategoryId = categoryId;
    _applyFilters();
  }

  /// Event: set completion status filter
  void setFilterCompletion(CompletionStatus? status) {
    _filterCompletion = status;
    _applyFilters();
  }

  /// Event: set search query
  void setSearch(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void _applyFilters() {
    final all = SessionsState.instance.sessions;
    _filteredSessions = all.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.intention.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _filterCategoryId == null || s.categoryId == _filterCategoryId;
      final matchesCompletion = _filterCompletion == null || s.outcome == _filterCompletion;
      return matchesSearch && matchesType && matchesCompletion;
    }).toList();
    notifyListeners();
  }

  /// Call when disposing the page (e.g. to avoid leaks in tests)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }

  @override
  void dispose() {
    SessionsState.instance.removeListener(_onSessionsChanged);
    super.dispose();
  }
}
