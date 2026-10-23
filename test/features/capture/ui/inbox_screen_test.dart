import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/data/capture_repository.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';
import 'package:life_manager/features/capture/speech/model_manager.dart';
import 'package:life_manager/features/capture/speech/speech_to_text.dart' show modelManagerProvider;

import '../../../helpers/app_harness.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/finance_ui.dart';

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

/// Lets real async work run while a spinner is on screen (pumpAndSettle would wait forever).
Future<void> work(WidgetTester t, [int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  late Directory dir;
  late InMemorySecureStore store;
  late FakeHttpPort http;
  final wav = Uint8List.fromList(List.filled(32, 3));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('inbox');
    store = InMemorySecureStore();
    http = FakeHttpPort((_) => const HttpReply(500, 'down'));
  });
  tearDown(() => dir.delete(recursive: true));

  Future<ProviderContainer> open(WidgetTester t) => pumpApp(
    t,
    locale: 'en',
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      httpPortProvider.overrideWithValue(http),
      modelManagerProvider.overrideWithValue(ModelManager(http, () async => dir)),
    ],
  );

  Future<void> saveKey(WidgetTester t, ProviderContainer c) async {
    await t.runAsync(() => GroqKeyStore(store).write(const Sensitive('gsk_1234')));
    c.invalidate(groqKeySavedProvider);
    await settle(t);
  }

  testWidgets('a voice capture without transcript shows Transcribe and, with AI allowed, Finish with AI', (t) async {
    final c = await open(t);
    final repo = CaptureRepository(dbOf(c));
    late int id;
    await t.runAsync(() async {
      id = await repo.createVoice(wav);
      await repo.setFailure(id, 'SpeechUnavailable');
    });
    await pushRoute(t, c, '/inbox');

    expect(find.byKey(ValueKey('inbox-row-$id')), findsOneWidget);
    expect(find.text('Voice, not transcribed yet'), findsOneWidget);
    expect(find.textContaining('No speech engine yet'), findsOneWidget);
    expect(find.textContaining('SpeechUnavailable'), findsNothing, reason: 'never the raw type');
    expect(find.byKey(ValueKey('inbox-transcribe-$id')), findsOneWidget);
    expect(find.byKey(ValueKey('inbox-ai-$id')), findsNothing, reason: 'no key saved');

    await saveKey(t, c);
    expect(find.byKey(ValueKey('inbox-ai-$id')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-ai-all')), findsOneWidget);
  });

  testWidgets('Finish with AI on a low-confidence draft with a fake LLM reply opens the review', (t) async {
    final c = await open(t);
    final repo = CaptureRepository(dbOf(c));
    late int id;
    await t.runAsync(() async {
      id = await repo.createText('اربعين تكسي');
      await repo.setParsed(id, [const MoneyProposal(type: IntentType.expense, confidence: 40)], by: 'rules');
    });
    await saveKey(t, c);
    http.reply = (_) => _content(
      jsonEncode({
        'intents': [
          {'type': 'expense', 'amount': '40000', 'currency': 'IQD', 'description': 'taxi'},
        ],
      }),
    );
    await pushRoute(t, c, '/inbox');
    expect(find.textContaining('Not sure what you meant'), findsOneWidget);

    await t.tap(find.byKey(ValueKey('inbox-ai-$id')));
    await settle(t);
    expect(find.byKey(const ValueKey('consent-sheet')), findsOneWidget, reason: 'asks before sending');
    expect(http.requests, isEmpty);
    await t.tap(find.byKey(const ValueKey('consent-allow')));
    await work(t);
    await settle(t);

    expect(http.requests, hasLength(1));
    expect(find.byKey(const ValueKey('capture-review')), findsOneWidget);
    expect(find.byKey(const ValueKey('cap-badge-ai')), findsOneWidget);
  });

  testWidgets('Discard asks for confirmation and removes the row; the Home badge count drops by one', (t) async {
    final c = await open(t);
    final repo = CaptureRepository(dbOf(c));
    late int id;
    await t.runAsync(() async {
      id = await repo.createVoice(wav);
      await repo.createText('دفعت 40 الف تكسي');
    });
    await settle(t);
    expect(find.descendant(of: find.byKey(const ValueKey('open-inbox')), matching: find.text('2')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('open-inbox')));
    await settle(t);
    await t.tap(find.byKey(ValueKey('inbox-discard-$id')));
    await settle(t);
    expect(find.byKey(const ValueKey('inbox-discard-confirm')), findsOneWidget);
    expect(find.byKey(ValueKey('inbox-row-$id')), findsOneWidget, reason: 'nothing happens before the confirm');
    await t.tap(find.byKey(const ValueKey('inbox-discard-confirm')));
    await settle(t);
    expect(find.byKey(ValueKey('inbox-row-$id')), findsNothing);
    final row = (await t.runAsync(() => repo.get(id)))!;
    expect(row.status, 'discarded');
    expect(row.audio, isNull);

    await t.pageBack();
    await settle(t);
    expect(find.descendant(of: find.byKey(const ValueKey('open-inbox')), matching: find.text('1')), findsOneWidget);
  });

  testWidgets('With online AI disabled, no "Finish with AI" button appears anywhere', (t) async {
    final c = await open(t);
    final repo = CaptureRepository(dbOf(c));
    await t.runAsync(() async {
      await repo.createVoice(wav);
      final id = await repo.createText('اربعين تكسي');
      await repo.setParsed(id, [const MoneyProposal(type: IntentType.expense, confidence: 40)], by: 'rules');
      await c.read(settingsRepositoryProvider).setAiOnlineEnabled(false);
    });
    await saveKey(t, c);
    await pushRoute(t, c, '/inbox');

    expect(find.text('Finish with AI'), findsNothing);
    expect(find.text('Finish all with AI'), findsNothing);
    expect(find.text('Transcribe'), findsOneWidget);
    expect(find.text('Read again'), findsOneWidget);
  });

  testWidgets('empty Inbox says so; Finance overview links to it', (t) async {
    final c = await open(t);
    await pushRoute(t, c, '/inbox');
    expect(find.byKey(const ValueKey('inbox-empty')), findsOneWidget);
    await t.pageBack();
    await settle(t);
    await openFinance(t);
    await t.scrollUntilVisible(find.byKey(const ValueKey('open-inbox-tile')), 200);
    await t.tap(find.byKey(const ValueKey('open-inbox-tile')));
    await settle(t);
    expect(find.byKey(const ValueKey('inbox-screen')), findsOneWidget);
  });
}
