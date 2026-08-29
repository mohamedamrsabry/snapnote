import 'package:flutter/foundation.dart';

import '../../domain/note.dart';
import '../../domain/note_repository.dart';

enum SearchFilter { lockedNotes, checklists, images, recordings }

class SearchViewModel extends ChangeNotifier {
  final NoteRepository _repository;
  List<Note> _allNotes = [];
  String query = '';
  final Set<SearchFilter> activeFilters = {};

  SearchViewModel(this._repository) {
    _load();
  }

  Future<void> _load() async {
    _allNotes = await _repository.getNotes();
    notifyListeners();
  }

  Future<void> reload() => _load();

  bool get isBrowsing => query.isEmpty && activeFilters.isEmpty;

  List<Note> get results {
    final lowerQuery = query.toLowerCase();
    return _allNotes.where((note) {
      final matchesQuery =
          query.isEmpty ||
          note.title.toLowerCase().contains(lowerQuery) ||
          note.body.toLowerCase().contains(lowerQuery);
      final matchesFilters = activeFilters.every(
        (filter) => switch (filter) {
          SearchFilter.lockedNotes => note.isLocked,
          SearchFilter.checklists => false,
          SearchFilter.images => note.photoPaths.isNotEmpty,
          SearchFilter.recordings => note.voiceMemoPaths.isNotEmpty,
        },
      );
      return matchesQuery && matchesFilters;
    }).toList();
  }

  void updateQuery(String value) {
    query = value;
    notifyListeners();
  }

  void toggleFilter(SearchFilter filter) {
    if (!activeFilters.remove(filter)) activeFilters.add(filter);
    notifyListeners();
  }

  void clear() {
    query = '';
    activeFilters.clear();
    notifyListeners();
  }
}
