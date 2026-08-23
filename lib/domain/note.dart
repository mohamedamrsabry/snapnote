class Note {
  final String id;
  final String title;
  final String body;
  final List<String> photoPaths;
  final String? voiceMemoPath;
  final List<String> tags;
  final bool isPinned;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.body,
    this.photoPaths = const [],
    this.voiceMemoPath,
    this.tags = const [],
    this.isPinned = false,
    this.isLocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Note copyWith({
    String? title,
    String? body,
    List<String>? photoPaths,
    String? voiceMemoPath,
    List<String>? tags,
    bool? isPinned,
    bool? isLocked,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      photoPaths: photoPaths ?? this.photoPaths,
      voiceMemoPath: voiceMemoPath ?? this.voiceMemoPath,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'photoPaths': photoPaths.join(','),
      'voiceMemoPath': voiceMemoPath,
      'tags': tags.join(','),
      'isPinned': isPinned ? 1 : 0,
      'isLocked': isLocked ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      photoPaths: (map['photoPaths'] as String).isEmpty
          ? []
          : (map['photoPaths'] as String).split(','),
      voiceMemoPath: map['voiceMemoPath'] as String?,
      tags: (map['tags'] as String).isEmpty
          ? []
          : (map['tags'] as String).split(','),
      isPinned: (map['isPinned'] as int) == 1,
      isLocked: (map['isLocked'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
