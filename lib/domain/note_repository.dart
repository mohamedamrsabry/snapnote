import 'note.dart';

abstract class NoteRepository {
  Future<List<Note>> getNotes();

  Future<Note?> getNoteById(String id);

  Future<void> addNote(Note note);

  Future<void> updateNote(Note note);

  /// Permanently deletes the note and its attachment files. Used for
  /// permanently removing an already-archived note, not for the user's
  /// everyday "delete" action — see [archiveNote].
  Future<void> deleteNote(String id);

  /// Permanently deletes the notes and their attachment files.
  Future<void> deleteNotes(List<String> ids);

  /// Soft-deletes a note: it stops appearing in [getNotes] and moves to
  /// [getArchivedNotes] instead of being removed immediately, so it can be
  /// recovered until it's purged.
  Future<void> archiveNote(String id);

  Future<void> archiveNotes(List<String> ids);

  /// Moves an archived note back to the regular notes list.
  Future<void> restoreNote(String id);

  Future<List<Note>> getArchivedNotes();

  /// Permanently deletes any archived note whose archivedAt is older than
  /// [maxAge].
  Future<void> purgeExpiredArchivedNotes(Duration maxAge);
}
