import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../domain/note.dart';
import '../../domain/note_repository.dart';

class NoteDetailViewModel extends ChangeNotifier {
  final NoteRepository _repository;
  late Note _note;
  Timer? _debounce;

  NoteDetailViewModel(this._repository, {Note? existingNote}) {
    final now = DateTime.now();
    _note =
        existingNote ??
        Note(
          id: const Uuid().v4(),
          title: '',
          body: '',
          createdAt: now,
          updatedAt: now,
        );
  }

  Note get note => _note;
  bool get isNewNote => _note.title.isEmpty && _note.body.isEmpty;

  void updateTitle(String value) {
    _note = _note.copyWith(title: value, updatedAt: DateTime.now());
    _scheduleSave();
  }

  void updateBody(String value) {
    _note = _note.copyWith(body: value, updatedAt: DateTime.now());
    _scheduleSave();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    // Don't save a note that's still completely empty.
    if (_note.title.isEmpty && _note.body.isEmpty) return;
    await _repository.addNote(_note);
  }

  Future<void> saveNow() async {
    _debounce?.cancel();
    await _save();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
