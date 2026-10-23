import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/ai/groq_client.dart';
import 'package:life_manager/features/capture/speech/groq_stt.dart';
import 'package:life_manager/features/capture/speech/speech_to_text.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('GroqStt sends multipart file=capture.wav with the configured model', () async {
    final keys = GroqKeyStore(InMemorySecureStore());
    await keys.write(const Sensitive('gsk_5555'));
    final http = FakeHttpPort((_) => const HttpReply(200, '{"text":" غدا 12 دولار "}'));
    var model = 'whisper-large-v3';
    final stt = GroqStt(GroqClient(http, keys), () => model);
    final wav = Uint8List.fromList(List.filled(32, 1));
    expect(await stt.transcribe(wav), 'غدا 12 دولار');
    model = 'whisper-large-v3-turbo';
    await stt.transcribe(wav);
    expect(http.requests.map((r) => (r.fields!['model'], r.fileField, r.fileName)), [
      ('whisper-large-v3', 'file', 'capture.wav'),
      ('whisper-large-v3-turbo', 'file', 'capture.wav'),
    ]);
    expect(http.requests.first.file, wav);
  });

  test('NoSpeechEngine refuses with SpeechUnavailable', () {
    expect(() => const NoSpeechEngine().transcribe(Uint8List(4)), throwsA(isA<SpeechUnavailable>()));
  });
}
