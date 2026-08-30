import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextSelection;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../domain/note.dart';
import '../../domain/note_repository.dart';
import '../../domain/tag.dart';
import '../../domain/tag_repository.dart';
import '../../domain/transcription_service.dart';
import '../tag_colors.dart';

enum TranscriptionStatus { idle, loading, error }

class TranscriptionUiState {
  final TranscriptionStatus status;
  final String? message;

  const TranscriptionUiState._(this.status, this.message);

  const TranscriptionUiState.loading()
    : this._(TranscriptionStatus.loading, null);
  const TranscriptionUiState.error(String message)
    : this._(TranscriptionStatus.error, message);
}

class NoteDetailViewModel extends ChangeNotifier {
  final NoteRepository _repository;
  final TagRepository _tagRepository;
  final TranscriptionService _transcriptionService;
  late Note _note;

  // The single rich-text document for this note's whole content — text,
  // photos, and voice memos all live inline in it. Photos are the built-in
  // 'image' embed type; voice memos are a plain Embeddable('audio', ...)
  // carrying {id, path, transcript} as JSON, deliberately not using
  // Quill's CustomBlockEmbed double-JSON-wrapping since 'audio' doesn't
  // collide with any built-in embed type.
  late final QuillController quillController;
  StreamSubscription<DocChange>? _documentChangeSubscription;

  Timer? _debounce;
  // Created lazily, only once recording actually starts, and disposed
  // again right after — instantiating AudioRecorder unconditionally for
  // every note (even ones that never touch the mic) is enough to trip
  // Android's microphone-in-use privacy indicator for the rest of the
  // app session.
  AudioRecorder? _recorder;
  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<Duration> _playerDurationSubscription;
  late final StreamSubscription<Duration> _playerPositionSubscription;
  Timer? _recordingTimer;

  // Where the finished voice memo embed will be inserted, captured when
  // the recording modal opens (before it can affect the editor's own
  // selection) rather than read fresh when the mic is tapped.
  int _pendingInsertionIndex = 0;
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  Duration _recordingDuration = Duration.zero;

  // Guards notifyListeners()/state writes from a transcription request that
  // resolves after this ViewModel has already been disposed (e.g. the user
  // navigated away mid-request).
  bool _disposed = false;

  // Transient, per-memo transcription state — keyed by the audio embed's
  // own id (not its document offset, which shifts as the surrounding text
  // is edited) so multiple memos in one note can transcribe independently
  // and a request that outlives an edit elsewhere can still find its memo
  // again. Deliberately has no "success" status: success is the embed's
  // own transcript field being non-empty, so the persisted note stays the
  // single source of truth and this map only ever holds state that should
  // NOT survive process death.
  final Map<String, TranscriptionUiState> _transcription = {};

  String? _playingAudioId;
  bool _isPlaying = false;
  final Map<String, Duration> _voiceMemoDurations = {};
  final Map<String, Duration> _playbackPositions = {};

  NoteDetailViewModel(
    this._repository,
    this._tagRepository,
    this._transcriptionService, {
    Note? existingNote,
  }) {
    final now = DateTime.now();
    if (existingNote != null) {
      _note = existingNote;
    } else {
      _note = Note(
        id: const Uuid().v4(),
        title: '',
        colorValue: tagColorPalette[0].toARGB32(),
        createdAt: now,
        updatedAt: now,
      );
      _assignStableColor();
    }
    quillController = QuillController(
      document: _parseDocument(_note.quillJson),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _documentChangeSubscription = quillController.document.changes.listen((_) {
      if (_disposed) return;
      _syncNoteFromDocument();
      _scheduleSave();
    });
    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (_playingAudioId != null) {
          _playbackPositions[_playingAudioId!] = Duration.zero;
        }
      }
      notifyListeners();
    });
    _playerDurationSubscription = _player.onDurationChanged.listen((duration) {
      if (_playingAudioId != null) {
        _voiceMemoDurations[_playingAudioId!] = duration;
      }
      notifyListeners();
    });
    _playerPositionSubscription = _player.onPositionChanged.listen((position) {
      if (_playingAudioId != null) {
        _playbackPositions[_playingAudioId!] = position;
      }
      notifyListeners();
    });
    _preloadDurations();
  }

  Document _parseDocument(String quillJson) {
    try {
      return Document.fromJson(jsonDecode(quillJson) as List);
    } catch (_) {
      return Document();
    }
  }

  void _syncNoteFromDocument() {
    _note = _note.copyWith(
      quillJson: jsonEncode(quillController.document.toDelta().toJson()),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _assignStableColor() async {
    final existingNotes = await _repository.getNotes();
    final color = paletteColorForCreationIndex(existingNotes.length);
    _note = _note.copyWith(colorValue: color.toARGB32());
    notifyListeners();
  }

  Future<void> _preloadDurations() async {
    for (final embed in _audioEmbeds()) {
      final path = embed.payload['path'] as String? ?? '';
      final id = embed.payload['id'] as String?;
      if (path.isEmpty || id == null) continue;
      await _player.setSourceDeviceFile(path);
      final duration = await _player.getDuration();
      if (duration != null) {
        _voiceMemoDurations[id] = duration;
        notifyListeners();
      }
    }
  }

  // Walks the current document once, returning every audio embed found
  // along with its current offset and decoded {id, path, transcript}
  // payload. The offset is only valid at the instant this runs — it shifts
  // whenever earlier content in the document changes length.
  List<({int offset, Map<String, dynamic> payload})> _audioEmbeds() {
    final results = <({int offset, Map<String, dynamic> payload})>[];
    var offset = 0;
    for (final op in quillController.document.toDelta().toJson()) {
      final insert = op['insert'];
      if (insert is String) {
        offset += insert.length;
      } else if (insert is Map) {
        if (insert['audio'] is String) {
          try {
            final payload =
                jsonDecode(insert['audio'] as String) as Map<String, dynamic>;
            results.add((offset: offset, payload: payload));
          } catch (_) {
            // Malformed embed payload — skip it.
          }
        }
        offset += 1;
      }
    }
    return results;
  }

  ({int offset, Map<String, dynamic> payload})? _findAudioEmbed(String id) {
    for (final embed in _audioEmbeds()) {
      if (embed.payload['id'] == id) return embed;
    }
    return null;
  }

  void _replaceAudioEmbed(int offset, Map<String, dynamic> newPayload) {
    quillController.replaceText(
      offset,
      1,
      Embeddable('audio', jsonEncode(newPayload)),
      null,
    );
    _syncNoteFromDocument();
  }

  Note get note => _note;
  bool get isNewNote => _note.title.isEmpty && _note.body.isEmpty;

  bool get isRecording => _isRecording;
  bool get isRecordingPaused => _isRecordingPaused;
  Duration get recordingDuration => _recordingDuration;

  bool isPlayingAudio(String audioId) =>
      _isPlaying && _playingAudioId == audioId;
  Duration voiceMemoDurationFor(String audioId) =>
      _voiceMemoDurations[audioId] ?? Duration.zero;
  Duration playbackPositionFor(String audioId) => _playingAudioId == audioId
      ? (_playbackPositions[audioId] ?? Duration.zero)
      : Duration.zero;

  bool get canTranscribe => _transcriptionService.isConfigured;
  TranscriptionStatus transcriptionStatusFor(String audioId) =>
      _transcription[audioId]?.status ?? TranscriptionStatus.idle;
  String? transcriptionErrorFor(String audioId) =>
      _transcription[audioId]?.message;

  void updateTitle(String value) {
    _note = _note.copyWith(title: value, updatedAt: DateTime.now());
    _scheduleSave();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    // Don't save a note that's still completely empty.
    if (_note.title.isEmpty &&
        _note.body.isEmpty &&
        _note.photoPaths.isEmpty &&
        _note.voiceMemoPaths.isEmpty &&
        _note.tags.isEmpty) {
      return;
    }
    await _repository.addNote(_note);
  }

  Future<void> saveNow() async {
    _debounce?.cancel();
    await _save();
  }

  Future<List<String>> getAvailableTags() async {
    final allNotes = await _repository.getNotes();
    final tagSet = <String>{};
    for (final note in allNotes) {
      tagSet.addAll(note.tags);
    }
    tagSet.removeAll(_note.tags);
    return tagSet.toList()..sort();
  }

  Future<int> getSuggestedTagColor() async {
    final existingTags = await _tagRepository.getTags();
    return paletteColorForCreationIndex(existingTags.length).toARGB32();
  }

  Future<void> addTag(String tag, {int? colorValue}) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _note.tags.contains(trimmed)) return;

    final existingTags = await _tagRepository.getTags();
    final alreadyExists = existingTags.any((t) => t.name == trimmed);
    if (!alreadyExists) {
      final resolvedColorValue =
          colorValue ??
          paletteColorForCreationIndex(existingTags.length).toARGB32();
      await _tagRepository.saveTag(
        Tag(name: trimmed, colorValue: resolvedColorValue),
      );
    }

    _note = _note.copyWith(
      tags: [..._note.tags, trimmed],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await saveNow();
  }

  Future<void> removeTag(String tag) async {
    _note = _note.copyWith(
      tags: _note.tags.where((t) => t != tag).toList(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await saveNow();
  }

  Future<void> addPhoto(File pickedFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}${p.extension(pickedFile.path)}';
    final savedFile = await pickedFile.copy(p.join(docsDir.path, fileName));

    final index = quillController.selection.baseOffset.clamp(
      0,
      quillController.document.length,
    );
    quillController.replaceText(
      index,
      0,
      Embeddable('image', savedFile.path),
      TextSelection.collapsed(offset: index + 1),
    );
    _syncNoteFromDocument();
    notifyListeners();
    await saveNow();
  }

  Future<void> removePhotoAt(int offset, String filePath) async {
    if (_note.isLocked) return;
    if (filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    }
    quillController.replaceText(offset, 1, '', null);
    _syncNoteFromDocument();
    notifyListeners();
    await saveNow();
  }

  Future<void> removeAudio(String audioId) async {
    if (_note.isLocked) return;
    final found = _findAudioEmbed(audioId);
    if (found == null) return;
    if (_playingAudioId == audioId && _isPlaying) {
      await _player.stop();
    }
    final path = found.payload['path'] as String? ?? '';
    if (path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    quillController.replaceText(found.offset, 1, '', null);
    _syncNoteFromDocument();
    _transcription.remove(audioId);
    _voiceMemoDurations.remove(audioId);
    _playbackPositions.remove(audioId);
    notifyListeners();
    await saveNow();
  }

  // Drops an audio embed's pending transcript into the note as real text,
  // placed immediately after the memo it came from.
  Future<void> commitTranscript(String audioId) async {
    if (_note.isLocked) return;
    final found = _findAudioEmbed(audioId);
    if (found == null) return;
    final text = found.payload['transcript'] as String? ?? '';
    if (text.isEmpty) return;

    _replaceAudioEmbed(found.offset, {...found.payload, 'transcript': ''});
    quillController.replaceText(
      found.offset + 1,
      0,
      '$text\n',
      TextSelection.collapsed(offset: found.offset + 1 + text.length + 1),
    );
    _syncNoteFromDocument();
    notifyListeners();
    await saveNow();
  }

  Future<void> discardTranscript(String audioId) async {
    if (_note.isLocked) return;
    final found = _findAudioEmbed(audioId);
    if (found == null) return;
    _replaceAudioEmbed(found.offset, {...found.payload, 'transcript': ''});
    notifyListeners();
    await saveNow();
  }

  // Transcribes a memo's saved audio file via the injected
  // TranscriptionService (a cloud call, made strictly AFTER the memo has
  // already finished recording — never while the recorder has the mic, so
  // this can't repeat the mic-conflict bug that broke live recognition).
  // A memo is only ever transcribed once: a cached transcript short-
  // circuits before any network call, so re-tapping never re-bills.
  Future<void> transcribeAudio(String audioId) async {
    if (_note.isLocked) return;
    final found = _findAudioEmbed(audioId);
    if (found == null) return;
    final path = found.payload['path'] as String? ?? '';
    final existingTranscript = found.payload['transcript'] as String? ?? '';
    if (path.isEmpty || existingTranscript.isNotEmpty) return;
    if (transcriptionStatusFor(audioId) == TranscriptionStatus.loading) {
      return;
    }

    _transcription[audioId] = const TranscriptionUiState.loading();
    notifyListeners();

    try {
      final text = await _transcriptionService.transcribe(path);
      if (_disposed) return;
      final current = _findAudioEmbed(audioId);
      if (current == null) {
        // The memo was deleted while the request was in flight.
        _transcription.remove(audioId);
        return;
      }
      _replaceAudioEmbed(current.offset, {
        ...current.payload,
        'transcript': text,
      });
      _transcription.remove(audioId);
      notifyListeners();
      await saveNow();
    } on TranscriptionException catch (e) {
      if (_disposed) return;
      _transcription[audioId] = TranscriptionUiState.error(_messageFor(e.kind));
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _transcription[audioId] = const TranscriptionUiState.error(
        'Something went wrong. Try again.',
      );
      notifyListeners();
    }
  }

  void clearTranscriptionError(String audioId) {
    _transcription.remove(audioId);
    notifyListeners();
  }

  String _messageFor(TranscriptionErrorKind kind) {
    switch (kind) {
      case TranscriptionErrorKind.notConfigured:
        return "Transcription isn't configured in this build.";
      case TranscriptionErrorKind.network:
        return 'No internet connection. Check your network and retry.';
      case TranscriptionErrorKind.unauthorized:
        return 'Transcription key was rejected.';
      case TranscriptionErrorKind.rateLimited:
        return 'Too many requests. Wait a moment and retry.';
      case TranscriptionErrorKind.fileMissing:
        return "This memo's audio file is missing.";
      case TranscriptionErrorKind.fileTooLarge:
        return 'This memo is too long to transcribe.';
      case TranscriptionErrorKind.emptyResult:
        return 'No speech detected in this memo.';
      case TranscriptionErrorKind.server:
        return 'Transcription service is unavailable. Retry in a moment.';
    }
  }

  // Recording only ever happens inside the recording modal: this just
  // starts the recorder and a live timer. The audio embed itself isn't
  // added to the document until stopRecording() finalizes it — so there's
  // never a half-finished "recording in progress" embed sitting in the
  // note, and starting a second recording can never collide with a still-
  // open one from before.
  Future<void> startRecording({required int insertionIndex}) async {
    if (_isRecording) return;
    _pendingInsertionIndex = insertionIndex;

    final docsDir = await getApplicationDocumentsDirectory();
    final filePath = p.join(docsDir.path, '${const Uuid().v4()}.m4a');
    final recorder = _recorder ??= AudioRecorder();
    await recorder.start(const RecordConfig(), path: filePath);
    _isRecording = true;
    _isRecordingPaused = false;
    _recordingDuration = Duration.zero;
    _startRecordingTimer();
    notifyListeners();
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  Future<void> pauseRecording() async {
    if (!_isRecording || _isRecordingPaused) return;
    await _recorder?.pause();
    _recordingTimer?.cancel();
    _isRecordingPaused = true;
    notifyListeners();
  }

  Future<void> resumeRecording() async {
    if (!_isRecording || !_isRecordingPaused) return;
    await _recorder?.resume();
    _isRecordingPaused = false;
    _startRecordingTimer();
    notifyListeners();
  }

  Future<void> _disposeRecorder() async {
    final recorder = _recorder;
    _recorder = null;
    await recorder?.dispose();
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    final path = await _recorder?.stop();
    await _disposeRecorder();
    _isRecording = false;
    _isRecordingPaused = false;
    if (path != null) {
      final audioId = const Uuid().v4();
      final payload = jsonEncode({
        'id': audioId,
        'path': path,
        'transcript': '',
      });
      final index = _pendingInsertionIndex.clamp(
        0,
        quillController.document.length,
      );
      quillController.replaceText(
        index,
        0,
        Embeddable('audio', payload),
        TextSelection.collapsed(offset: index + 1),
      );
      _syncNoteFromDocument();
      _voiceMemoDurations[audioId] = _recordingDuration;
    }
    _pendingInsertionIndex = 0;
    _recordingDuration = Duration.zero;
    notifyListeners();
    await saveNow();
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    final path = await _recorder?.stop();
    await _disposeRecorder();
    _isRecording = false;
    _isRecordingPaused = false;
    _recordingDuration = Duration.zero;
    _pendingInsertionIndex = 0;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    notifyListeners();
  }

  Future<void> playAudio(String audioId, String path) async {
    if (path.isEmpty) return;
    _playingAudioId = audioId;
    await _player.play(DeviceFileSource(path));
  }

  Future<void> pausePlayback() async {
    await _player.pause();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _recordingTimer?.cancel();
    _documentChangeSubscription?.cancel();
    _playerStateSubscription.cancel();
    _playerDurationSubscription.cancel();
    _playerPositionSubscription.cancel();
    _recorder?.dispose();
    _player.dispose();
    quillController.dispose();
    super.dispose();
  }
}
