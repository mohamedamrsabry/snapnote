import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapnote/domain/note.dart';

Note _note({String quillJson = Note.emptyQuillJson}) {
  final now = DateTime(2026, 1, 1);
  return Note(
    id: 'n1',
    title: 'Test',
    quillJson: quillJson,
    colorValue: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Map<String, dynamic> _legacyMap({
  String body = '',
  String photoPaths = '',
  String? voiceMemoPath,
  String blocksJson = '[]',
}) {
  final now = DateTime(2026, 1, 1).toIso8601String();
  return {
    'id': 'legacy1',
    'title': 'Old note',
    'quillJson': '',
    'blocksJson': blocksJson,
    'body': body,
    'photoPaths': photoPaths,
    'voiceMemoPath': voiceMemoPath,
    'tags': '',
    'isPinned': 0,
    'isLocked': 0,
    'colorValue': 0,
    'createdAt': now,
    'updatedAt': now,
    'archivedAt': null,
  };
}

void main() {
  group('Note content derived from quillJson', () {
    test('body concatenates only the plain-text inserts, trimmed', () {
      final delta = jsonEncode([
        {'insert': 'Hello '},
        {'insert': 'world'},
        {
          'insert': {'image': '/some/photo.jpg'},
        },
        {'insert': '\n'},
      ]);

      final note = _note(quillJson: delta);

      expect(note.body, 'Hello world');
    });

    test('photoPaths collects every image embed in document order', () {
      final delta = jsonEncode([
        {
          'insert': {'image': '/a.jpg'},
        },
        {'insert': 'text between\n'},
        {
          'insert': {'image': '/b.jpg'},
        },
      ]);

      final note = _note(quillJson: delta);

      expect(note.photoPaths, ['/a.jpg', '/b.jpg']);
    });

    test('voiceMemoPaths decodes the JSON-encoded audio payload', () {
      final audioPayload = jsonEncode({
        'id': 'audio1',
        'path': '/memo.m4a',
        'transcript': '',
      });
      final delta = jsonEncode([
        {
          'insert': {'audio': audioPayload},
        },
      ]);

      final note = _note(quillJson: delta);

      expect(note.voiceMemoPaths, ['/memo.m4a']);
    });

    test('voiceMemoPaths skips a malformed audio payload instead of throwing', () {
      final delta = jsonEncode([
        {
          'insert': {'audio': 'not valid json'},
        },
      ]);

      final note = _note(quillJson: delta);

      expect(note.voiceMemoPaths, isEmpty);
    });

    test('hasChecklist is true only when a line has a checked/unchecked attribute', () {
      final withChecklist = jsonEncode([
        {'insert': 'Buy milk'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
      ]);
      final withoutChecklist = jsonEncode([
        {'insert': 'Just text\n'},
      ]);

      expect(_note(quillJson: withChecklist).hasChecklist, isTrue);
      expect(_note(quillJson: withoutChecklist).hasChecklist, isFalse);
    });
  });

  group('Note.fromMap legacy migration (pre-quill notes)', () {
    test('reconstructs an equivalent delta from flat legacy fields', () {
      final map = _legacyMap(
        body: 'Legacy body text',
        photoPaths: '/p1.jpg,/p2.jpg',
        voiceMemoPath: '/memo.m4a',
      );

      final note = Note.fromMap(map);

      expect(note.body, 'Legacy body text');
      expect(note.photoPaths, ['/p1.jpg', '/p2.jpg']);
      expect(note.voiceMemoPaths, ['/memo.m4a']);
    });

    test('reconstructs a delta from blocksJson, preserving bold/italic', () {
      final blocksJson = jsonEncode([
        {
          'id': 'b1',
          'type': 'text',
          'text': 'Styled text',
          'bold': true,
          'italic': false,
          'path': '',
          'transcript': '',
        },
      ]);
      final map = _legacyMap(blocksJson: blocksJson);

      final note = Note.fromMap(map);

      expect(note.body, 'Styled text');
      final ops = (jsonDecode(note.quillJson) as List).cast<Map<String, dynamic>>();
      final textOp = ops.firstWhere((op) => op['insert'] == 'Styled text');
      expect((textOp['attributes'] as Map)['bold'], isTrue);
    });

    test('a brand-new note with a real quillJson is not treated as legacy', () {
      final delta = jsonEncode([
        {'insert': 'Already on quill\n'},
      ]);
      final map = _legacyMap()..['quillJson'] = delta;

      final note = Note.fromMap(map);

      expect(note.quillJson, delta);
      expect(note.body, 'Already on quill');
    });
  });
}
