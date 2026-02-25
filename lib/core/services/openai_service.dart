import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/message.dart';

const _kBaseUrl = 'https://api.openai.com/v1';
const _kChatEndpoint = '$_kBaseUrl/chat/completions';

/// Thin wrapper around the OpenAI Chat Completions API.
///
/// Supports both streaming (SSE) and non-streaming calls. The API key is
/// injected per-call so it is never stored inside this service.
class OpenAIService {
  final http.Client _client;

  OpenAIService({http.Client? client}) : _client = client ?? http.Client();

  /// Streams the assistant's reply token by token.
  ///
  /// [messages] is the full conversation history to send as context.
  /// Yields each text delta as it arrives from the SSE stream.
  Stream<String> streamChat({
    required String apiKey,
    required String model,
    required List<Message> messages,
    double temperature = 0.7,
  }) async* {
    final request = http.Request('POST', Uri.parse(_kChatEndpoint));
    request.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    });
    request.body = jsonEncode({
      'model': model,
      'stream': true,
      'temperature': temperature,
      'messages': messages.map(_messageToMap).toList(),
    });

    late http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (e) {
      throw OpenAIException('Network error: $e');
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final errorMsg =
          (decoded['error'] as Map?)?['message'] as String? ?? body;
      throw OpenAIException('API error ${response.statusCode}: $errorMsg');
    }

    // SSE stream — accumulate partial lines across chunks
    final buffer = StringBuffer();

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      final raw = buffer.toString();
      final lines = raw.split('\n');

      // Keep the last potentially-incomplete line in the buffer
      buffer.clear();
      buffer.write(lines.last);

      for (final line in lines.sublist(0, lines.length - 1)) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;

        final payload = trimmed.substring(5).trim();
        if (payload == '[DONE]') return;
        if (payload.isEmpty) continue;

        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;

          final delta =
              (choices.first as Map<String, dynamic>)['delta'] as Map?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {
          // Malformed JSON chunk — skip silently
        }
      }
    }
  }

  /// Returns a list of available chat-capable model IDs.
  Future<List<String>> fetchModels({required String apiKey}) async {
    final response = await _client.get(
      Uri.parse('$_kBaseUrl/models'),
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode != 200) {
      throw OpenAIException(
          'Failed to fetch models: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = (data['data'] as List<dynamic>)
        .map((m) => (m as Map<String, dynamic>)['id'] as String)
        .where((id) => id.startsWith('gpt-'))
        .toList()
      ..sort();
    return models;
  }

  static Map<String, dynamic> _messageToMap(Message msg) => {
        'role': msg.role.name,
        'content': msg.content,
      };

  void dispose() => _client.close();
}

class OpenAIException implements Exception {
  final String message;
  const OpenAIException(this.message);

  @override
  String toString() => 'OpenAIException: $message';
}
