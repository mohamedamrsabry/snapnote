import 'dart:convert';

import 'note_block.dart';

class Note {
  final String id;
  final String title;
  // A Quill Delta document, JSON-encoded (the output of
  // jsonEncode(document.toDelta().toJson())). This is the single source of
  // truth for the note's content — text, photos, and voice memos all live
  // inline in one document. Photos are represented as an embed operation
  // {'insert': {'image': '<file path>'}}; voice memos as
  // {'insert': {'audio': '<json-encoded {path, transcript}>'}}. Deliberately
  // NOT using Quill's CustomBlockEmbed/BlockEmbed.custom wrapper for audio —
  // that double-encodes the payload as JSON-inside-JSON for no benefit here,
  // since 'audio' doesn't collide with Quill's own built-in embed types.
  final String quillJson;
  final List<String> tags;
  final bool isPinned;
  final bool isLocked;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  static const String emptyQuillJson = '[{"insert":"\\n"}]';

  Note({
    required this.id,
    required this.title,
    this.quillJson = emptyQuillJson,
    this.tags = const [],
    this.isPinned = false,
    this.isLocked = false,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  List<Map<String, dynamic>> get _ops {
    try {
      return (jsonDecode(quillJson) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  // A plain-text view of the note's content (attachments excluded), used
  // for search matching and list/gallery previews — kept in sync
  // automatically since it's derived from quillJson rather than stored
  // independently.
  String get body {
    final buffer = StringBuffer();
    for (final op in _ops) {
      final insert = op['insert'];
      if (insert is String) buffer.write(insert);
    }
    return buffer.toString().trim();
  }

  List<String> get photoPaths {
    final paths = <String>[];
    for (final op in _ops) {
      final insert = op['insert'];
      if (insert is Map && insert['image'] is String) {
        paths.add(insert['image'] as String);
      }
    }
    return paths;
  }

  List<String> get voiceMemoPaths {
    final paths = <String>[];
    for (final op in _ops) {
      final insert = op['insert'];
      if (insert is Map && insert['audio'] is String) {
        try {
          final payload =
              jsonDecode(insert['audio'] as String) as Map<String, dynamic>;
          final path = payload['path'] as String?;
          if (path != null && path.isNotEmpty) paths.add(path);
        } catch (_) {
          // Malformed embed payload — skip it rather than fail the whole
          // note.
        }
      }
    }
    return paths;
  }

  // Whether this note contains at least one checklist line. Drives the
  // "Notes with Checklists" search filter.
  bool get hasChecklist {
    for (final op in _ops) {
      final attrs = op['attributes'];
      if (attrs is Map &&
          (attrs['list'] == 'checked' || attrs['list'] == 'unchecked')) {
        return true;
      }
    }
    return false;
  }

  Note copyWith({
    String? title,
    String? quillJson,
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
      quillJson: quillJson ?? this.quillJson,
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
      'quillJson': quillJson,
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
    var quillJson = map['quillJson'] as String? ?? '';
    if (quillJson.isEmpty) {
      // Saved before the rich-text editor existed: reconstruct an
      // equivalent Quill document from the old block list (or, for a note
      // saved even before blocks existed, from the flat legacy fields) so
      // nothing already on a device gets lost.
      final blocksJson = map['blocksJson'] as String? ?? '';
      List<NoteBlock> legacyBlocks;
      if (blocksJson.isNotEmpty && blocksJson != '[]') {
        legacyBlocks = (jsonDecode(blocksJson) as List)
            .map((e) => NoteBlock.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        final legacyBody = map['body'] as String? ?? '';
        final legacyPhotoPaths = (map['photoPaths'] as String? ?? '').isEmpty
            ? <String>[]
            : (map['photoPaths'] as String).split(',');
        final legacyVoiceMemoPath = map['voiceMemoPath'] as String?;
        var counter = 0;
        String nextId() => '${map['id']}-legacy-${counter++}';
        legacyBlocks = [
          if (legacyBody.isNotEmpty)
            NoteBlock.text(id: nextId(), text: legacyBody),
          for (final path in legacyPhotoPaths)
            NoteBlock.photo(id: nextId(), path: path),
          if (legacyVoiceMemoPath != null)
            NoteBlock.audio(id: nextId(), path: legacyVoiceMemoPath),
        ];
      }
      quillJson = _quillJsonFromLegacyBlocks(legacyBlocks);
    }

    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      quillJson: quillJson,
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

  static String _quillJsonFromLegacyBlocks(List<NoteBlock> blocks) {
    final ops = <Map<String, dynamic>>[];
    for (final block in blocks) {
      switch (block.type) {
        case NoteBlockType.text:
          if (block.text.isNotEmpty) {
            final attrs = <String, dynamic>{};
            if (block.bold) attrs['bold'] = true;
            if (block.italic) attrs['italic'] = true;
            ops.add({
              'insert': block.text,
              if (attrs.isNotEmpty) 'attributes': attrs,
            });
          }
          ops.add({'insert': '\n'});
        case NoteBlockType.photo:
          if (block.path.isNotEmpty) {
            ops.add({
              'insert': {'image': block.path},
            });
            ops.add({'insert': '\n'});
          }
        case NoteBlockType.audio:
          if (block.path.isNotEmpty) {
            final payload = jsonEncode({
              'path': block.path,
              'transcript': block.transcript,
            });
            ops.add({
              'insert': {'audio': payload},
            });
            ops.add({'insert': '\n'});
          }
      }
    }
    if (ops.isEmpty) ops.add({'insert': '\n'});
    return jsonEncode(ops);
  }
}
