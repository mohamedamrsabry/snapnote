import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/groq_transcription_service.dart';
import 'data/note_repository_impl.dart';
import 'data/settings_repository_impl.dart';
import 'data/tag_repository_impl.dart';
import 'domain/note_repository.dart';
import 'domain/settings_repository.dart';
import 'domain/tag_repository.dart';
import 'domain/transcription_service.dart';
import 'ui/view_models/notes_list_view_model.dart';
import 'ui/view_models/theme_view_model.dart';
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
        Provider<SettingsRepository>(create: (_) => SettingsRepositoryImpl()),
        Provider<TranscriptionService>(
          create: (_) => GroqTranscriptionService(),
        ),
        ChangeNotifierProvider<ThemeViewModel>(
          create: (context) =>
              ThemeViewModel(context.read<SettingsRepository>()),
        ),
      ],
      child: ChangeNotifierProvider<NotesListViewModel>(
        create: (context) => NotesListViewModel(
          context.read<NoteRepository>(),
          context.read<TagRepository>(),
        ),
        child: Consumer<ThemeViewModel>(
          builder: (context, themeViewModel, child) {
            return MaterialApp(
              title: 'SnapNote',
              themeMode: themeViewModel.themeMode,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF5F5F7),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.light,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFFF5F5F7),
                  elevation: 0,
                ),
              ),
              darkTheme: ThemeData(
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
            );
          },
        ),
      ),
    );
  }
}
