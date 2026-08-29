import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/note_repository.dart';
import 'app_theme_colors.dart';
import 'view_models/archived_notes_view_model.dart';

class ArchivedNotesScreen extends StatelessWidget {
  const ArchivedNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ArchivedNotesViewModel>(
      create: (context) =>
          ArchivedNotesViewModel(context.read<NoteRepository>()),
      child: const _ArchivedNotesView(),
    );
  }
}

class _ArchivedNotesView extends StatelessWidget {
  const _ArchivedNotesView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ArchivedNotesViewModel>();

    return Scaffold(
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: pillColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryTextColor(context)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'Archived Notes',
          style: TextStyle(
            color: primaryTextColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, ArchivedNotesViewModel viewModel) {
    switch (viewModel.status) {
      case ArchivedNotesStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case ArchivedNotesStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                viewModel.errorMessage ?? 'Something went wrong.',
                style: TextStyle(color: primaryTextColor(context)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: viewModel.load,
                child: const Text('Retry'),
              ),
            ],
          ),
        );

      case ArchivedNotesStatus.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'No archived notes.\nDeleted notes stay here for 3 days before being removed for good.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryTextColor(context)),
            ),
          ),
        );

      case ArchivedNotesStatus.success:
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: viewModel.notes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final note = viewModel.notes[index];
            final daysLeft = viewModel.daysRemaining(note);
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: pillColor(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title.isEmpty ? '(Untitled)' : note.title,
                          style: TextStyle(
                            color: primaryTextColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          daysLeft <= 1
                              ? 'Deletes in less than a day'
                              : 'Deletes in $daysLeft days',
                          style: TextStyle(
                            color: secondaryTextColor(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.restore, color: primaryTextColor(context)),
                    tooltip: 'Restore',
                    onPressed: () => viewModel.restore(note.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    tooltip: 'Delete now',
                    onPressed: () => viewModel.deleteNow(note.id),
                  ),
                ],
              ),
            );
          },
        );
    }
  }
}
