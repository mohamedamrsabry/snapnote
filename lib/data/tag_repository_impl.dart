import 'package:sqflite/sqflite.dart';

import '../domain/tag.dart';
import '../domain/tag_repository.dart';
import 'app_database.dart';

class TagRepositoryImpl implements TagRepository {
  static const String _tableName = AppDatabase.tagsTable;

  @override
  Future<List<Tag>> getTags() async {
    final db = await AppDatabase.instance;
    final maps = await db.query(_tableName);
    return maps
        .map(
          (map) => Tag(
            name: map['name'] as String,
            colorValue: map['colorValue'] as int,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveTag(Tag tag) async {
    final db = await AppDatabase.instance;
    await db.insert(
      _tableName,
      {'name': tag.name, 'colorValue': tag.colorValue},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
