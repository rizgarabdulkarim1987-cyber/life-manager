import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/ai/groq_client.dart';
import 'package:life_manager/features/capture/capture_pipeline.dart';
import 'package:life_manager/features/capture/data/capture_repository.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';
import 'package:life_manager/features/capture/speech/model_manager.dart';
import 'package:life_manager/features/capture/speech/speech_to_text.dart';
import 'package:life_manager/features/settings/settings_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/finance_fixtures.dart';

class _FakeStt implements SpeechToText {
  _FakeStt(this.text);

  final String text;
  int calls = 0;

  @override
  Future<String> transcribe(Uint8List wav) async {
    calls++;
    return text;
  }
}

HttpReply _content(String content) => HttpReply(
  200,
  jsonEncode({
    'choices': [
      {
        'message': {'content': content},
      },
    ],
  }),
);

void main() {
  late FinanceFixture f;
  late CaptureRepository captures;
  late SettingsRepository settings;
  late GroqKeyStore keys;
  late Directory dir;
  final wav = Uint8List.fromList(List.filled(64, 7));

  setUp(() async {
    f = await financeFixture();
    captures = CaptureRepository(f.db);
    settings = SettingsRepository(f.db);
    keys = GroqKeyStore(InMemorySecureStore());
    dir = await Directory.systemTemp.createTemp('pipeline');
  });
  tearDown(() async {
    await f.db.close();
    await dir.delete(recursive: true);
  });

  Future<void> allowOnline() async {
    await keys.write(const Sensitive('gsk_1234'));
    await settings.setConsent(AiFeature.voice, ConsentState.granted);
    await settings.setConsent(AiFeature.parse, ConsentState.granted);
  }

  CapturePipeline pipeline(FakeHttpPort http, {Future<SpeechToText?> Function(AppSetting s)? local}) => CapturePipeline(
    db: f.db,
    keys: keys,
    client: GroqClient(http, keys),
    models: ModelManager(http, () async => dir),
    localEngine: local,
  );

  group('pipeline fallbacks', () {
    test('row exists before any network call', () async {
      await allowOnline();
      final seen = <int>[];
      final http = FakeHttpPort((r) {
        if (r.uri.path.endsWith('transcriptions')) return const HttpReply(200, '{"text":"دفعت 40 الف تكسي"}');
        return const HttpReply(500, 'down');
      })..before = (_) async => seen.add(await captures.pendingCount());
      await pipeline(http).fromVoice(wav);
      expect(seen, isNotEmpty);
      expect(seen.first, 1);
    });

    test('Groq STT network error → local whisper used', () async {
      await allowOnline();
      final local = _FakeStt('دفعت 40 الف تكسي');
      final http = FakeHttpPort((r) {
        if (r.uri.path.endsWith('transcriptions')) throw const SocketException('offline');
        return const HttpReply(500, 'down');
      });
      final out = await pipeline(http, local: (_) async => local).fromVoice(wav);
      expect(local.calls, 1);
      expect(out, isA<ReadyForReview>());
      final row = (await captures.get((out as ReadyForReview).captureId))!;
      expect(row.transcript, 'دفعت 40 الف تكسي');
      expect(row.parsedBy, 'rules');
    });

    test('no engine → SavedToInbox noSpeechEngine with audio kept', () async {
      final http = FakeHttpPort((_) => throw StateError('no network expected'));
      final out = await pipeline(http, local: (_) async => null).fromVoice(wav);
      expect(out, isA<SavedToInbox>());
      out as SavedToInbox;
      expect(out.reasonKey, 'noSpeechEngine');
      final row = (await captures.get(out.captureId))!;
      expect(row.status, 'pending');
      expect(row.audio, wav);
      expect(row.failureType, 'SpeechUnavailable');
      expect(http.requests, isEmpty);
    });

    test('STT fails online and offline → SavedToInbox sttFailed, audio kept', () async {
      await allowOnline();
      final http = FakeHttpPort((_) => throw const SocketException('offline'));
      final out = await pipeline(http, local: (_) async => null).fromVoice(wav);
      out as SavedToInbox;
      expect(out.reasonKey, 'sttFailed');
      final row = (await captures.get(out.captureId))!;
      expect(row.audio, wav);
      expect(row.failureType, 'GroqNetworkError');
    });

    test('empty transcript → SavedToInbox empty', () async {
      final out = await pipeline(
        FakeHttpPort((_) => const HttpReply(500, '')),
        local: (_) async => _FakeStt('  '),
      ).fromVoice(wav);
      expect((out as SavedToInbox).reasonKey, 'empty');
    });

    test('LLM 429 → rules parse, ReadyForReview, parsedBy rules', () async {
      await allowOnline();
      final http = FakeHttpPort((_) => const HttpReply(429, '{}'));
      final out = await pipeline(http).fromText('دفعت 40 الف تكسي');
      expect(out, isA<ReadyForReview>());
      final row = (await captures.get((out as ReadyForReview).captureId))!;
      expect(row.parsedBy, 'rules');
      expect((decodeProposals(row.parsedJson!).single as MoneyProposal).amountMinor, 40000);
      expect(http.requests, hasLength(1));
    });

    test('LLM answer accepted → parsedBy ai', () async {
      await allowOnline();
      final http = FakeHttpPort(
        (_) => _content(
          jsonEncode({
            'intents': [
              {'type': 'expense', 'amount': '40000', 'currency': 'IQD', 'description': 'taxi'},
            ],
          }),
        ),
      );
      final out = await pipeline(http).fromText('دفعت 40 الف تكسي');
      final row = (await captures.get((out as ReadyForReview).captureId))!;
      expect(row.parsedBy, 'ai');
    });

    test('LLM malformed and rules find nothing → SavedToInbox lowConfidence', () async {
      await allowOnline();
      final http = FakeHttpPort((_) => _content('not json at all'));
      final out = await pipeline(http).fromText('؟؟ !! …');
      expect(out, isA<SavedToInbox>());
      expect((out as SavedToInbox).reasonKey, 'lowConfidence');
      final row = (await captures.get(out.captureId))!;
      expect(row.status, 'pending');
      expect(row.parsedBy, 'rules');
    });

    test('offline text capture never touches HttpPort', () async {
      final http = FakeHttpPort((_) => throw StateError('no network expected'));
      final out = await pipeline(http).fromText('دفعت 40 الف تكسي');
      expect(out, isA<ReadyForReview>());
      expect(http.requests, isEmpty);
      expect(await captures.pendingCount(), 1);
    });

    test('reparse uses the edited transcript and replaces the proposals', () async {
      final p = pipeline(FakeHttpPort((_) => throw StateError('no network expected')));
      final id = ((await p.fromText('دفعت 40 الف تكسي')) as ReadyForReview).captureId;
      await captures.setTranscript(id, 'دفعت 25 الف غدا');
      final out = await p.reparse(id);
      expect((out as ReadyForReview).captureId, id);
      final row = (await captures.get(id))!;
      expect((decodeProposals(row.parsedJson!).single as MoneyProposal).amountMinor, 25000);
    });
  });
}
