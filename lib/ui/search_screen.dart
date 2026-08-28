import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/note_repository.dart';
import 'note_detail_screen.dart';
import 'view_models/search_view_model.dart';

const _pillColor = Color(0xFF2C2C2E);

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
  final String label;

  const _FilterInfo(this.filter, this.label);
}

const _filters = [
  _FilterInfo(SearchFilter.lockedNotes, 'Locked Notes'),
  _FilterInfo(SearchFilter.checklists, 'Notes with Checklists'),
  _FilterInfo(SearchFilter.images, 'Notes with Images'),
  _FilterInfo(SearchFilter.recordings, 'Notes with Recordings'),
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
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: _pillColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by the title and body text...',
              hintStyle: const TextStyle(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              suffixIcon: viewModel.query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
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
      ),
      body: Column(
        children: [
          if (viewModel.query.isEmpty) _buildFilterSection(context, viewModel),
          Expanded(child: _buildBody(context, viewModel)),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, SearchViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _pillColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                for (final info in _filters)
                  Column(
                    children: [
                      ListTile(
                        title: Text(
                          info.label,
                          style: TextStyle(
                            color: viewModel.activeFilters.contains(
                              info.filter,
                            )
                                ? Colors.white
                                : Colors.white70,
                          ),
                        ),
                        trailing: viewModel.activeFilters.contains(info.filter)
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                        onTap: () => viewModel.toggleFilter(info.filter),
                      ),
                      if (info != _filters.last)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Colors.white24,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchViewModel viewModel) {
    if (viewModel.isBrowsing) {
      return const Center(
        child: Text(
          'Type to search, or pick a filter above.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final results = viewModel.results;

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/cuate.png',
              width: 260,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.search_off,
                size: 96,
                color: Colors.white24,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'File not found. Try searching again.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final note = results[index];
        return ListTile(
          title: Text(
            note.title.isEmpty ? '(Untitled)' : note.title,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            note.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54),
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
