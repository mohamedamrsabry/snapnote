import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String notesTable = 'notes';
  static const String tagsTable = 'tags';
  static const int _defaultLegacyColorValue = 0xFF8E8E93;
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'snapnote.db');

    _db = await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $notesTable (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            photoPaths TEXT NOT NULL,
            voiceMemoPath TEXT,
            tags TEXT NOT NULL,
            isPinned INTEGER NOT NULL,
            isLocked INTEGER NOT NULL,
            colorValue INTEGER NOT NULL,
            blocksJson TEXT NOT NULL DEFAULT '[]',
            quillJson TEXT NOT NULL DEFAULT '',
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            archivedAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE $tagsTable (
            name TEXT PRIMARY KEY,
            colorValue INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE $tagsTable (
              name TEXT PRIMARY KEY,
              colorValue INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE $notesTable ADD COLUMN colorValue INTEGER NOT NULL DEFAULT $_defaultLegacyColorValue',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE $notesTable ADD COLUMN blocksJson TEXT NOT NULL DEFAULT '[]'",
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE $notesTable ADD COLUMN archivedAt TEXT',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            "ALTER TABLE $notesTable ADD COLUMN quillJson TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
    return _db!;
  }
}
