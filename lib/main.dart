import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/note_repository_impl.dart';
import 'data/tag_repository_impl.dart';
import 'domain/note_repository.dart';
import 'domain/tag_repository.dart';
import 'ui/view_models/notes_list_view_model.dart';
import 'ui/notes_list_screen.dart';

void main() {
  runApp(const SnapNoteApp());
}

class SnapNoteApp extends StatelessWidget {
  const SnapNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<NoteRepository>(create: (_) => NoteRepositoryImpl()),
        Provider<TagRepository>(create: (_) => TagRepositoryImpl()),
      ],
      child: ChangeNotifierProvider<NotesListViewModel>(
        create: (context) => NotesListViewModel(
          context.read<NoteRepository>(),
          context.read<TagRepository>(),
        ),
        child: MaterialApp(
          title: 'SnapNote',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF1C1C1E),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1C1C1E),
              elevation: 0,
            ),
          ),
          home: const NotesListScreen(),
        ),
      ),
    );
  }
}
