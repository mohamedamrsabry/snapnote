import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/note.dart';
import '../domain/note_repository.dart';

class NoteRepositoryImpl implements NoteRepository {
  static const String _tableName = 'notes';
  static Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'snapnote.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            photoPaths TEXT NOT NULL,
            voiceMemoPath TEXT,
            tags TEXT NOT NULL,
            isPinned INTEGER NOT NULL,
            isLocked INTEGER NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  @override
  Future<List<Note>> getNotes() async {
    final db = await _database;
    final maps = await db.query(_tableName, orderBy: 'updatedAt DESC');
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final db = await _database;
    final maps = await db.query(_tableName, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  @override
  Future<void> addNote(Note note) async {
    final db = await _database;
    await db.insert(
      _tableName,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateNote(Note note) async {
    final db = await _database;
    await db.update(
      _tableName,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  @override
  Future<void> deleteNote(String id) async {
    final db = await _database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
