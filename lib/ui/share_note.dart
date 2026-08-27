import 'package:share_plus/share_plus.dart';

import '../domain/note.dart';

Future<void> shareNote(Note note) async {
  final textParts = <String>[
    if (note.title.isNotEmpty) note.title,
    if (note.body.isNotEmpty) note.body,
  ];
  final shareText = textParts.join('\n\n');

  if (note.photoPaths.isNotEmpty) {
    await Share.shareXFiles(
      note.photoPaths.map((path) => XFile(path)).toList(),
      text: shareText.isEmpty ? null : shareText,
    );
  } else if (shareText.isNotEmpty) {
    await Share.share(shareText);
  }
}
