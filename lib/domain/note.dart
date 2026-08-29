import 'dart:convert';

import 'note_block.dart';

class Note {
  final String id;
  final String title;
  final List<NoteBlock> blocks;
  final List<String> tags;
  final bool isPinned;
  final bool isLocked;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  Note({
    required this.id,
    required this.title,
    this.blocks = const [],
    this.tags = const [],
    this.isPinned = false,
    this.isLocked = false,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  // A plain-text view of the note's content, used for search matching and
  // list/gallery previews — kept in sync automatically since it's derived
  // from blocks rather than stored independently.
  String get body => blocks
      .where((b) => b.type == NoteBlockType.text)
      .map((b) => b.text)
      .where((t) => t.isNotEmpty)
      .join('\n');

  List<String> get photoPaths => blocks
      .where((b) => b.type == NoteBlockType.photo)
      .map((b) => b.path)
      .toList();

  List<String> get voiceMemoPaths => blocks
      .where((b) => b.type == NoteBlockType.audio)
      .map((b) => b.path)
      .where((p) => p.isNotEmpty)
      .toList();

  Note copyWith({
    String? title,
    List<NoteBlock>? blocks,
    List<String>? tags,
    bool? isPinned,
    bool? isLocked,
    int? colorValue,
    DateTime? updatedAt,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      blocks: blocks ?? this.blocks,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'blocksJson': jsonEncode(blocks.map((b) => b.toJson()).toList()),
      'photoPaths': photoPaths.join(','),
      'voiceMemoPath': voiceMemoPaths.isEmpty ? null : voiceMemoPaths.first,
      'tags': tags.join(','),
      'isPinned': isPinned ? 1 : 0,
      'isLocked': isLocked ? 1 : 0,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'archivedAt': archivedAt?.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    final blocksJson = map['blocksJson'] as String? ?? '';
    List<NoteBlock> blocks;
    if (blocksJson.isNotEmpty && blocksJson != '[]') {
      blocks = (jsonDecode(blocksJson) as List)
          .map((e) => NoteBlock.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // Legacy note saved before blocks existed — reconstruct a reasonable
      // block sequence from the old flat fields so nothing is lost.
      final legacyBody = map['body'] as String? ?? '';
      final legacyPhotoPaths = (map['photoPaths'] as String? ?? '').isEmpty
          ? <String>[]
          : (map['photoPaths'] as String).split(',');
      final legacyVoiceMemoPath = map['voiceMemoPath'] as String?;
      var counter = 0;
      String nextId() => '${map['id']}-legacy-${counter++}';
      blocks = [
        if (legacyBody.isNotEmpty) NoteBlock.text(id: nextId(), text: legacyBody),
        for (final path in legacyPhotoPaths)
          NoteBlock.photo(id: nextId(), path: path),
        if (legacyVoiceMemoPath != null)
          NoteBlock.audio(id: nextId(), path: legacyVoiceMemoPath),
      ];
    }

    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      blocks: blocks,
      tags: (map['tags'] as String).isEmpty
          ? []
          : (map['tags'] as String).split(','),
      isPinned: (map['isPinned'] as int) == 1,
      isLocked: (map['isLocked'] as int) == 1,
      colorValue: map['colorValue'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      archivedAt: map['archivedAt'] == null
          ? null
          : DateTime.parse(map['archivedAt'] as String),
    );
  }
}
