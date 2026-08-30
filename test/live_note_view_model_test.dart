import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snapnote/domain/live_note_service.dart';
import 'package:snapnote/domain/note.dart';
import 'package:snapnote/domain/note_repository.dart';
import 'package:snapnote/domain/settings_repository.dart';
import 'package:snapnote/ui/view_models/live_note_view_model.dart';

class FakeLiveNoteService implements LiveNoteService {
  int showCallCount = 0;
  int hideCallCount = 0;
  bool showResult = true;
  bool isShowingResult = true;
  ({String noteId, String title, String body})? lastShowArgs;

  @override
  Future<bool> show({
    required String noteId,
    required String title,
    required String body,
  }) async {
    showCallCount++;
    lastShowArgs = (noteId: noteId, title: title, body: body);
    return showResult;
  }

  @override
  Future<void> hide() async {
    hideCallCount++;
  }

  @override
  Future<bool> isShowing() async => isShowingResult;
}

class FakeSettingsRepository implements SettingsRepository {
  String? liveNoteId;

  @override
  Future<bool> isDarkMode() async => true;

  @override
  Future<void> setDarkMode(bool value) async {}

  @override
  Future<String?> getLiveNoteId() async => liveNoteId;

  @override
  Future<void> setLiveNoteId(String? id) async {
    liveNoteId = id;
  }
}

class FakeNoteRepository implements NoteRepository {
  final Map<String, Note> notes;

  FakeNoteRepository(this.notes);

  @override
  Future<Note?> getNoteById(String id) async => notes[id];

  @override
  Future<List<Note>> getNotes() async => notes.values.toList();

  @override
  Future<void> addNote(Note note) async {}

  @override
  Future<void> updateNote(Note note) async {}

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<void> deleteNotes(List<String> ids) async {}

  @override
  Future<void> archiveNote(String id) async {}

  @override
  Future<void> archiveNotes(List<String> ids) async {}

  @override
  Future<void> restoreNote(String id) async {}

  @override
  Future<List<Note>> getArchivedNotes() async => [];

  @override
  Future<void> purgeExpiredArchivedNotes(Duration maxAge) async {}
}

Note _note(
  String id, {
  String title = '',
  String body = '',
  DateTime? archivedAt,
}) {
  final now = DateTime(2026, 1, 1);
  return Note(
    id: id,
    title: title,
    quillJson: body.isEmpty
        ? Note.emptyQuillJson
        : jsonEncode([
            {'insert': '$body\n'},
          ]),
    colorValue: 0,
    createdAt: now,
    updatedAt: now,
    archivedAt: archivedAt,
  );
}

void main() {
  group('LiveNoteViewModel', () {
    test('toggle on note B while A is live leaves liveNoteId == B '
        'and calls show exactly once', () async {
      final noteA = _note('A', title: 'Note A');
      final noteB = _note('B', title: 'Note B');
      final service = FakeLiveNoteService()..isShowingResult = true;
      final settings = FakeSettingsRepository()..liveNoteId = 'A';
      final notes = FakeNoteRepository({'A': noteA, 'B': noteB});

      final viewModel = LiveNoteViewModel(service, settings, notes);
      // Let the constructor's reconcile() (A already showing) settle
      // before isolating the effect of toggling to B.
      await Future<void>.delayed(Duration.zero);
      service.showCallCount = 0;

      await viewModel.toggle(noteB);

      expect(viewModel.liveNoteId, 'B');
      expect(settings.liveNoteId, 'B');
      expect(service.showCallCount, 1);
      expect(service.lastShowArgs?.noteId, 'B');
    });

    test(
      'reconcile with an archived note calls hide and clears the key',
      () async {
        final archived = _note(
          'X',
          title: 'Gone',
          archivedAt: DateTime(2026, 1, 2),
        );
        final service = FakeLiveNoteService();
        final settings = FakeSettingsRepository()..liveNoteId = 'X';
        final notes = FakeNoteRepository({'X': archived});

        final viewModel = LiveNoteViewModel(service, settings, notes);
        await Future<void>.delayed(Duration.zero);

        expect(service.hideCallCount, 1);
        expect(settings.liveNoteId, isNull);
        expect(viewModel.liveNoteId, isNull);
      },
    );

    test(
      'reconcile re-shows with the right title/body when isShowing() is false',
      () async {
        final note = _note('Y', title: 'Groceries', body: 'Milk and eggs');
        final service = FakeLiveNoteService()..isShowingResult = false;
        final settings = FakeSettingsRepository()..liveNoteId = 'Y';
        final notes = FakeNoteRepository({'Y': note});

        final viewModel = LiveNoteViewModel(service, settings, notes);
        await Future<void>.delayed(Duration.zero);

        expect(viewModel.liveNoteId, 'Y');
        expect(service.showCallCount, 1);
        expect(service.lastShowArgs?.noteId, 'Y');
        expect(service.lastShowArgs?.title, 'Groceries');
        expect(service.lastShowArgs?.body, 'Milk and eggs');
      },
    );
  });
}
