import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/note_repository_impl.dart';
import 'domain/note_repository.dart';
import 'ui/view_models/notes_list_view_model.dart';
import 'ui/notes_list_screen.dart';

void main() {
  runApp(const SnapNoteApp());
}

class SnapNoteApp extends StatelessWidget {
  const SnapNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<NoteRepository>(
      create: (_) => NoteRepositoryImpl(),
      child: ChangeNotifierProvider<NotesListViewModel>(
        create: (context) => NotesListViewModel(context.read<NoteRepository>()),
        child: MaterialApp(
          title: 'SnapNote',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          home: const NotesListScreen(),
        ),
      ),
    );
  }
}
