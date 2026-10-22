import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/ai/groq_client.dart';
import 'package:life_manager/features/capture/speech/groq_stt.dart';
import 'package:life_manager/features/capture/speech/local_whisper_stt.dart';
import 'package:life_manager/features/capture/speech/model_manager.dart';
import 'package:life_manager/features/capture/speech/speech_to_text.dart';
import 'package:life_manager/features/settings/settings_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/finance_fixtures.dart';

void main() {
  test('pickSpeechEngine: online when allowed; local when installed; NoSpeechEngine otherwise', () async {
    final f = await financeFixture();
    addTearDown(f.db.close);
    final dir = await Directory.systemTemp.createTemp('stt_pick');
    addTearDown(() => dir.delete(recursive: true));
    final settings = SettingsRepository(f.db);
    final keys = GroqKeyStore(InMemorySecureStore());
    final client = GroqClient(FakeHttpPort((_) => const HttpReply(200, '{}')), keys);
    final models = ModelManager(FakeHttpPort((_) => const HttpReply(500, '')), () async => dir);
    Future<SpeechToText> pick() async => pickSpeechEngine(await settings.get(), keys, client, models);

    expect(await pick(), isA<NoSpeechEngine>(), reason: 'no key, no model');

    await keys.write(const Sensitive('gsk_1'));
    await settings.setConsent(AiFeature.voice, ConsentState.granted);
    expect(await pick(), isA<GroqStt>());

    await settings.setAiOnlineEnabled(false);
    expect(await pick(), isA<NoSpeechEngine>(), reason: 'offline and no model installed');

    // Install the selected model by hand: a file of the pinned size.
    await settings.setLocalWhisperModel('base');
    final spec = kWhisperModels['base']!;
    await Directory('${dir.path}/models').create();
    final raf = await File('${dir.path}/models/${spec.fileName}').open(mode: FileMode.write);
    await raf.truncate(spec.sizeBytes);
    await raf.close();
    final local = await pick();
    expect(local, isA<LocalWhisperStt>());
    expect((local as LocalWhisperStt).modelFile.path, endsWith(spec.fileName));

    await settings.setLocalWhisperModel('small');
    expect(await pick(), isA<NoSpeechEngine>(), reason: 'the selected model is not installed');
  });
}
