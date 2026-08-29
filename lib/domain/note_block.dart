enum NoteBlockType { text, photo, audio }

class NoteBlock {
  final String id;
  final NoteBlockType type;
  final String text;
  final bool bold;
  final bool italic;
  final String path;
  // Only ever set on an audio block, and only until the user commits or
  // discards it — a pending speech-to-text result waiting to become a
  // real text block. Deliberately not read by Note.body, so it stays out
  // of search/previews/share until it's actually committed.
  final String transcript;

  const NoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.bold = false,
    this.italic = false,
    this.path = '',
    this.transcript = '',
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

  factory NoteBlock.audio({
    required String id,
    String path = '',
    String transcript = '',
  }) {
    return NoteBlock(
      id: id,
      type: NoteBlockType.audio,
      path: path,
      transcript: transcript,
    );
  }

  NoteBlock copyWith({
    String? text,
    bool? bold,
    bool? italic,
    String? path,
    String? transcript,
    bool clearTranscript = false,
  }) {
    return NoteBlock(
      id: id,
      type: type,
      text: text ?? this.text,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      path: path ?? this.path,
      transcript: clearTranscript ? '' : (transcript ?? this.transcript),
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
      'transcript': transcript,
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
      transcript: json['transcript'] as String? ?? '',
    );
  }
}
