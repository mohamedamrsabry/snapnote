import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../domain/note.dart';
import '../../domain/note_block.dart';
import '../../domain/note_repository.dart';
import '../../domain/tag.dart';
import '../../domain/tag_repository.dart';
import '../tag_colors.dart';

class NoteDetailViewModel extends ChangeNotifier {
  final NoteRepository _repository;
  final TagRepository _tagRepository;
  late Note _note;
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

  String? _pendingSplitBlockId;
  int _pendingSplitOffset = 0;
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  Duration _recordingDuration = Duration.zero;

  String? _playingBlockId;
  bool _isPlaying = false;
  final Map<String, Duration> _voiceMemoDurations = {};
  final Map<String, Duration> _playbackPositions = {};

  NoteDetailViewModel(this._repository, this._tagRepository, {Note? existingNote}) {
    final now = DateTime.now();
    if (existingNote != null) {
      _note = existingNote;
    } else {
      _note = Note(
        id: const Uuid().v4(),
        title: '',
        blocks: [NoteBlock.text(id: const Uuid().v4())],
        colorValue: tagColorPalette[0].toARGB32(),
        createdAt: now,
        updatedAt: now,
      );
      _assignStableColor();
    }
    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (_playingBlockId != null) {
          _playbackPositions[_playingBlockId!] = Duration.zero;
        }
      }
      notifyListeners();
    });
    _playerDurationSubscription = _player.onDurationChanged.listen((
      duration,
    ) {
      if (_playingBlockId != null) {
        _voiceMemoDurations[_playingBlockId!] = duration;
      }
      notifyListeners();
    });
    _playerPositionSubscription = _player.onPositionChanged.listen((
      position,
    ) {
      if (_playingBlockId != null) {
        _playbackPositions[_playingBlockId!] = position;
      }
      notifyListeners();
    });
    _preloadDurations();
  }

  Future<void> _assignStableColor() async {
    final existingNotes = await _repository.getNotes();
    final color = paletteColorForCreationIndex(existingNotes.length);
    _note = _note.copyWith(colorValue: color.toARGB32());
    notifyListeners();
  }

  Future<void> _preloadDurations() async {
    for (final block in _note.blocks) {
      if (block.type == NoteBlockType.audio && block.path.isNotEmpty) {
        await _player.setSourceDeviceFile(block.path);
        final duration = await _player.getDuration();
        if (duration != null) {
          _voiceMemoDurations[block.id] = duration;
          notifyListeners();
        }
      }
    }
  }

  Note get note => _note;
  bool get isNewNote => _note.title.isEmpty && _note.body.isEmpty;

  bool get isRecording => _isRecording;
  bool get isRecordingPaused => _isRecordingPaused;
  Duration get recordingDuration => _recordingDuration;

  bool isPlayingBlock(String blockId) => _isPlaying && _playingBlockId == blockId;
  Duration voiceMemoDurationFor(String blockId) =>
      _voiceMemoDurations[blockId] ?? Duration.zero;
  Duration playbackPositionFor(String blockId) =>
      _playingBlockId == blockId
          ? (_playbackPositions[blockId] ?? Duration.zero)
          : Duration.zero;

  void updateTitle(String value) {
    _note = _note.copyWith(title: value, updatedAt: DateTime.now());
    _scheduleSave();
  }

  void updateBlockText(String blockId, String value) {
    final blocks = _note.blocks
        .map((b) => b.id == blockId ? b.copyWith(text: value) : b)
        .toList();
    _note = _note.copyWith(blocks: blocks, updatedAt: DateTime.now());
    _scheduleSave();
  }

  // Pressing Enter inside a text block should start a genuinely new
  // paragraph — its own block with its own bold/italic state — rather
  // than just inserting a newline that stays under the same style as the
  // rest of the block. [parts] is the block's new text split on '\n'; the
  // first part replaces the original block in place and each remaining
  // part becomes its own new block, all seeded with the original block's
  // current style.
  void splitTextBlockIntoParagraphs(String blockId, List<String> parts) {
    final blocks = [..._note.blocks];
    final index = blocks.indexWhere((b) => b.id == blockId);
    if (index == -1 || parts.isEmpty) return;

    final target = blocks[index];
    final replacement = <NoteBlock>[
      NoteBlock.text(
        id: target.id,
        text: parts.first,
        bold: target.bold,
        italic: target.italic,
      ),
      for (final part in parts.skip(1))
        NoteBlock.text(
          id: const Uuid().v4(),
          text: part,
          bold: target.bold,
          italic: target.italic,
        ),
    ];
    blocks.replaceRange(index, index + 1, replacement);

    _note = _note.copyWith(blocks: blocks, updatedAt: DateTime.now());
    notifyListeners();
    _scheduleSave();
  }

  void toggleBlockBold(String blockId) {
    final blocks = _note.blocks
        .map((b) => b.id == blockId ? b.copyWith(bold: !b.bold) : b)
        .toList();
    _note = _note.copyWith(blocks: blocks, updatedAt: DateTime.now());
    notifyListeners();
    saveNow();
  }

  void toggleBlockItalic(String blockId) {
    final blocks = _note.blocks
        .map((b) => b.id == blockId ? b.copyWith(italic: !b.italic) : b)
        .toList();
    _note = _note.copyWith(blocks: blocks, updatedAt: DateTime.now());
    notifyListeners();
    saveNow();
  }

  // Splits the block at [splitBlockId]/[splitOffset] (the text block that
  // currently has focus, and the cursor position within it) and inserts
  // [newBlock] between the two halves, so the user can keep typing on
  // either side of an inserted photo or voice memo. Falls back to
  // appending after the last block if nothing is focused.
  void _insertBlock(
    NoteBlock newBlock, {
    String? splitBlockId,
    int splitOffset = 0,
  }) {
    final blocks = [..._note.blocks];

    int index;
    int offset;
    if (blocks.isEmpty) {
      blocks.add(NoteBlock.text(id: const Uuid().v4()));
      index = 0;
      offset = 0;
    } else {
      index = splitBlockId == null
          ? -1
          : blocks.indexWhere(
              (b) => b.id == splitBlockId && b.type == NoteBlockType.text,
            );
      if (index == -1) {
        if (blocks.last.type != NoteBlockType.text) {
          blocks.add(NoteBlock.text(id: const Uuid().v4()));
        }
        index = blocks.length - 1;
        offset = blocks[index].text.length;
      } else {
        offset = splitOffset.clamp(0, blocks[index].text.length);
      }
    }

    final target = blocks[index];
    final before = target.text.substring(0, offset);
    final after = target.text.substring(offset);
    final replacement = <NoteBlock>[
      if (before.isNotEmpty)
        NoteBlock.text(
          id: target.id,
          text: before,
          bold: target.bold,
          italic: target.italic,
        ),
      newBlock,
      NoteBlock.text(
        id: const Uuid().v4(),
        text: after,
        bold: target.bold,
        italic: target.italic,
      ),
    ];
    blocks.replaceRange(index, index + 1, replacement);

    _note = _note.copyWith(blocks: blocks, updatedAt: DateTime.now());
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

  Future<void> addPhoto(
    File pickedFile, {
    String? splitBlockId,
    int splitOffset = 0,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final fileName = '${const Uuid().v4()}${p.extension(pickedFile.path)}';
    final savedFile = await pickedFile.copy(p.join(docsDir.path, fileName));

    _insertBlock(
      NoteBlock.photo(id: const Uuid().v4(), path: savedFile.path),
      splitBlockId: splitBlockId,
      splitOffset: splitOffset,
    );
    notifyListeners();
    await saveNow();
  }

  Future<void> removeBlock(String blockId) async {
    final block = _note.blocks.firstWhere((b) => b.id == blockId);
    if (block.path.isNotEmpty) {
      if (_playingBlockId == blockId && _isPlaying) {
        await _player.stop();
      }
      final file = File(block.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final blocks = _note.blocks.where((b) => b.id != blockId).toList();
    _note = _note.copyWith(blocks: blocks, updatedAt: DateTime.now());
    notifyListeners();
    await saveNow();
  }

  // Recording only ever happens inside the recording modal: this just
  // starts the recorder and a live timer. The audio block itself isn't
  // added to the note's blocks until stopRecording() finalizes it — so
  // there's never a half-finished "recording in progress" block sitting
  // in the note, and starting a second recording can never collide with
  // a still-open one from before.
  Future<void> startRecording({
    String? splitBlockId,
    int splitOffset = 0,
  }) async {
    if (_isRecording) return;
    _pendingSplitBlockId = splitBlockId;
    _pendingSplitOffset = splitOffset;

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
      final block = NoteBlock.audio(id: const Uuid().v4(), path: path);
      _insertBlock(
        block,
        splitBlockId: _pendingSplitBlockId,
        splitOffset: _pendingSplitOffset,
      );
      _voiceMemoDurations[block.id] = _recordingDuration;
    }
    _pendingSplitBlockId = null;
    _pendingSplitOffset = 0;
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
    _pendingSplitBlockId = null;
    _pendingSplitOffset = 0;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    notifyListeners();
  }

  Future<void> playBlockAudio(String blockId) async {
    final block = _note.blocks.firstWhere((b) => b.id == blockId);
    if (block.path.isEmpty) return;
    _playingBlockId = blockId;
    await _player.play(DeviceFileSource(block.path));
  }

  Future<void> pausePlayback() async {
    await _player.pause();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recordingTimer?.cancel();
    _playerStateSubscription.cancel();
    _playerDurationSubscription.cancel();
    _playerPositionSubscription.cancel();
    _recorder?.dispose();
    _player.dispose();
    super.dispose();
  }
}
