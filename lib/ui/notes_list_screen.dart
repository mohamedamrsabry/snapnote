import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../domain/note.dart';
import 'note_detail_screen.dart';
import 'search_screen.dart';
import 'share_note.dart';
import 'view_models/notes_list_view_model.dart';

const _pillColor = Color(0xFF2C2C2E);

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
              backgroundColor: _pillColor,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
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
      title: Text(
        'SnapNote',
        style: GoogleFonts.fredoka(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        _AppBarPillButton(
          icon: Icons.search,
          onPressed: () async {
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
            viewModel.loadNotes();
          },
        ),
        _AppBarPillMenu(viewModel: viewModel),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTagFilterRow(
    BuildContext context,
    NotesListViewModel viewModel,
  ) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: viewModel.allTags.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = viewModel.allTags[index];
          final tagColor = viewModel.colorForTagName(tag);
          final selected = viewModel.selectedTagFilter == tag;
          return ChoiceChip(
            label: Text(
              tag,
              style: TextStyle(color: selected ? Colors.black87 : tagColor),
            ),
            backgroundColor: tagColor.withValues(alpha: 0.15),
            selectedColor: tagColor,
            selected: selected,
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
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/rafiki.png',
                width: 280,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.edit_note,
                  size: 140,
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Create your first note !',
                style: TextStyle(color: Colors.white70, fontSize: 20),
              ),
            ],
          ),
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

  void _deleteWithUndo(
    BuildContext context,
    NotesListViewModel viewModel,
    String noteId,
  ) {
    viewModel.deleteNoteWithUndo(noteId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note deleted'),
        duration: NotesListViewModel.undoWindow,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => viewModel.undoDelete(noteId),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, NotesListViewModel viewModel) {
    final notes = viewModel.filteredNotes;
    final pinnedCount = viewModel.pinnedCount;
    final hasDivider = pinnedCount > 0 && pinnedCount < notes.length;

    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: notes.length + (hasDivider ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasDivider && index == pinnedCount) {
            return Divider(
              height: 25,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: Colors.white24,
            );
          }

          final noteIndex = hasDivider && index > pinnedCount
              ? index - 1
              : index;
          final note = notes[noteIndex];
          final isSelected = viewModel.selectedNoteIds.contains(note.id);
          return Slidable(
            key: ValueKey(note.id),
            groupTag: 'notes-list',
            enabled: !viewModel.isSelectionMode,
            startActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.25,
              dismissible: DismissiblePane(
                closeOnCancel: true,
                onDismissed: () {},
                confirmDismiss: () async {
                  viewModel.togglePin(note.id);
                  return false;
                },
              ),
              children: [
                CustomSlidableAction(
                  onPressed: (_) => viewModel.togglePin(note.id),
                  backgroundColor: Colors.transparent,
                  child: _SwipeActionButton(
                    icon: note.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    label: note.isPinned ? 'Unpin' : 'Pin',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.72,
              dismissible: DismissiblePane(
                closeOnCancel: true,
                onDismissed: () {},
                confirmDismiss: () async {
                  _deleteWithUndo(context, viewModel, note.id);
                  return false;
                },
              ),
              children: [
                CustomSlidableAction(
                  onPressed: (_) => viewModel.toggleLock(note.id),
                  backgroundColor: Colors.transparent,
                  child: _SwipeActionButton(
                    icon: note.isLocked ? Icons.lock_open : Icons.lock,
                    label: note.isLocked ? 'Unlock' : 'Lock',
                    color: Colors.orange,
                  ),
                ),
                CustomSlidableAction(
                  onPressed: (_) => shareNote(note),
                  backgroundColor: Colors.transparent,
                  child: const _SwipeActionButton(
                    icon: Icons.share,
                    label: 'Share',
                    color: Colors.green,
                  ),
                ),
                CustomSlidableAction(
                  onPressed: (actionContext) =>
                      _deleteWithUndo(actionContext, viewModel, note.id),
                  backgroundColor: Colors.transparent,
                  child: const _SwipeActionButton(
                    icon: Icons.delete,
                    label: 'Delete',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            child: _NoteCard(
              note: note,
              color: viewModel.colorForNote(note),
              isSelectionMode: viewModel.isSelectionMode,
              isSelected: isSelected,
              onTap: () => _handleTap(context, viewModel, note),
            ),
          );
        },
      ),
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
            color: viewModel.colorForNote(note),
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
                          : Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                note.body,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        note.title.isEmpty ? '(Untitled)' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87),
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
                      color: Colors.black87,
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

class _AppBarPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _AppBarPillButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _pillColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

class _AppBarPillMenu extends StatelessWidget {
  final NotesListViewModel viewModel;

  const _AppBarPillMenu({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _pillColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, color: Colors.white),
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
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SwipeActionButton({
    required this.icon,
    required this.label,
    required this.color,
  });

  // At rest each action only gets its normal reveal width (a quarter of the
  // screen or less), so it renders as a small floating circle. Keep
  // swiping past the button reveal and flutter_slidable's dismiss motion
  // grows the furthest action's width toward the full screen width — past
  // that point this switches to a filled rounded rect that stretches to
  // fill the growing space, so it visually expands as the swipe nears the
  // edge, and releasing there triggers the action instead of just tapping.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandThreshold = MediaQuery.sizeOf(context).width * 0.32;
        final isExpanding = constraints.maxWidth > expandThreshold;

        if (!isExpanding) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final Color color;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;

  const _NoteCard({
    required this.note,
    required this.color,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                if (isSelectionMode) ...[
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: Colors.black87,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    note.title.isEmpty ? '(Untitled)' : note.title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!isSelectionMode && (note.isPinned || note.isLocked))
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (note.isPinned)
                          const Icon(
                            Icons.push_pin,
                            size: 16,
                            color: Colors.black54,
                          ),
                        if (note.isPinned && note.isLocked)
                          const SizedBox(width: 4),
                        if (note.isLocked)
                          const Icon(
                            Icons.lock,
                            size: 16,
                            color: Colors.black54,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
