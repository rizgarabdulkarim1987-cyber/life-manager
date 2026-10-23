import 'dart:convert';
import 'dart:typed_data';

import '../../../core/net/http_port.dart';
import 'ai_config.dart';

/// No subclass carries a response body or the key, so they are safe to log.
sealed class GroqError implements Exception {
  const GroqError();
}

/// 401/403, or no key saved.
class GroqUnauthorized extends GroqError {
  const GroqUnauthorized();
}

class GroqRateLimited extends GroqError {
  const GroqRateLimited();
}

class GroqServerError extends GroqError {
  const GroqServerError(this.status);

  final int status;

  @override
  String toString() => 'GroqServerError($status)';
}

/// No connection, DNS failure, TLS failure or timeout.
class GroqNetworkError extends GroqError {
  const GroqNetworkError();
}

class GroqBadResponse extends GroqError {
  const GroqBadResponse();
}

const kGroqBase = 'https://api.groq.com/openai/v1';
const kChatTimeout = Duration(seconds: 15);
const kSttTimeout = Duration(seconds: 30);
const kVisionTimeout = Duration(seconds: 40);

class GroqClient {
  GroqClient(this._http, this._keys);

  final HttpPort _http;
  final GroqKeyStore _keys;

  Future<(String, Map<String, String>)> _auth() async {
    final c = await _keys.credential();
    if (c == null) throw const GroqUnauthorized();
    return (c.base, {'Authorization': 'Bearer ${c.secret.value}'});
  }

  Future<HttpReply> _send(Future<HttpReply> Function() call) async {
    final HttpReply r;
    try {
      r = await call();
    } on GroqError {
      rethrow;
    } catch (_) {
      throw const GroqNetworkError();
    }
    return switch (r.status) {
      200 => r,
      401 || 403 => throw const GroqUnauthorized(),
      429 => throw const GroqRateLimited(),
      >= 500 => throw GroqServerError(r.status),
      _ => throw const GroqBadResponse(),
    };
  }

  Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const GroqBadResponse();
    }
  }

  /// Returns the model's message content (expected to be a JSON object as text).
  Future<String> chatJson({required String model, required String system, required String user}) async {
    final (base, auth) = await _auth();
    final headers = {...auth, 'Content-Type': 'application/json'};
    final body = jsonEncode({
      'model': model,
      'temperature': 0,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
    });
    final r = await _send(() => _http.postJson(Uri.parse('$base/chat/completions'), headers, body, kChatTimeout));
    final json = _decode(r.body);
    if (json case {'choices': [{'message': {'content': final String content}}, ...]}) return content;
    throw const GroqBadResponse();
  }

  /// A receipt photo: the text prompt plus the JPEG as an OpenAI-style `image_url` data URL.
  Future<String> chatJsonWithImage({
    required String model,
    required String system,
    required String user,
    required Uint8List jpeg,
  }) async {
    final (base, auth) = await _auth();
    final headers = {...auth, 'Content-Type': 'application/json'};
    final body = jsonEncode({
      'model': model,
      'temperature': 0,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': system},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': user},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(jpeg)}'},
            },
          ],
        },
      ],
    });
    final r = await _send(() => _http.postJson(Uri.parse('$base/chat/completions'), headers, body, kVisionTimeout));
    final json = _decode(r.body);
    if (json case {'choices': [{'message': {'content': final String content}}, ...]}) return content;
    throw const GroqBadResponse();
  }

  Future<String> transcribe({required String model, required Uint8List wav}) async {
    final (base, headers) = await _auth();
    final r = await _send(
      () => _http.postMultipart(
        Uri.parse('$base/audio/transcriptions'),
        headers,
        {'model': model, 'response_format': 'json', 'temperature': '0'},
        'file',
        'capture.wav',
        wav,
        kSttTimeout,
      ),
    );
    if (_decode(r.body) case {'text': final String text}) return text;
    throw const GroqBadResponse();
  }
}
