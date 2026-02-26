
class Schema {
  Schema._();

  /// One row per focus session. All fields needed for analytics and ML training.

  static const String sessionsTable = '''
CREATE TABLE sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  intention TEXT NOT NULL,
  category TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  stopped_at_ms INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL,
  outcome TEXT NOT NULL,
  reflection TEXT,
  created_at_ms INTEGER NOT NULL
)
''';

  static const String indexStartedAt = 'CREATE INDEX idx_sessions_started_at ON sessions(started_at_ms)';
  static const String indexCategory = 'CREATE INDEX idx_sessions_category ON sessions(category)';
  static const String indexOutcome = 'CREATE INDEX idx_sessions_outcome ON sessions(outcome)';
}
