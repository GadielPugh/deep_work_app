import 'package:flutter/foundation.dart';

import 'package:deep_work/session_model.dart';
import 'package:deep_work/services/app_services.dart';

/// Central state for sessions. Single source of truth for the session list.
///
/// - Receives events: load, save session
/// - Uses [SessionStorageService] from [AppServices]
/// - Notifies listeners when state changes
class SessionsState extends ChangeNotifier {
  SessionsState._();

  static final SessionsState instance = SessionsState._();

  List<Session> _sessions = [];
  bool _isLoaded = false;

  List<Session> get sessions => _sessions;
  bool get isLoaded => _isLoaded;

  /// Event: load sessions from storage
  Future<void> load() async {
    _sessions = await AppServices.sessionStorage.getAllSessions();
    _isLoaded = true;
    notifyListeners();
  }

  /// Event: save a new session, then reload list
  Future<void> saveSession({
    required String intention,
    required String category,
    required DateTime startedAt,
    required DateTime stoppedAt,
    required int durationSeconds,
    required String outcome,
    String? reflection,
  }) async {
    await AppServices.sessionStorage.insertSession(
      intention: intention,
      category: category,
      startedAt: startedAt,
      stoppedAt: stoppedAt,
      durationSeconds: durationSeconds,
      outcome: outcome,
      reflection: reflection,
    );
    await load();
  }

  /// Alias for load (e.g. after external changes)
  Future<void> reload() => load();
}
