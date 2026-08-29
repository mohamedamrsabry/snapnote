import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/note.dart';
import '../../domain/note_repository.dart';
import '../../domain/tag.dart';
import '../../domain/tag_repository.dart';
import '../tag_colors.dart';

enum NotesListStatus { loading, empty, error, success }

class NotesListViewModel extends ChangeNotifier {
  final NoteRepository _repository;
  final TagRepository _tagRepository;
  final Map<String, Timer> _pendingDeleteTimers = {};
  final Map<String, Note> _pendingDeleteNotes = {};
  String? _lastPendingDeleteId;
  Map<String, Color> _tagColors = {};

  static const undoWindow = Duration(seconds: 4);
  static const archiveMaxAge = Duration(days: 3);

  NotesListViewModel(this._repository, this._tagRepository) {
    loadNotes();
  }

  NotesListStatus status = NotesListStatus.loading;
  List<Note> notes = [];
  String? errorMessage;
  bool isGalleryView = false;
  bool isSelectionMode = false;
  final Set<String> selectedNoteIds = {};
  String? selectedTagFilter;

  Color colorForNote(Note note) {
    if (note.tags.isNotEmpty) {
      final color = _tagColors[note.tags.first];
      if (color != null) return color;
    }
    return Color(note.colorValue);
  }

  Color colorForTagName(String tag) {
    return _tagColors[tag] ??
        tagColorPalette[tag.hashCode.abs() % tagColorPalette.length];
  }

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
      await _repository.purgeExpiredArchivedNotes(archiveMaxAge);
      final result = await _repository.getNotes();
      notes = result
          .where((n) => !_pendingDeleteTimers.containsKey(n.id))
          .toList();
      status = notes.isEmpty ? NotesListStatus.empty : NotesListStatus.success;
      await _loadTagColors();
    } catch (e) {
      errorMessage = 'Could not load your notes.';
      status = NotesListStatus.error;
    }

    notifyListeners();
  }

  Future<void> _loadTagColors() async {
    final tags = await _tagRepository.getTags();
    _tagColors = {for (final tag in tags) tag.name: Color(tag.colorValue)};

    final usedTags = <String>{for (final note in notes) ...note.tags};
    final missingTags = usedTags.difference(_tagColors.keys.toSet());
    for (final tagName in missingTags) {
      final color = paletteColorForCreationIndex(_tagColors.length);
      await _tagRepository.saveTag(Tag(name: tagName, colorValue: color.toARGB32()));
      _tagColors[tagName] = color;
    }
  }

  // The note pending an "Undo" (i.e. the most recently swipe/bulk-deleted
  // note still inside its undo window), or null if none. The UI's undo
  // banner is driven directly off this instead of a Flutter SnackBar, so
  // its visibility can never drift out of sync with the actual pending
  // archive — both are driven by the same Timer below.
  Note? get pendingUndoNote =>
      _lastPendingDeleteId == null
          ? null
          : _pendingDeleteNotes[_lastPendingDeleteId];

  void deleteNoteWithUndo(String id) {
    final note = notes.firstWhere((n) => n.id == id);
    notes = notes.where((n) => n.id != id).toList();
    status = notes.isEmpty ? NotesListStatus.empty : NotesListStatus.success;
    _pendingDeleteNotes[id] = note;
    _lastPendingDeleteId = id;
    notifyListeners();

    _pendingDeleteTimers[id] = Timer(undoWindow, () async {
      _pendingDeleteTimers.remove(id);
      _pendingDeleteNotes.remove(id);
      if (_lastPendingDeleteId == id) _lastPendingDeleteId = null;
      await _repository.archiveNote(id);
      notifyListeners();
    });
  }

  void undoDelete(String id) {
    final timer = _pendingDeleteTimers.remove(id);
    if (timer == null) return;
    timer.cancel();
    _pendingDeleteNotes.remove(id);
    if (_lastPendingDeleteId == id) _lastPendingDeleteId = null;
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
    await _repository.archiveNotes(ids);
    isSelectionMode = false;
    selectedNoteIds.clear();
    await loadNotes();
  }

  @override
  void dispose() {
    for (final timer in _pendingDeleteTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
