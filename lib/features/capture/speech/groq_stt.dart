import 'dart:typed_data';

import '../ai/groq_client.dart';
import 'speech_to_text.dart';

class GroqStt implements SpeechToText {
  GroqStt(this._client, this._model);

  final GroqClient _client;
  final String Function() _model;

  @override
  Future<String> transcribe(Uint8List wav) async => (await _client.transcribe(model: _model(), wav: wav)).trim();
}
