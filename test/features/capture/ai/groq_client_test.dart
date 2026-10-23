import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/ai/groq_client.dart';
import 'package:life_manager/features/settings/settings_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/finance_fixtures.dart';

const _key = 'gsk_test_key_1234';

HttpReply _chat(String content) => HttpReply(
  200,
  jsonEncode({
    'choices': [
      {
        'message': {'role': 'assistant', 'content': content},
      },
    ],
  }),
);

void main() {
  late InMemorySecureStore store;
  late GroqKeyStore keys;

  setUp(() async {
    store = InMemorySecureStore();
    keys = GroqKeyStore(store);
    await keys.write(const Sensitive(_key));
  });

  test('chat request shape', () async {
    final http = FakeHttpPort((_) => _chat('{"intents":[]}'));
    final out = await GroqClient(http, keys).chatJson(model: 'llama-3.3-70b-versatile', system: 'S', user: 'U');
    expect(out, '{"intents":[]}');
    final r = http.requests.single;
    expect(r.uri.toString(), 'https://api.groq.com/openai/v1/chat/completions');
    expect(r.headers['Authorization'], 'Bearer $_key');
    expect(r.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(r.body!), {
      'model': 'llama-3.3-70b-versatile',
      'temperature': 0,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': 'S'},
        {'role': 'user', 'content': 'U'},
      ],
    });
  });

  test('transcription request shape', () async {
    final http = FakeHttpPort((_) => const HttpReply(200, '{"text":"دفعت 40 الف"}'));
    final wav = Uint8List.fromList([82, 73, 70, 70]);
    final text = await GroqClient(http, keys).transcribe(model: 'whisper-large-v3-turbo', wav: wav);
    expect(text, 'دفعت 40 الف');
    final r = http.requests.single;
    expect(r.uri.toString(), 'https://api.groq.com/openai/v1/audio/transcriptions');
    expect(r.headers['Authorization'], 'Bearer $_key');
    expect(r.fields, {'model': 'whisper-large-v3-turbo', 'response_format': 'json', 'temperature': '0'});
    expect((r.fileField, r.fileName, r.file), ('file', 'capture.wav', wav));
  });

  test('401 → GroqUnauthorized; 429 → GroqRateLimited; timeout → GroqNetworkError', () async {
    Future<Object> errorFor(HttpReply Function(FakeRequest) reply) async {
      try {
        await GroqClient(FakeHttpPort(reply), keys).chatJson(model: 'm', system: 's', user: 'u');
      } catch (e) {
        return e;
      }
      fail('expected an error');
    }

    expect(
      await errorFor((_) => const HttpReply(401, '{"error":"bad key gsk_test_key_1234"}')),
      isA<GroqUnauthorized>(),
    );
    expect(await errorFor((_) => const HttpReply(403, '')), isA<GroqUnauthorized>());
    expect(await errorFor((_) => const HttpReply(429, '')), isA<GroqRateLimited>());
    final server = await errorFor((_) => const HttpReply(503, 'down'));
    expect((server as GroqServerError).status, 503);
    expect(await errorFor((_) => const HttpReply(200, 'not json')), isA<GroqBadResponse>());
    expect(await errorFor((_) => const HttpReply(200, '{"choices":[]}')), isA<GroqBadResponse>());
    expect(await errorFor((_) => throw TimeoutException('slow')), isA<GroqNetworkError>());
    expect(await errorFor((_) => throw const SocketException('no route to api.groq.com')), isA<GroqNetworkError>());
    final unauthorized = await errorFor((_) => const HttpReply(401, 'gsk_test_key_1234'));
    expect('$unauthorized', isNot(contains(_key)));
  });

  test('no key: nothing is sent', () async {
    await keys.clear();
    final http = FakeHttpPort((_) => _chat('{}'));
    await expectLater(
      GroqClient(http, keys).chatJson(model: 'm', system: 's', user: 'u'),
      throwsA(isA<GroqUnauthorized>()),
    );
    expect(http.requests, isEmpty);
  });

  test('key store never returns an empty key and Sensitive hides it', () async {
    expect(() => keys.write(const Sensitive('   ')), throwsArgumentError);
    await keys.write(const Sensitive('  gsk_trim_me  '));
    final k = (await keys.read())!;
    expect(k.value, 'gsk_trim_me');
    expect('$k', isNot(contains('gsk')));
    await store.write(kGroqKeyStoreKey, '  ');
    expect(await keys.read(), isNull);
    await keys.clear();
    expect(await store.read(kGroqKeyStoreKey), isNull);
  });

  test('canUseOnline false without key, without consent, or with AI disabled', () async {
    final f = await financeFixture();
    addTearDown(f.db.close);
    final settings = SettingsRepository(f.db);
    Future<bool> can(AiFeature x) async => canUseOnline(x, await settings.get(), keys);

    expect(await can(AiFeature.parse), isFalse, reason: 'no consent yet');
    await settings.setConsent(AiFeature.parse, ConsentState.granted);
    expect(await can(AiFeature.parse), isTrue);
    expect(await can(AiFeature.voice), isFalse, reason: 'consent is per feature');
    await settings.setConsent(AiFeature.voice, ConsentState.declined);
    expect(await can(AiFeature.voice), isFalse);
    await settings.setAiOnlineEnabled(false);
    expect(await can(AiFeature.parse), isFalse, reason: 'AI switched off');
    await settings.setAiOnlineEnabled(true);
    await keys.clear();
    expect(await can(AiFeature.parse), isFalse, reason: 'no key');
  });
}
