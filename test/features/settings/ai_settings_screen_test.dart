import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/ai/consent.dart';
import 'package:life_manager/features/capture/speech/model_manager.dart';
import 'package:life_manager/features/capture/speech/speech_to_text.dart';
import 'package:life_manager/features/settings/settings_repository.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fakes.dart';
import '../../helpers/finance_ui.dart';

void main() {
  late InMemorySecureStore store;
  late FakeHttpPort http;

  setUp(() {
    store = InMemorySecureStore();
    http = FakeHttpPort((_) => const HttpReply(401, ''));
  });

  Future<ProviderContainer> open(WidgetTester t, {String locale = 'en', ModelManager? models}) async {
    final c = await pumpApp(
      t,
      locale: locale,
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        httpPortProvider.overrideWithValue(http),
        modelManagerProvider.overrideWithValue(
          models ?? ModelManager(http, () async => Directory('${Directory.systemTemp.path}/lm_ai_settings_test')),
        ),
      ],
    );
    await pushRoute(t, c, '/settings');
    final link = find.byKey(const ValueKey('settings-ai'));
    await t.scrollUntilVisible(link, 200, scrollable: find.byType(Scrollable).last);
    await t.ensureVisible(link);
    await settle(t);
    await t.tap(link);
    await settle(t);
    return c;
  }

  Future<void> reveal(WidgetTester t, String key) async {
    final f = find.byKey(ValueKey(key));
    await t.scrollUntilVisible(
      f,
      150,
      scrollable: find
          .descendant(of: find.byKey(const ValueKey('ai-settings')), matching: find.byType(Scrollable))
          .first,
    );
    await t.ensureVisible(f);
    await settle(t);
  }

  testWidgets('AI settings shows only the last 4 key chars', (t) async {
    await open(t);
    await t.enterText(find.byKey(const ValueKey('groq-key-field')), '  gsk_abcdefgh5678 ');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('groq-key-save')));
    await settle(t);
    expect(await store.read(kGroqKeyStoreKey), 'gsk_abcdefgh5678');
    expect(find.byKey(const ValueKey('groq-key-field')), findsNothing);
    final saved = t.widget<Text>(find.byKey(const ValueKey('groq-key-saved'))).data!;
    expect(saved, contains('5678'));
    expect(saved, isNot(contains('abcd')));
    expect(find.textContaining('gsk_abcdefgh'), findsNothing);

    await t.tap(find.byKey(const ValueKey('groq-key-clear')));
    await settle(t);
    expect(await store.read(kGroqKeyStoreKey), isNull);
    expect(find.byKey(const ValueKey('groq-key-field')), findsOneWidget);
  });

  testWidgets('test key reports unauthorized without showing the key', (t) async {
    await open(t);
    await t.enterText(find.byKey(const ValueKey('groq-key-field')), 'gsk_badkey9999');
    await settle(t);
    await t.tap(find.byKey(const ValueKey('groq-key-save')));
    await settle(t);
    await reveal(t, 'groq-test');
    await t.tap(find.byKey(const ValueKey('groq-test')));
    await settle(t);
    expect(http.requests.single.uri.path, '/openai/v1/chat/completions');
    final result = t.widget<Text>(find.byKey(const ValueKey('groq-test-result'))).data!;
    expect(result, isNotEmpty);
    expect(result, isNot(contains('badkey')));
  });

  testWidgets('online switch, model names and consent reset are saved', (t) async {
    final c = await open(t);
    final db = dbOf(c);
    final repo = SettingsRepository(db);
    await t.runAsync(() => repo.setConsent(AiFeature.parse, ConsentState.granted));
    await settle(t);

    await t.tap(find.byKey(const ValueKey('ai-online')));
    await settle(t);
    expect((await t.runAsync(repo.get))!.aiOnlineEnabled, isFalse);

    await reveal(t, 'consent-reset-parse');
    await t.tap(find.byKey(const ValueKey('consent-reset-parse')));
    await settle(t);
    expect((await t.runAsync(repo.get))!.aiParseConsent, isNull);

    await reveal(t, 'llm-model');
    await t.enterText(find.byKey(const ValueKey('llm-model')), 'llama-3.1-8b-instant');
    await t.tap(find.byKey(const ValueKey('models-save')));
    await settle(t);
    expect((await t.runAsync(repo.get))!.groqLlmModel, 'llama-3.1-8b-instant');
  });

  testWidgets('consent sheet declined → consent stored declined; not shown again', (t) async {
    final c = await open(t);
    final ctx = t.element(find.byKey(const ValueKey('ai-settings')));
    final first = ensureConsent(ctx, AiFeature.parse);
    await settle(t);
    expect(find.byKey(const ValueKey('consent-sheet')), findsOneWidget);
    expect(find.textContaining('Groq'), findsWidgets);
    expect(find.textContaining('vault'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('consent-decline')));
    await settle(t);
    expect(await first, isFalse);
    expect((await t.runAsync(() => SettingsRepository(dbOf(c)).get()))!.aiParseConsent, 'declined');

    final again = ensureConsent(ctx, AiFeature.parse);
    await settle(t);
    expect(find.byKey(const ValueKey('consent-sheet')), findsNothing);
    expect(await again, isFalse);
  });

  testWidgets('consent sheet allowed → granted', (t) async {
    final c = await open(t);
    final ctx = t.element(find.byKey(const ValueKey('ai-settings')));
    final r = ensureConsent(ctx, AiFeature.voice);
    await settle(t);
    await t.tap(find.byKey(const ValueKey('consent-allow')));
    await settle(t);
    expect(await r, isTrue);
    expect((await t.runAsync(() => SettingsRepository(dbOf(c)).get()))!.aiVoiceConsent, 'granted');
  });

  testWidgets('AI settings and the consent sheet fit a small phone in Arabic', (t) async {
    t.view.physicalSize = const Size(340, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await open(t, locale: 'ar');
    expect(t.takeException(), isNull);
    final ctx = t.element(find.byKey(const ValueKey('ai-settings')));
    ensureConsent(ctx, AiFeature.parse);
    await settle(t);
    expect(find.byKey(const ValueKey('consent-sheet')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  /// File work is real IO: let it run outside the fake clock until [f] shows.
  Future<void> waitFor(WidgetTester t, Finder f) async {
    for (var i = 0; i < 50 && f.evaluate().isEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump();
    }
    expect(f, findsOneWidget);
  }

  testWidgets('offline model: download is checked and installed, then deleted', (t) async {
    final dir = (await t.runAsync(() => Directory.systemTemp.createTemp('ai_models')))!;
    addTearDown(() => t.runAsync(() => dir.delete(recursive: true)));
    final bytes = List<int>.generate(3000, (i) => i & 0xff);
    WhisperModelSpec spec(String id) => WhisperModelSpec(
      id: id,
      fileName: 'ggml-$id.bin',
      url: Uri.parse('https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$id.bin'),
      sha256: sha256.convert(bytes).toString(),
      sizeBytes: bytes.length,
    );
    http.stream = (_) => Stream.fromIterable([bytes.sublist(0, 1000), bytes.sublist(1000)]);
    final models = ModelManager(http, () async => dir, specs: {'small': spec('small'), 'base': spec('base')});
    await open(t, models: models);
    await reveal(t, 'whisper-section');
    await waitFor(t, find.byKey(const ValueKey('whisper-install')));
    await t.ensureVisible(find.byKey(const ValueKey('whisper-install')));
    await t.tap(find.byKey(const ValueKey('whisper-install')));
    await waitFor(t, find.byKey(const ValueKey('whisper-installed')));
    expect(http.streamed.single.path, endsWith('ggml-small.bin'));
    expect(find.textContaining('Sorani'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('whisper-delete')));
    await waitFor(t, find.byKey(const ValueKey('whisper-install')));
    expect((await t.runAsync(() => models.installed('small'))), isNull);
  });
}
