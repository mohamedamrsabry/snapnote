import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'note_detail_screen.dart';
import 'view_models/notes_list_view_model.dart';

class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NotesListViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('SnapNote')),
      body: _buildBody(context, viewModel),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NoteDetailScreen()));
          viewModel.loadNotes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotesListViewModel viewModel) {
    switch (viewModel.status) {
      case NotesListStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case NotesListStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(viewModel.errorMessage ?? 'Something went wrong.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: viewModel.loadNotes,
                child: const Text('Retry'),
              ),
            ],
          ),
        );

      case NotesListStatus.empty:
        return const Center(
          child: Text('No notes yet. Tap + to create your first one.'),
        );

      case NotesListStatus.success:
        return ListView.builder(
          itemCount: viewModel.notes.length,
          itemBuilder: (context, index) {
            final note = viewModel.notes[index];
            return ListTile(
              title: Text(note.title.isEmpty ? '(Untitled)' : note.title),
              subtitle: Text(
                note.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NoteDetailScreen(existingNote: note),
                  ),
                );
                viewModel.loadNotes();
              },
            );
          },
        );
    }
  }
}
