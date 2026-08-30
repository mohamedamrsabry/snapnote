import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../domain/note.dart';
import 'app_theme_colors.dart';
import 'note_detail_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'share_note.dart';
import 'swipe_action_button.dart';
import 'view_models/notes_list_view_model.dart';

class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NotesListViewModel>();

    return Scaffold(
      appBar: _buildAppBar(context, viewModel),
      body: Stack(
        children: [
          Column(
            children: [
              if (!viewModel.isSelectionMode &&
                  viewModel.status == NotesListStatus.success &&
                  viewModel.allTags.isNotEmpty)
                _buildTagFilterRow(context, viewModel),
              Expanded(child: _buildBody(context, viewModel)),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 112,
            child: _UndoBanner(viewModel: viewModel),
          ),
        ],
      ),
      floatingActionButton: viewModel.isSelectionMode
          ? null
          : FloatingActionButton(
              backgroundColor: pillColor(context),
              foregroundColor: primaryTextColor(context),
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
          color: primaryTextColor(context),
        ),
      ),
      actions: [
        _AppBarPillButton(
          icon: Icons.search,
          onPressed: () async {
            await Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SearchScreen()));
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
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.edit_note,
                  size: 140,
                  color: secondaryTextColor(context, 0.24),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Create your first note !',
                style: TextStyle(
                  color: secondaryTextColor(context, 0.7),
                  fontSize: 20,
                ),
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
              color: secondaryTextColor(context, 0.24),
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
                  child: SwipeActionButton(
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
                  viewModel.deleteNoteWithUndo(note.id);
                  return false;
                },
              ),
              children: [
                CustomSlidableAction(
                  onPressed: (_) => viewModel.toggleLock(note.id),
                  backgroundColor: Colors.transparent,
                  child: SwipeActionButton(
                    icon: note.isLocked ? Icons.lock_open : Icons.lock,
                    label: note.isLocked ? 'Unlock' : 'Lock',
                    color: Colors.orange,
                  ),
                ),
                CustomSlidableAction(
                  onPressed: (_) => shareNote(note),
                  backgroundColor: Colors.transparent,
                  child: const SwipeActionButton(
                    icon: Icons.share,
                    label: 'Share',
                    color: Colors.green,
                  ),
                ),
                CustomSlidableAction(
                  onPressed: (_) => viewModel.deleteNoteWithUndo(note.id),
                  backgroundColor: Colors.transparent,
                  child: const SwipeActionButton(
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
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                // Decode at the grid cell's actual pixel
                                // size instead of the photo's full camera
                                // resolution — the cell size varies with
                                // screen width, so this is read from the
                                // real layout constraints rather than a
                                // guessed constant.
                                final dpr = MediaQuery.of(
                                  context,
                                ).devicePixelRatio;
                                return Image.file(
                                  File(note.photoPaths.first),
                                  fit: BoxFit.cover,
                                  cacheWidth: (constraints.maxWidth * dpr)
                                      .round(),
                                  cacheHeight: (constraints.maxHeight * dpr)
                                      .round(),
                                );
                              },
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

// Shows/hides purely off NotesListViewModel.pendingUndoNote — the same
// state the archive Timer itself updates — instead of a Flutter SnackBar,
// so its visibility can never drift out of sync with (or get stuck
// relative to) the actual pending delete.
class _UndoBanner extends StatelessWidget {
  final NotesListViewModel viewModel;

  const _UndoBanner({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final note = viewModel.pendingUndoNote;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: note == null
          ? const SizedBox.shrink(key: ValueKey('undo-banner-empty'))
          : Container(
              key: ValueKey('undo-banner-${note.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: (isDarkContext(context) ? Colors.black : Colors.white)
                    .withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Note deleted',
                      style: TextStyle(color: primaryTextColor(context)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => viewModel.undoDelete(note.id),
                    child: Text(
                      'Undo',
                      style: TextStyle(
                        color: primaryTextColor(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
        color: pillColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: primaryTextColor(context)),
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
        color: pillColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz, color: primaryTextColor(context)),
        onSelected: (value) async {
          switch (value) {
            case 'gallery':
              viewModel.toggleGalleryView();
            case 'select':
              viewModel.enterSelectionMode();
            case 'settings':
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              viewModel.loadNotes();
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
          const PopupMenuItem(value: 'settings', child: Text('Settings')),
        ],
      ),
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
