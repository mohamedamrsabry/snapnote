import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/note_repository.dart';
import 'note_detail_screen.dart';
import 'view_models/search_view_model.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SearchViewModel>(
      create: (context) => SearchViewModel(context.read<NoteRepository>()),
      child: const _SearchView(),
    );
  }
}

class _FilterInfo {
  final SearchFilter filter;
  final IconData icon;
  final String label;

  const _FilterInfo(this.filter, this.icon, this.label);
}

const _filters = [
  _FilterInfo(SearchFilter.lockedNotes, Icons.lock_outline, 'Locked Notes'),
  _FilterInfo(
    SearchFilter.checklists,
    Icons.check_box_outlined,
    'Notes with Checklists',
  ),
  _FilterInfo(SearchFilter.images, Icons.image_outlined, 'Notes with Images'),
  _FilterInfo(
    SearchFilter.recordings,
    Icons.mic_none,
    'Notes with Recordings',
  ),
];

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SearchViewModel>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search by the title and body text...',
            border: InputBorder.none,
            suffixIcon: viewModel.query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      viewModel.clear();
                    },
                  )
                : null,
          ),
          onChanged: viewModel.updateQuery,
        ),
      ),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, SearchViewModel viewModel) {
    if (viewModel.isBrowsing) {
      return ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Filters', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final info in _filters)
            ListTile(
              leading: Icon(info.icon),
              title: Text(info.label),
              trailing: viewModel.activeFilters.contains(info.filter)
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => viewModel.toggleFilter(info.filter),
            ),
        ],
      );
    }

    final results = viewModel.results;

    if (results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48),
            SizedBox(height: 16),
            Text('File not found. Try searching again.'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final note = results[index];
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
            viewModel.reload();
          },
        );
      },
    );
  }
}
