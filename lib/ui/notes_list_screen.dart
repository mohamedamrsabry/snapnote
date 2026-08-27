import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../domain/note.dart';
import 'note_detail_screen.dart';
import 'search_screen.dart';
import 'share_note.dart';
import 'view_models/notes_list_view_model.dart';

class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NotesListViewModel>();

    return Scaffold(
      appBar: _buildAppBar(context, viewModel),
      body: Column(
        children: [
          if (!viewModel.isSelectionMode &&
              viewModel.status == NotesListStatus.success &&
              viewModel.allTags.isNotEmpty)
            _buildTagFilterRow(context, viewModel),
          Expanded(child: _buildBody(context, viewModel)),
        ],
      ),
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

  Widget _buildTagFilterRow(BuildContext context, NotesListViewModel viewModel) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: viewModel.allTags.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = viewModel.allTags[index];
          return ChoiceChip(
            label: Text(tag),
            selected: viewModel.selectedTagFilter == tag,
            onSelected: (_) => viewModel.selectTagFilter(tag),
          );
        },
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
        if (viewModel.filteredNotes.isEmpty) {
          return const Center(child: Text('No notes with this tag.'));
        }
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
    final notes = viewModel.filteredNotes;
    final pinnedCount = viewModel.pinnedCount;
    final hasDivider = pinnedCount > 0 && pinnedCount < notes.length;

    return ListView.builder(
      itemCount: notes.length + (hasDivider ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasDivider && index == pinnedCount) {
          return Divider(
            height: 25,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          );
        }

        final noteIndex = hasDivider && index > pinnedCount
            ? index - 1
            : index;
        final note = notes[noteIndex];
        final isSelected = viewModel.selectedNoteIds.contains(note.id);
        return Slidable(
          key: ValueKey(note.id),
          enabled: !viewModel.isSelectionMode,
          startActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (_) => viewModel.togglePin(note.id),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                icon: note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: note.isPinned ? 'Unpin' : 'Pin',
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.72,
            children: [
              SlidableAction(
                onPressed: (_) => viewModel.toggleLock(note.id),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                icon: note.isLocked ? Icons.lock_open : Icons.lock,
                label: note.isLocked ? 'Unlock' : 'Lock',
              ),
              SlidableAction(
                onPressed: (_) => shareNote(note),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                icon: Icons.share,
                label: 'Share',
              ),
              SlidableAction(
                onPressed: (_) => viewModel.deleteNote(note.id),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: 'Delete',
              ),
            ],
          ),
          child: ListTile(
            leading: viewModel.isSelectionMode
                ? Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  )
                : null,
            title: Text(note.title.isEmpty ? '(Untitled)' : note.title),
            subtitle: Text(
              note.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: !viewModel.isSelectionMode && (note.isPinned || note.isLocked)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (note.isPinned)
                        const Icon(Icons.push_pin, size: 16),
                      if (note.isPinned && note.isLocked)
                        const SizedBox(width: 4),
                      if (note.isLocked)
                        const Icon(Icons.lock, size: 16),
                    ],
                  )
                : null,
            onTap: () => _handleTap(context, viewModel, note),
          ),
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
      itemCount: viewModel.filteredNotes.length,
      itemBuilder: (context, index) {
        final note = viewModel.filteredNotes[index];
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
