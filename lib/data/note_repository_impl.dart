import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../domain/note.dart';
import '../domain/note_repository.dart';
import 'app_database.dart';

class NoteRepositoryImpl implements NoteRepository {
  static const String _tableName = AppDatabase.notesTable;

  Future<Database> get _database => AppDatabase.instance;

  @override
  Future<List<Note>> getNotes() async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'archivedAt IS NULL',
      orderBy: 'updatedAt DESC',
    );
    return maps.map((map) => Note.fromMap(map)).toList();
  }

  @override
  Future<List<Note>> getArchivedNotes() async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'archivedAt IS NOT NULL',
      orderBy: 'archivedAt DESC',
    );
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
  Future<void> archiveNote(String id) async {
    final db = await _database;
    await db.update(
      _tableName,
      {'archivedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> archiveNotes(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      _tableName,
      {'archivedAt': DateTime.now().toIso8601String()},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  @override
  Future<void> restoreNote(String id) async {
    final db = await _database;
    await db.update(
      _tableName,
      {'archivedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> purgeExpiredArchivedNotes(Duration maxAge) async {
    final cutoff = DateTime.now().subtract(maxAge);
    final archived = await getArchivedNotes();
    final expiredIds = archived
        .where((note) => note.archivedAt != null && note.archivedAt!.isBefore(cutoff))
        .map((note) => note.id)
        .toList();
    await deleteNotes(expiredIds);
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
    for (final path in [...note.photoPaths, ...note.voiceMemoPaths]) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
