import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../domain/note.dart';
import '../domain/note_block.dart';
import '../domain/note_repository.dart';
import '../domain/tag_repository.dart';
import '../domain/transcription_service.dart';
import 'app_theme_colors.dart';
import 'go_live_button.dart';
import 'permission_request_screen.dart';
import 'swipe_action_button.dart';
import 'tag_colors.dart';
import 'view_models/live_note_view_model.dart';
import 'view_models/note_detail_view_model.dart';

class NoteDetailScreen extends StatelessWidget {
  final Note? existingNote;

  const NoteDetailScreen({super.key, this.existingNote});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NoteDetailViewModel>(
      create: (context) => NoteDetailViewModel(
        context.read<NoteRepository>(),
        context.read<TagRepository>(),
        context.read<TranscriptionService>(),
        existingNote: existingNote,
      ),
      child: const _NoteDetailView(),
    );
  }
}

class _NoteDetailView extends StatefulWidget {
  const _NoteDetailView();

  @override
  State<_NoteDetailView> createState() => _NoteDetailViewState();
}

class _NoteDetailViewState extends State<_NoteDetailView> {
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  final Map<String, TextEditingController> _blockControllers = {};
  final Map<String, FocusNode> _blockFocusNodes = {};
  String? _focusedBlockId;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<NoteDetailViewModel>();
    _titleController = TextEditingController(text: viewModel.note.title);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus && _focusedBlockId != null) {
        setState(() => _focusedBlockId = null);
      }
    });
    _syncControllers(viewModel.note.blocks);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    for (final controller in _blockControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _blockFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  // Keeps one TextEditingController + FocusNode per text block in sync
  // with the ViewModel's block list. Controllers for blocks that still
  // exist are left alone so the user's cursor position and typing aren't
  // disturbed, except when a block's text changed for a reason other than
  // that same controller's own onChanged (e.g. it was just split by an
  // inserted photo/recording), in which case the controller is updated to
  // match.
  void _syncControllers(List<NoteBlock> blocks) {
    final currentIds = blocks
        .where((b) => b.type == NoteBlockType.text)
        .map((b) => b.id)
        .toSet();
    final staleIds = _blockControllers.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _blockControllers.remove(id)?.dispose();
      _blockFocusNodes.remove(id)?.dispose();
    }

    for (final block in blocks) {
      if (block.type != NoteBlockType.text) continue;
      final existing = _blockControllers[block.id];
      if (existing == null) {
        _blockControllers[block.id] = TextEditingController(text: block.text);
        final focusNode = FocusNode();
        focusNode.addListener(() {
          if (focusNode.hasFocus) {
            setState(() => _focusedBlockId = block.id);
          } else if (_focusedBlockId == block.id) {
            setState(() => _focusedBlockId = null);
          }
        });
        _blockFocusNodes[block.id] = focusNode;
      } else if (existing.text != block.text) {
        existing.text = block.text;
      }
    }
  }

  void _focusEndOfNote(NoteDetailViewModel viewModel) {
    if (viewModel.note.isLocked) {
      _showLockedMessage();
      return;
    }
    NoteBlock? lastTextBlock;
    for (final block in viewModel.note.blocks.reversed) {
      if (block.type == NoteBlockType.text) {
        lastTextBlock = block;
        break;
      }
    }
    if (lastTextBlock == null) return;

    final controller = _blockControllers[lastTextBlock.id];
    final focusNode = _blockFocusNodes[lastTextBlock.id];
    if (controller == null || focusNode == null) return;
    focusNode.requestFocus();
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  void _showLockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This note is locked. Edits are disabled.')),
    );
  }

  Future<void> _showAddTagSheet() async {
    final viewModel = context.read<NoteDetailViewModel>();
    if (viewModel.note.isLocked) {
      _showLockedMessage();
      return;
    }
    final availableTags = await viewModel.getAvailableTags();
    final suggestedColor = await viewModel.getSuggestedTagColor();
    if (!mounted) return;

    final newTagController = TextEditingController();
    var selectedColor = suggestedColor;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (availableTags.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Choose a tag',
                        style: Theme.of(sheetContext).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    for (final tag in availableTags)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.label_outline),
                        title: Text(tag),
                        onTap: () {
                          viewModel.addTag(tag);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Create a new tag',
                    style: Theme.of(sheetContext).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newTagController,
                    autofocus: availableTags.isEmpty,
                    decoration: const InputDecoration(hintText: 'New tag name'),
                    onSubmitted: (value) {
                      viewModel.addTag(value, colorValue: selectedColor);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final color in tagColorPalette)
                        GestureDetector(
                          onTap: () => setSheetState(
                            () => selectedColor = color.toARGB32(),
                          ),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selectedColor == color.toARGB32()
                                  ? Border.all(color: Colors.black, width: 3)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () {
                        viewModel.addTag(
                          newTagController.text,
                          colorValue: selectedColor,
                        );
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBack() async {
    final viewModel = context.read<NoteDetailViewModel>();
    final liveViewModel = context.read<LiveNoteViewModel>();
    if (viewModel.isRecording) {
      await viewModel.stopRecording();
    }
    await viewModel.saveNow();
    await liveViewModel.refresh(viewModel.note);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleGoLivePressed() async {
    final viewModel = context.read<NoteDetailViewModel>();
    final liveViewModel = context.read<LiveNoteViewModel>();

    // Turning Live off never needs permission.
    if (liveViewModel.isLive(viewModel.note.id)) {
      await liveViewModel.toggle(viewModel.note);
      return;
    }
    if (viewModel.isNewNote) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a title or some text before going live.'),
        ),
      );
      return;
    }
    final granted = await ensurePermission(
      context,
      Permission.notification,
      'notifications',
    );
    if (!granted || !mounted) return;

    await viewModel.saveNow();
    await liveViewModel.toggle(viewModel.note);
  }

  void _handleAttachPressed() {
    final viewModel = context.read<NoteDetailViewModel>();
    if (viewModel.note.isLocked) {
      _showLockedMessage();
      return;
    }
    _showAttachmentMenu();
  }

  ({String? blockId, int offset}) _currentSplitPoint() {
    final blockId = _focusedBlockId;
    if (blockId == null) return (blockId: null, offset: 0);
    final offset = _blockControllers[blockId]?.selection.baseOffset ?? 0;
    return (blockId: blockId, offset: offset < 0 ? 0 : offset);
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: pillColor(context),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AttachmentMenuItem(
                  icon: Icons.camera_alt,
                  label: 'Take Photo',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                _AttachmentMenuItem(
                  icon: Icons.photo_library,
                  label: 'Choose Photo',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
                _AttachmentMenuItem(
                  icon: Icons.voicemail,
                  label: 'Record Audio',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _startRecording();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final granted = await ensurePermission(
        context,
        Permission.camera,
        'camera',
      );
      if (!granted) return;
    }

    if (!mounted) return;
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    if (!mounted) return;
    final split = _currentSplitPoint();
    await context.read<NoteDetailViewModel>().addPhoto(
      File(pickedFile.path),
      splitBlockId: split.blockId,
      splitOffset: split.offset,
    );
  }

  Future<void> _startRecording() async {
    final granted = await ensurePermission(
      context,
      Permission.microphone,
      'microphone',
    );
    if (!granted) return;

    if (!mounted) return;
    final viewModel = context.read<NoteDetailViewModel>();
    final split = _currentSplitPoint();

    // The recorder itself only starts once the user taps the record
    // button inside the modal — opening this menu item just opens the
    // modal. The modal can only be left via Stop (finalizes the memo) or
    // Cancel (discards it), never by swiping/tapping outside, so a
    // recording can never keep running in the background after the modal
    // closes.
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ChangeNotifierProvider<NoteDetailViewModel>.value(
        value: viewModel,
        child: _RecordingModal(
          splitBlockId: split.blockId,
          splitOffset: split.offset,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildBlock(
    BuildContext context,
    NoteDetailViewModel viewModel,
    NoteBlock block,
    bool isFirstBlock,
  ) {
    final locked = viewModel.note.isLocked;
    switch (block.type) {
      case NoteBlockType.text:
        return _buildTextBlock(viewModel, block, locked, isFirstBlock);
      case NoteBlockType.photo:
        return _buildPhotoBlock(viewModel, block, locked);
      case NoteBlockType.audio:
        return _buildAudioBlock(viewModel, block, locked);
    }
  }

  Widget _buildTextBlock(
    NoteDetailViewModel viewModel,
    NoteBlock block,
    bool locked,
    bool isFirstBlock,
  ) {
    final controller = _blockControllers[block.id]!;
    final focusNode = _blockFocusNodes[block.id]!;
    final isFocused = _focusedBlockId == block.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFocused && !locked)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StyleToggleButton(
                  icon: Icons.format_bold,
                  active: block.bold,
                  onPressed: () => viewModel.toggleBlockBold(block.id),
                ),
                const SizedBox(width: 8),
                _StyleToggleButton(
                  icon: Icons.format_italic,
                  active: block.italic,
                  onPressed: () => viewModel.toggleBlockItalic(block.id),
                ),
              ],
            ),
          ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: null,
          readOnly: locked,
          style: TextStyle(
            color: primaryTextColor(context),
            fontWeight: block.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: block.italic ? FontStyle.italic : FontStyle.normal,
          ),
          decoration: InputDecoration(
            hintText: isFirstBlock && block.text.isEmpty
                ? 'Start typing...'
                : null,
            hintStyle: TextStyle(color: secondaryTextColor(context, 0.38)),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onTap: locked ? _showLockedMessage : null,
          onChanged: locked
              ? null
              : (value) => _handleTextChanged(viewModel, block, value),
        ),
      ],
    );
  }

  // Pressing Enter inserts a newline into the controller's text before
  // this callback runs. Rather than let that newline live inside the same
  // block (which would force the whole paragraph to share one bold/italic
  // state), split it into a new block so the new paragraph can be styled
  // independently, then move focus there — matching where the cursor
  // would land after a normal Enter press.
  void _handleTextChanged(
    NoteDetailViewModel viewModel,
    NoteBlock block,
    String value,
  ) {
    if (!value.contains('\n')) {
      viewModel.updateBlockText(block.id, value);
      return;
    }
    viewModel.splitTextBlockIntoParagraphs(block.id, value.split('\n'));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final blocks = context.read<NoteDetailViewModel>().note.blocks;
      final index = blocks.indexWhere((b) => b.id == block.id);
      if (index == -1 || index + 1 >= blocks.length) return;
      final nextBlock = blocks[index + 1];
      if (nextBlock.type != NoteBlockType.text) return;
      final nextFocusNode = _blockFocusNodes[nextBlock.id];
      final nextController = _blockControllers[nextBlock.id];
      if (nextFocusNode == null || nextController == null) return;
      nextFocusNode.requestFocus();
      nextController.selection = TextSelection.collapsed(
        offset: nextController.text.length,
      );
    });
  }

  Widget _buildPhotoBlock(
    NoteDetailViewModel viewModel,
    NoteBlock block,
    bool locked,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(block.path),
                width: 160,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            if (!locked)
              Positioned(
                top: 6,
                right: 6,
                child: _RemoveBlockButton(
                  onTap: () => viewModel.removeBlock(block.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBlock(
    NoteDetailViewModel viewModel,
    NoteBlock block,
    bool locked,
  ) {
    if (block.path.isEmpty) return const SizedBox.shrink();

    final isPlaying = viewModel.isPlayingBlock(block.id);
    final status = viewModel.transcriptionStatusFor(block.id);
    final hasArea =
        !locked &&
        (block.transcript.isNotEmpty || status != TranscriptionStatus.idle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Slidable(
          key: ValueKey(block.id),
          groupTag: 'note-audio-blocks',
          enabled: !locked,
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.28,
            dismissible: DismissiblePane(
              closeOnCancel: true,
              onDismissed: () {},
              confirmDismiss: () async {
                viewModel.removeBlock(block.id);
                return false;
              },
            ),
            children: [
              CustomSlidableAction(
                onPressed: (_) => viewModel.removeBlock(block.id),
                backgroundColor: Colors.transparent,
                child: const SwipeActionButton(
                  icon: Icons.delete,
                  label: 'Delete',
                  color: Colors.red,
                ),
              ),
            ],
          ),
          child: Container(
            // Bottom margin stays constant (not shrunk when a transcript
            // area follows) so this pill's rendered height never dips
            // below what the swipe-to-delete action needs — shrinking it
            // for a tighter visual "hug" caused a real RenderFlex overflow
            // in SwipeActionButton's icon+label column.
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pillColor(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: primaryTextColor(context),
                  ),
                  onPressed: isPlaying
                      ? viewModel.pausePlayback
                      : () => viewModel.playBlockAudio(block.id),
                ),
                Text(
                  '${_formatDuration(viewModel.playbackPositionFor(block.id))} / '
                  '${_formatDuration(viewModel.voiceMemoDurationFor(block.id))}',
                  style: TextStyle(color: secondaryTextColor(context, 0.7)),
                ),
                const Spacer(),
                if (!locked)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: status == TranscriptionStatus.loading
                        ? Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: secondaryTextColor(context, 0.6),
                              ),
                            ),
                          )
                        : (block.transcript.isEmpty
                              ? IconButton(
                                  tooltip: 'Transcribe',
                                  icon: Icon(
                                    Icons.description_outlined,
                                    color: secondaryTextColor(
                                      context,
                                      viewModel.canTranscribe ? 0.7 : 0.3,
                                    ),
                                  ),
                                  onPressed: () =>
                                      viewModel.transcribeBlock(block.id),
                                )
                              : const SizedBox.shrink()),
                  ),
              ],
            ),
          ),
        ),
        if (hasArea) _buildTranscriptArea(viewModel, block, status),
      ],
    );
  }

  // Shared geometry for every state of the area under a memo: a short
  // vertical thread connecting it to the pill above, then an indented,
  // outlined box — so loading/ready/error all read as the same "thing
  // hanging off this memo" rather than three different widgets.
  Widget _transcriptShell({
    required BuildContext context,
    required Widget child,
    Color? borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Container(
            width: 2,
            height: 12,
            color: secondaryTextColor(context, 0.22),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor ?? secondaryTextColor(context, 0.18),
              ),
            ),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptArea(
    NoteDetailViewModel viewModel,
    NoteBlock block,
    TranscriptionStatus status,
  ) {
    if (status == TranscriptionStatus.loading) {
      return _transcriptShell(
        context: context,
        child: Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: secondaryTextColor(context, 0.45),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Transcribing…',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: secondaryTextColor(context, 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == TranscriptionStatus.error) {
      final errorColor = Theme.of(context).colorScheme.error;
      return _transcriptShell(
        context: context,
        borderColor: errorColor.withValues(alpha: 0.4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 14, color: errorColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viewModel.transcriptionErrorFor(block.id) ??
                        'Something went wrong.',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor(context, 0.62),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => viewModel.transcribeBlock(block.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 14,
                            color: primaryTextColor(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => viewModel.clearTranscriptionError(block.id),
              child: Icon(
                Icons.close,
                size: 14,
                color: secondaryTextColor(context, 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // Ready: a real transcript is sitting on the block, waiting to be
    // committed into the note body.
    return _transcriptShell(
      context: context,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => viewModel.commitTranscript(block.id),
          child: Semantics(
            button: true,
            label: 'Insert transcript into note',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.subtitles_outlined,
                  size: 14,
                  color: secondaryTextColor(context, 0.45),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.transcript,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontStyle: FontStyle.italic,
                          color: secondaryTextColor(context, 0.62),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to add to note',
                        style: TextStyle(
                          fontSize: 10,
                          color: secondaryTextColor(context, 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => viewModel.discardTranscript(block.id),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: secondaryTextColor(context, 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<NoteDetailViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: pillColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: primaryTextColor(context)),
              onPressed: _handleBack,
            ),
          ),
          actions: [
            if (viewModel.note.isLocked)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.lock),
              ),
          ],
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    readOnly: viewModel.note.isLocked,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                    ),
                    onTap: viewModel.note.isLocked ? _showLockedMessage : null,
                    onChanged: viewModel.note.isLocked
                        ? null
                        : viewModel.updateTitle,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Consumer<NoteDetailViewModel>(
                          builder: (context, viewModel, child) {
                            _syncControllers(viewModel.note.blocks);
                            return GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => _focusEndOfNote(viewModel),
                              child: SlidableAutoCloseBehavior(
                                child: SingleChildScrollView(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (
                                          var i = 0;
                                          i < viewModel.note.blocks.length;
                                          i++
                                        )
                                          _buildBlock(
                                            context,
                                            viewModel,
                                            viewModel.note.blocks[i],
                                            i == 0,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Consumer<NoteDetailViewModel>(
                builder: (context, viewModel, child) {
                  final tags = viewModel.note.tags;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer<LiveNoteViewModel>(
                        builder: (context, liveViewModel, child) =>
                            GoLiveButton(
                              isLive: liveViewModel.isLive(viewModel.note.id),
                              onPressed: liveViewModel.isBusy
                                  ? null
                                  : _handleGoLivePressed,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                for (final tag in tags)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: pillColor(context),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tag,
                                          style: TextStyle(
                                            color: primaryTextColor(context),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: viewModel.note.isLocked
                                              ? _showLockedMessage
                                              : () => viewModel.removeTag(tag),
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: secondaryTextColor(
                                              context,
                                              0.7,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Material(
                                  color: pillColor(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: _showAddTagSheet,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add,
                                            size: 16,
                                            color: primaryTextColor(context),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Add tag',
                                            style: TextStyle(
                                              color: primaryTextColor(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FloatingActionButton(
                            heroTag: 'noteAttachButton',
                            backgroundColor: pillColor(context),
                            foregroundColor: primaryTextColor(context),
                            shape: const CircleBorder(),
                            onPressed: _handleAttachPressed,
                            child: const Icon(Icons.attach_file),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: primaryTextColor(context), size: 26),
            const SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                color: primaryTextColor(context),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleToggleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  const _StyleToggleButton({
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? secondaryTextColor(context, 0.24) : pillColor(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: primaryTextColor(context)),
        ),
      ),
    );
  }
}

class _RemoveBlockButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RemoveBlockButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

class _RecordingModal extends StatefulWidget {
  final String? splitBlockId;
  final int splitOffset;

  const _RecordingModal({
    required this.splitBlockId,
    required this.splitOffset,
  });

  @override
  State<_RecordingModal> createState() => _RecordingModalState();
}

class _RecordingModalState extends State<_RecordingModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildPulseRing(double phaseOffset) {
    final t = (_pulseController.value + phaseOffset) % 1.0;
    final scale = 0.65 + t * 0.7;
    final opacity = (1 - t).clamp(0.0, 1.0) * 0.35;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCenterTap(NoteDetailViewModel viewModel) async {
    if (!viewModel.isRecording) {
      await viewModel.startRecording(
        splitBlockId: widget.splitBlockId,
        splitOffset: widget.splitOffset,
      );
      return;
    }
    await viewModel.stopRecording();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleCancelTap(NoteDetailViewModel viewModel) async {
    await viewModel.cancelRecording();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NoteDetailViewModel>();

    // Recording can only be left via the record button (stop, which keeps
    // the memo) or the cancel button (discards it) — never by swiping
    // down, tapping outside, or the system back gesture — so a recording
    // can never keep running unattended in the background.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'New Recording',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundIconButton(
                    icon: viewModel.isRecordingPaused ? Icons.mic : Icons.pause,
                    onPressed: viewModel.isRecordingPaused
                        ? viewModel.resumeRecording
                        : viewModel.pauseRecording,
                  ),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTap: () => _handleCenterTap(viewModel),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return SizedBox(
                          width: 140,
                          height: 140,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (viewModel.isRecording) ...[
                                _buildPulseRing(0),
                                _buildPulseRing(0.5),
                              ],
                              Container(
                                width: 84,
                                height: 84,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  viewModel.isRecording
                                      ? Icons.stop
                                      : Icons.mic,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 32),
                  _RoundIconButton(
                    icon: Icons.close,
                    onPressed: () => _handleCancelTap(viewModel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: Colors.black26)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: Colors.black87),
        ),
      ),
    );
  }
}
