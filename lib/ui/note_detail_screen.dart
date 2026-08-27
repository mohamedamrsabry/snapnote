import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../domain/note.dart';
import '../domain/note_repository.dart';
import 'permission_request_screen.dart';
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

  Future<void> _handleBack() async {
    final viewModel = context.read<NoteDetailViewModel>();
    if (viewModel.isRecording) {
      await viewModel.stopRecording();
    }
    await viewModel.saveNow();
    if (mounted) Navigator.of(context).pop();
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
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _showAttachmentMenu,
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
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
                onChanged: viewModel.updateTitle,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Start typing...',
                    border: InputBorder.none,
                  ),
                  onChanged: viewModel.updateBody,
                ),
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
                          onPressed: viewModel.deleteVoiceMemo,
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
