import 'package:flutter/foundation.dart';

import '../../domain/note.dart';
import '../../domain/note_repository.dart';
import 'notes_list_view_model.dart';

enum ArchivedNotesStatus { loading, empty, error, success }

class ArchivedNotesViewModel extends ChangeNotifier {
  final NoteRepository _repository;

  ArchivedNotesViewModel(this._repository) {
    load();
  }

  ArchivedNotesStatus status = ArchivedNotesStatus.loading;
  List<Note> notes = [];
  String? errorMessage;

  Future<void> load() async {
    status = ArchivedNotesStatus.loading;
    notifyListeners();

    try {
      await _repository.purgeExpiredArchivedNotes(
        NotesListViewModel.archiveMaxAge,
      );
      notes = await _repository.getArchivedNotes();
      status = notes.isEmpty
          ? ArchivedNotesStatus.empty
          : ArchivedNotesStatus.success;
    } catch (e) {
      errorMessage = 'Could not load archived notes.';
      status = ArchivedNotesStatus.error;
    }

    notifyListeners();
  }

  // How many days are left before this note is purged for good.
  int daysRemaining(Note note) {
    final archivedAt = note.archivedAt;
    if (archivedAt == null) return 0;
    final expiresAt = archivedAt.add(NotesListViewModel.archiveMaxAge);
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 0;
    // Round up so "a few hours left" still reads as 1 day, not 0.
    return (remaining.inHours / 24).ceil().clamp(0, 3);
  }

  Future<void> restore(String id) async {
    await _repository.restoreNote(id);
    await load();
  }

  Future<void> deleteNow(String id) async {
    await _repository.deleteNote(id);
    await load();
  }
}
