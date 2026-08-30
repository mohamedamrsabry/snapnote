import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snapnote/domain/note.dart';
import 'package:snapnote/domain/note_repository.dart';
import 'package:snapnote/domain/tag.dart';
import 'package:snapnote/domain/tag_repository.dart';
import 'package:snapnote/ui/notes_list_screen.dart';
import 'package:snapnote/ui/view_models/notes_list_view_model.dart';

// In-memory fake, functional enough to exercise loadNotes()'s real
// behavior (unlike a stub that just returns nothing) without touching
// sqflite/a real database.
class FakeNoteRepository implements NoteRepository {
  final Map<String, Note> notes;

  FakeNoteRepository(this.notes);

  @override
  Future<Note?> getNoteById(String id) async => notes[id];

  @override
  Future<List<Note>> getNotes() async =>
      notes.values.where((n) => n.archivedAt == null).toList();

  @override
  Future<void> addNote(Note note) async => notes[note.id] = note;

  @override
  Future<void> updateNote(Note note) async => notes[note.id] = note;

  @override
  Future<void> deleteNote(String id) async => notes.remove(id);

  @override
  Future<void> deleteNotes(List<String> ids) async {
    for (final id in ids) {
      notes.remove(id);
    }
  }

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

class FakeTagRepository implements TagRepository {
  @override
  Future<List<Tag>> getTags() async => [];

  @override
  Future<void> saveTag(Tag tag) async {}
}

Note _note(String id, {String title = ''}) {
  final now = DateTime(2026, 1, 1);
  return Note(
    id: id,
    title: title,
    colorValue: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(NotesListViewModel viewModel) {
  return MaterialApp(
    home: ChangeNotifierProvider<NotesListViewModel>.value(
      value: viewModel,
      child: const NotesListScreen(),
    ),
  );
}

void main() {
  testWidgets('shows the empty state when there are no notes', (
    tester,
  ) async {
    final viewModel = NotesListViewModel(
      FakeNoteRepository({}),
      FakeTagRepository(),
    );

    await tester.pumpWidget(_wrap(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('Create your first note !'), findsOneWidget);
  });

  testWidgets('shows a note in the list once loaded', (tester) async {
    final viewModel = NotesListViewModel(
      FakeNoteRepository({'1': _note('1', title: 'Groceries')}),
      FakeTagRepository(),
    );

    await tester.pumpWidget(_wrap(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Create your first note !'), findsNothing);
  });

  testWidgets('an untitled note falls back to a placeholder label', (
    tester,
  ) async {
    final viewModel = NotesListViewModel(
      FakeNoteRepository({'1': _note('1', title: '')}),
      FakeTagRepository(),
    );

    await tester.pumpWidget(_wrap(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('(Untitled)'), findsOneWidget);
  });
}
