import 'package:flutter/foundation.dart';

import '../../domain/live_note_service.dart';
import '../../domain/note.dart';
import '../../domain/note_repository.dart';
import '../../domain/settings_repository.dart';

// App-scoped (not per-note) because "which note is live" must survive
// popping the note detail screen, and reconciliation needs to run even
// when no note detail screen exists (e.g. on app resume).
class LiveNoteViewModel extends ChangeNotifier {
  final LiveNoteService _service;
  final SettingsRepository _settings;
  final NoteRepository _notes;

  String? _liveNoteId;
  bool _isBusy = false;

  LiveNoteViewModel(this._service, this._settings, this._notes) {
    reconcile();
  }

  String? get liveNoteId => _liveNoteId;
  bool get isBusy => _isBusy;
  bool isLive(String noteId) => _liveNoteId == noteId;

  String _titleFor(Note note) =>
      note.title.isEmpty ? 'Untitled note' : note.title;

  String _bodyFor(Note note) {
    if (note.isLocked) return 'This note is locked.';
    if (note.body.isEmpty) return 'No text in this note yet.';
    return note.body.length > 300
        ? '${note.body.substring(0, 300)}…'
        : note.body;
  }

  Future<void> _start(Note note) async {
    final shown = await _service.show(
      noteId: note.id,
      title: _titleFor(note),
      body: _bodyFor(note),
    );
    if (!shown) {
      await _settings.setLiveNoteId(null);
      _liveNoteId = null;
      return;
    }
    await _settings.setLiveNoteId(note.id);
    _liveNoteId = note.id;
  }

  Future<void> _stop() async {
    await _service.hide();
    await _settings.setLiveNoteId(null);
    _liveNoteId = null;
  }

  // Toggles Live for [note]. Going live on a different note while another
  // is already live needs no explicit teardown of the old one: show()
  // reuses a single fixed notification id (an atomic replace, no
  // flicker/duplicate) and the stored id is a single value that just gets
  // overwritten.
  Future<void> toggle(Note note) async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();
    try {
      if (isLive(note.id)) {
        await _stop();
      } else {
        await _start(note);
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  // Re-posts the live notification with a note's current text. No-ops
  // unless that note is the one currently live.
  Future<void> refresh(Note note) async {
    if (!isLive(note.id)) return;
    await _start(note);
    notifyListeners();
  }

  // Self-heal against both the OS (the user swiped the notification away,
  // or the device rebooted) and the database (the live note was deleted
  // or purged while we weren't looking). Fully idempotent — safe to call
  // on every app resume.
  Future<void> reconcile() async {
    final id = await _settings.getLiveNoteId();
    if (id == null) {
      _liveNoteId = null;
      notifyListeners();
      return;
    }

    final note = await _notes.getNoteById(id);
    if (note == null || note.archivedAt != null) {
      await _service.hide();
      await _settings.setLiveNoteId(null);
      _liveNoteId = null;
      notifyListeners();
      return;
    }

    _liveNoteId = id;
    if (!await _service.isShowing()) {
      final shown = await _service.show(
        noteId: note.id,
        title: _titleFor(note),
        body: _bodyFor(note),
      );
      if (!shown) {
        await _settings.setLiveNoteId(null);
        _liveNoteId = null;
      }
    }
    notifyListeners();
  }
}
