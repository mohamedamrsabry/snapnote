import 'dart:io';

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
    final note = await getNoteById(id);
    if (note != null) {
      await _deleteAttachmentFiles(note);
    }

    final db = await _database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteNotes(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final maps = await db.query(
      _tableName,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    for (final map in maps) {
      await _deleteAttachmentFiles(Note.fromMap(map));
    }

    await db.delete(_tableName, where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<void> _deleteAttachmentFiles(Note note) async {
    for (final path in note.photoPaths) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final voiceMemoPath = note.voiceMemoPath;
    if (voiceMemoPath != null) {
      final file = File(voiceMemoPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
