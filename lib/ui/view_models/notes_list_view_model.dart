import 'package:flutter/foundation.dart';

import '../../domain/note.dart';
import '../../domain/note_repository.dart';

enum NotesListStatus { loading, empty, error, success }

class NotesListViewModel extends ChangeNotifier {
  final NoteRepository _repository;

  NotesListViewModel(this._repository) {
    loadNotes();
  }

  NotesListStatus status = NotesListStatus.loading;
  List<Note> notes = [];
  String? errorMessage;

  Future<void> loadNotes() async {
    status = NotesListStatus.loading;
    notifyListeners();

    try {
      final result = await _repository.getNotes();
      notes = result;
      status = result.isEmpty ? NotesListStatus.empty : NotesListStatus.success;
    } catch (e) {
      errorMessage = 'Could not load your notes.';
      status = NotesListStatus.error;
    }

    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    await loadNotes();
  }
}
