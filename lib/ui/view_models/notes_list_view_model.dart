import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/note.dart';
import '../../domain/note_repository.dart';

enum NotesListStatus { loading, empty, error, success }

class NotesListViewModel extends ChangeNotifier {
  final NoteRepository _repository;
  final Map<String, Timer> _pendingDeletes = {};

  static const undoWindow = Duration(seconds: 4);

  NotesListViewModel(this._repository) {
    loadNotes();
  }

  NotesListStatus status = NotesListStatus.loading;
  List<Note> notes = [];
  String? errorMessage;
  bool isGalleryView = false;
  bool isSelectionMode = false;
  final Set<String> selectedNoteIds = {};
  String? selectedTagFilter;

  List<String> get allTags {
    final tagSet = <String>{};
    for (final note in notes) {
      tagSet.addAll(note.tags);
    }
    return tagSet.toList()..sort();
  }

  List<Note> get filteredNotes {
    final filter = selectedTagFilter;
    final source = filter == null
        ? notes
        : notes.where((note) => note.tags.contains(filter)).toList();

    final pinned = source.where((note) => note.isPinned);
    final unpinned = source.where((note) => !note.isPinned);
    return [...pinned, ...unpinned];
  }

  int get pinnedCount => filteredNotes.where((note) => note.isPinned).length;

  void selectTagFilter(String tag) {
    selectedTagFilter = selectedTagFilter == tag ? null : tag;
    notifyListeners();
  }

  Future<void> loadNotes() async {
    status = NotesListStatus.loading;
    notifyListeners();

    try {
      final result = await _repository.getNotes();
      notes = result.where((n) => !_pendingDeletes.containsKey(n.id)).toList();
      status = notes.isEmpty ? NotesListStatus.empty : NotesListStatus.success;
    } catch (e) {
      errorMessage = 'Could not load your notes.';
      status = NotesListStatus.error;
    }

    notifyListeners();
  }

  void deleteNoteWithUndo(String id) {
    notes = notes.where((n) => n.id != id).toList();
    status = notes.isEmpty ? NotesListStatus.empty : NotesListStatus.success;
    notifyListeners();

    _pendingDeletes[id] = Timer(undoWindow, () async {
      _pendingDeletes.remove(id);
      await _repository.deleteNote(id);
    });
  }

  void undoDelete(String id) {
    final timer = _pendingDeletes.remove(id);
    if (timer == null) return;
    timer.cancel();
    loadNotes();
  }

  Future<void> togglePin(String id) async {
    final note = notes.firstWhere((n) => n.id == id);
    await _repository.updateNote(note.copyWith(isPinned: !note.isPinned));
    await loadNotes();
  }

  Future<void> toggleLock(String id) async {
    final note = notes.firstWhere((n) => n.id == id);
    await _repository.updateNote(note.copyWith(isLocked: !note.isLocked));
    await loadNotes();
  }

  void toggleGalleryView() {
    isGalleryView = !isGalleryView;
    notifyListeners();
  }

  void enterSelectionMode() {
    isSelectionMode = true;
    selectedNoteIds.clear();
    notifyListeners();
  }

  void exitSelectionMode() {
    isSelectionMode = false;
    selectedNoteIds.clear();
    notifyListeners();
  }

  void toggleNoteSelection(String id) {
    if (!selectedNoteIds.remove(id)) selectedNoteIds.add(id);
    notifyListeners();
  }

  Future<void> deleteSelectedOrAll() async {
    final ids = selectedNoteIds.isEmpty
        ? notes.map((n) => n.id).toList()
        : selectedNoteIds.toList();
    await _repository.deleteNotes(ids);
    isSelectionMode = false;
    selectedNoteIds.clear();
    await loadNotes();
  }

  @override
  void dispose() {
    for (final timer in _pendingDeletes.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
