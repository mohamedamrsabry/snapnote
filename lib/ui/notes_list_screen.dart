import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/note.dart';
import 'note_detail_screen.dart';
import 'search_screen.dart';
import 'view_models/notes_list_view_model.dart';

class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NotesListViewModel>();

    return Scaffold(
      appBar: _buildAppBar(context, viewModel),
      body: _buildBody(context, viewModel),
      floatingActionButton: viewModel.isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NoteDetailScreen()),
                );
                viewModel.loadNotes();
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    NotesListViewModel viewModel,
  ) {
    if (viewModel.isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: viewModel.exitSelectionMode,
        ),
        title: Text('${viewModel.selectedNoteIds.length} selected'),
        actions: [
          TextButton(
            onPressed: viewModel.deleteSelectedOrAll,
            child: Text(
              viewModel.selectedNoteIds.isEmpty ? 'Delete All' : 'Delete',
            ),
          ),
        ],
      );
    }

    return AppBar(
      title: const Text('SnapNote'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () async {
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
            viewModel.loadNotes();
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'gallery':
                viewModel.toggleGalleryView();
              case 'select':
                viewModel.enterSelectionMode();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'gallery',
              child: Text(
                viewModel.isGalleryView ? 'View as List' : 'View as Gallery',
              ),
            ),
            const PopupMenuItem(value: 'select', child: Text('Select Notes')),
          ],
        ),
      ],
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
        return viewModel.isGalleryView
            ? _buildGallery(context, viewModel)
            : _buildList(context, viewModel);
    }
  }

  Future<void> _handleTap(
    BuildContext context,
    NotesListViewModel viewModel,
    Note note,
  ) async {
    if (viewModel.isSelectionMode) {
      viewModel.toggleNoteSelection(note.id);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteDetailScreen(existingNote: note)),
    );
    viewModel.loadNotes();
  }

  Widget _buildList(BuildContext context, NotesListViewModel viewModel) {
    return ListView.builder(
      itemCount: viewModel.notes.length,
      itemBuilder: (context, index) {
        final note = viewModel.notes[index];
        final isSelected = viewModel.selectedNoteIds.contains(note.id);
        return ListTile(
          leading: viewModel.isSelectionMode
              ? Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                )
              : null,
          title: Text(note.title.isEmpty ? '(Untitled)' : note.title),
          subtitle: Text(
            note.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _handleTap(context, viewModel, note),
        );
      },
    );
  }

  Widget _buildGallery(BuildContext context, NotesListViewModel viewModel) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: viewModel.notes.length,
      itemBuilder: (context, index) {
        final note = viewModel.notes[index];
        final isSelected = viewModel.selectedNoteIds.contains(note.id);
        return InkWell(
          onTap: () => _handleTap(context, viewModel, note),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: note.photoPaths.isNotEmpty
                          ? Image.file(
                              File(note.photoPaths.first),
                              fit: BoxFit.cover,
                            )
                          : ColoredBox(
                              color: const Color(0x11000000),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  note.body,
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        note.title.isEmpty ? '(Untitled)' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (viewModel.isSelectionMode)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
