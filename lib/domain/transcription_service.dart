enum TranscriptionErrorKind {
  notConfigured,
  network,
  unauthorized,
  rateLimited,
  fileMissing,
  fileTooLarge,
  emptyResult,
  server,
}

class TranscriptionException implements Exception {
  final TranscriptionErrorKind kind;
  final String? detail;

  const TranscriptionException(this.kind, {this.detail});

  @override
  String toString() => 'TranscriptionException($kind, $detail)';
}

// Turns a saved voice-memo audio file into text. Intentionally takes a
// file path rather than a File so the domain layer stays free of dart:io,
// and so a fake implementation needs no real filesystem for tests.
abstract class TranscriptionService {
  // Whether this build has the credentials needed to transcribe at all.
  // Synchronous and network-free — the UI reads it to decide how to
  // render the transcribe button before the user ever taps it.
  bool get isConfigured;

  // Throws a TranscriptionException for every failure mode, including an
  // empty/no-speech result — modelled as an error so it lands in the
  // retry UI rather than silently doing nothing.
  Future<String> transcribe(String audioFilePath);
}
