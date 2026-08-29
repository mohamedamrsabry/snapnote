enum NoteBlockType { text, photo, audio }

class NoteBlock {
  final String id;
  final NoteBlockType type;
  final String text;
  final bool bold;
  final bool italic;
  final String path;

  const NoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.bold = false,
    this.italic = false,
    this.path = '',
  });

  factory NoteBlock.text({
    required String id,
    String text = '',
    bool bold = false,
    bool italic = false,
  }) {
    return NoteBlock(
      id: id,
      type: NoteBlockType.text,
      text: text,
      bold: bold,
      italic: italic,
    );
  }

  factory NoteBlock.photo({required String id, required String path}) {
    return NoteBlock(id: id, type: NoteBlockType.photo, path: path);
  }

  factory NoteBlock.audio({required String id, String path = ''}) {
    return NoteBlock(id: id, type: NoteBlockType.audio, path: path);
  }

  NoteBlock copyWith({String? text, bool? bold, bool? italic, String? path}) {
    return NoteBlock(
      id: id,
      type: type,
      text: text ?? this.text,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      path: path ?? this.path,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'text': text,
      'bold': bold,
      'italic': italic,
      'path': path,
    };
  }

  factory NoteBlock.fromJson(Map<String, dynamic> json) {
    return NoteBlock(
      id: json['id'] as String,
      type: NoteBlockType.values.byName(json['type'] as String),
      text: json['text'] as String? ?? '',
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      path: json['path'] as String? ?? '',
    );
  }
}
