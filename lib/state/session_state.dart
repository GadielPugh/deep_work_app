import 'package:flutter/foundation.dart';

import 'package:deep_work/database/session_repository.dart';
import 'package:deep_work/session_model.dart';

/// Global session state for the app.
///
/// - Keeps the in-memory list of all sessions.
/// - Notifies listeners when the list changes.
/// - Backed by SQLite via [SessionRepository].
///
/// This makes it easy for multiple screens (History, Insights, Home)
/// to react automatically when a new focus session is saved.
class SessionState extends ChangeNotifier {
  SessionState._();

  /// Single shared instance used across the app.
  static final SessionState instance = SessionState._();

  List<Session> _sessions = [];
  bool _isLoaded = false;

  List<Session> get sessions => _sessions;
  bool get isLoaded => _isLoaded;

  /// Load all sessions from the database.
  Future<void> load() async {
    _sessions = await SessionRepository.getAll();
    _isLoaded = true;
    notifyListeners();
  }

  /// Reload sessions (alias for [load]).
  Future<void> reload() => load();
}

