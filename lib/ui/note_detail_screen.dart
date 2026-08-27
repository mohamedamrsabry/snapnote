import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../domain/note.dart';
import '../domain/note_repository.dart';
import 'permission_request_screen.dart';
import 'share_note.dart';
import 'view_models/note_detail_view_model.dart';

class NoteDetailScreen extends StatelessWidget {
  final Note? existingNote;

  const NoteDetailScreen({super.key, this.existingNote});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NoteDetailViewModel>(
      create: (context) => NoteDetailViewModel(
        context.read<NoteRepository>(),
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
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<NoteDetailViewModel>();
    _titleController = TextEditingController(text: viewModel.note.title);
    _bodyController = TextEditingController(text: viewModel.note.body);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _showLockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This note is locked. Edits are disabled.'),
      ),
    );
  }

  Future<void> _showAddTagSheet() async {
    final viewModel = context.read<NoteDetailViewModel>();
    if (viewModel.note.isLocked) {
      _showLockedMessage();
      return;
    }
    final availableTags = await viewModel.getAvailableTags();
    if (!mounted) return;

    final newTagController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: SafeArea(
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
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newTagController,
                autofocus: availableTags.isEmpty,
                decoration: const InputDecoration(hintText: 'New tag name'),
                onSubmitted: (value) {
                  viewModel.addTag(value);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBack() async {
    final viewModel = context.read<NoteDetailViewModel>();
    if (viewModel.isRecording) {
      await viewModel.stopRecording();
    }
    await viewModel.saveNow();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleShare() async {
    final note = context.read<NoteDetailViewModel>().note;
    await shareNote(note);
  }

  void _handleAttachPressed() {
    final viewModel = context.read<NoteDetailViewModel>();
    if (viewModel.note.isLocked) {
      _showLockedMessage();
      return;
    }
    _showAttachmentMenu();
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose Photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('Record Audio'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _startRecording();
              },
            ),
          ],
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
    await context.read<NoteDetailViewModel>().addPhoto(File(pickedFile.path));
  }

  Future<void> _startRecording() async {
    final granted = await ensurePermission(
      context,
      Permission.microphone,
      'microphone',
    );
    if (!granted) return;

    if (!mounted) return;
    await context.read<NoteDetailViewModel>().startRecording();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          actions: [
            if (viewModel.note.isLocked)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.lock),
              ),
            IconButton(icon: const Icon(Icons.share), onPressed: _handleShare),
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _handleAttachPressed,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                style: Theme.of(context).textTheme.headlineSmall,
                readOnly: viewModel.note.isLocked,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
                onTap: viewModel.note.isLocked ? _showLockedMessage : null,
                onChanged: viewModel.note.isLocked ? null : viewModel.updateTitle,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  readOnly: viewModel.note.isLocked,
                  decoration: const InputDecoration(
                    hintText: 'Start typing...',
                    border: InputBorder.none,
                  ),
                  onTap: viewModel.note.isLocked ? _showLockedMessage : null,
                  onChanged: viewModel.note.isLocked ? null : viewModel.updateBody,
                ),
              ),
              Consumer<NoteDetailViewModel>(
                builder: (context, viewModel, child) {
                  final tags = viewModel.note.tags;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final tag in tags)
                          Chip(
                            label: Text(tag),
                            onDeleted: viewModel.note.isLocked
                                ? _showLockedMessage
                                : () => viewModel.removeTag(tag),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('Add tag'),
                          onPressed: _showAddTagSheet,
                        ),
                      ],
                    ),
                  );
                },
              ),
              Consumer<NoteDetailViewModel>(
                builder: (context, viewModel, child) {
                  final photoPaths = viewModel.note.photoPaths;
                  if (photoPaths.isEmpty) return const SizedBox.shrink();

                  return SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photoPaths.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(photoPaths[index]),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Consumer<NoteDetailViewModel>(
                builder: (context, viewModel, child) {
                  if (viewModel.isRecording) {
                    return Row(
                      children: [
                        const Icon(Icons.mic, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Recording... ${_formatDuration(viewModel.recordingDuration)}',
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.stop),
                          onPressed: viewModel.stopRecording,
                        ),
                      ],
                    );
                  }

                  if (viewModel.note.voiceMemoPath != null) {
                    return Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            viewModel.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          onPressed: viewModel.isPlaying
                              ? viewModel.pausePlayback
                              : viewModel.playVoiceMemo,
                        ),
                        const Text('Voice memo'),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatDuration(viewModel.playbackPosition)} / ${_formatDuration(viewModel.voiceMemoDuration)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: viewModel.note.isLocked
                              ? _showLockedMessage
                              : viewModel.deleteVoiceMemo,
                        ),
                      ],
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
