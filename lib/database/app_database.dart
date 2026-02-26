import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// SQLite database for the app. Single place to open DB and run migrations.
/// Database file lives in app documents directory (e.g. iOS: NSDocumentDirectory).
class AppDatabase {
  AppDatabase._();

  static Database? _db;

  static const String _dbName = 'deep_work.db';
  static const int _version = 1;

  /// Returns the open database; opens it once and reuses.
  static Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final base = await getApplicationDocumentsDirectory();
    final path = join(base.path, _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(Schema.sessionsTable);
    await db.execute(Schema.indexStartedAt);
    await db.execute(Schema.indexCategory);
    await db.execute(Schema.indexOutcome);
  }

  /// Close the database (e.g. for tests). Safe to call multiple times.
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
