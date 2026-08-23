import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/note.dart';
import '../domain/note_repository.dart';
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
    await context.read<NoteDetailViewModel>().saveNow();
    if (mounted) Navigator.of(context).pop();
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
            ],
          ),
        ),
      ),
    );
  }
}
