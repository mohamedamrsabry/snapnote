import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
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
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<Duration> _playerDurationSubscription;
  late final StreamSubscription<Duration> _playerPositionSubscription;
  Timer? _recordingTimer;
  bool _isRecording = false;
  bool _isPlaying = false;
  Duration _recordingDuration = Duration.zero;
  Duration _voiceMemoDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;

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
    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        _playbackPosition = Duration.zero;
      }
      notifyListeners();
    });
    _playerDurationSubscription = _player.onDurationChanged.listen((
      duration,
    ) {
      _voiceMemoDuration = duration;
      notifyListeners();
    });
    _playerPositionSubscription = _player.onPositionChanged.listen((
      position,
    ) {
      _playbackPosition = position;
      notifyListeners();
    });
    if (_note.voiceMemoPath != null) {
      _loadVoiceMemoDuration();
    }
  }

  Future<void> _loadVoiceMemoDuration() async {
    final path = _note.voiceMemoPath;
    if (path == null) return;
    await _player.setSourceDeviceFile(path);
    final duration = await _player.getDuration();
    if (duration != null) {
      _voiceMemoDuration = duration;
      notifyListeners();
    }
  }

  Note get note => _note;
  bool get isNewNote => _note.title.isEmpty && _note.body.isEmpty;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  Duration get recordingDuration => _recordingDuration;
  Duration get voiceMemoDuration => _voiceMemoDuration;
  Duration get playbackPosition => _playbackPosition;

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
    if (_note.title.isEmpty &&
        _note.body.isEmpty &&
        _note.photoPaths.isEmpty &&
        _note.voiceMemoPath == null &&
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

  Future<void> addTag(String tag) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _note.tags.contains(trimmed)) return;

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

    _note = _note.copyWith(
      photoPaths: [..._note.photoPaths, savedFile.path],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await saveNow();
  }

  Future<void> startRecording() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final filePath = p.join(docsDir.path, '${const Uuid().v4()}.m4a');
    await _recorder.start(const RecordConfig(), path: filePath);
    _isRecording = true;
    _recordingDuration = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingDuration += const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    _isRecording = false;
    if (path != null) {
      _note = _note.copyWith(voiceMemoPath: path, updatedAt: DateTime.now());
      _voiceMemoDuration = _recordingDuration;
    }
    _recordingDuration = Duration.zero;
    notifyListeners();
    await saveNow();
  }

  Future<void> playVoiceMemo() async {
    final path = _note.voiceMemoPath;
    if (path == null) return;
    await _player.play(DeviceFileSource(path));
  }

  Future<void> pausePlayback() async {
    await _player.pause();
  }

  Future<void> deleteVoiceMemo() async {
    final path = _note.voiceMemoPath;
    if (path == null) return;

    if (_isPlaying) {
      await _player.stop();
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    _note = _note.copyWith(clearVoiceMemo: true, updatedAt: DateTime.now());
    _voiceMemoDuration = Duration.zero;
    _playbackPosition = Duration.zero;
    notifyListeners();
    await saveNow();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recordingTimer?.cancel();
    _playerStateSubscription.cancel();
    _playerDurationSubscription.cancel();
    _playerPositionSubscription.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
