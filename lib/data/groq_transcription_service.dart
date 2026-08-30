import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/transcription_service.dart';

// Transcribes a saved audio file via Groq's OpenAI-compatible Whisper
// endpoint. This runs strictly AFTER a memo has finished recording — never
// while the recorder holds the mic — which is what makes it safe: unlike
// live on-device recognition (tried first, reverted — see README), a file
// upload can never contend for the microphone with AudioRecorder.
class GroqTranscriptionService implements TranscriptionService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const _model = 'whisper-large-v3-turbo';
  static const _maxBytes = 25 * 1024 * 1024; // Groq free-tier cap
  static const _timeout = Duration(seconds: 60);

  final String _apiKey;
  final http.Client _client;

  GroqTranscriptionService({
    http.Client? client,
    this._apiKey = const String.fromEnvironment('GROQ_API_KEY'),
  }) : _client = client ?? http.Client();

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (!isConfigured) {
      throw const TranscriptionException(TranscriptionErrorKind.notConfigured);
    }

    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw const TranscriptionException(TranscriptionErrorKind.fileMissing);
    }
    if (await file.length() > _maxBytes) {
      throw const TranscriptionException(TranscriptionErrorKind.fileTooLarge);
    }

    late final http.Response response;
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = _model
        ..fields['response_format'] = 'json'
        ..files.add(await http.MultipartFile.fromPath('file', audioFilePath));

      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw const TranscriptionException(TranscriptionErrorKind.network);
    } on TimeoutException {
      throw const TranscriptionException(TranscriptionErrorKind.network);
    } on http.ClientException {
      throw const TranscriptionException(TranscriptionErrorKind.network);
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const TranscriptionException(TranscriptionErrorKind.unauthorized);
      case 413:
        throw const TranscriptionException(TranscriptionErrorKind.fileTooLarge);
      case 429:
        throw const TranscriptionException(TranscriptionErrorKind.rateLimited);
      default:
        throw TranscriptionException(
          TranscriptionErrorKind.server,
          detail: '${response.statusCode} ${response.body}',
        );
    }

    final String text;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      text = (decoded['text'] as String? ?? '').trim();
    } catch (e) {
      throw TranscriptionException(
        TranscriptionErrorKind.server,
        detail: 'Unparseable response: $e',
      );
    }

    if (text.isEmpty) {
      throw const TranscriptionException(TranscriptionErrorKind.emptyResult);
    }
    return text;
  }
}
