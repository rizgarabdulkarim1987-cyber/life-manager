import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/providers.dart';
import 'package:life_manager/core/db/app_database.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/ai/groq_client.dart';
import 'package:life_manager/features/capture/capture_pipeline.dart';
import 'package:life_manager/features/capture/chat/conversation.dart';
import 'package:life_manager/features/capture/data/capture_repository.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';
import 'package:life_manager/features/capture/speech/model_manager.dart';
import 'package:life_manager/features/settings/settings_repository.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/finance_fixtures.dart';

HttpReply _llm(List<Map<String, Object?>> intents) => HttpReply(
  200,
  jsonEncode({
    'choices': [
      {
        'message': {
          'content': jsonEncode({'intents': intents}),
        },
      },
    ],
  }),
);

void main() {
  late FinanceFixture f;
  late Directory dir;
  late GroqKeyStore keys;
  late FakeHttpPort http;
  late ProviderContainer c;

  setUp(() async {
    f = await financeFixture();
    await f.db.update(f.db.appSettingsTable).write(const AppSettingsTableCompanion(localeCode: Value('en')));
    dir = await Directory.systemTemp.createTemp('chat');
    keys = GroqKeyStore(InMemorySecureStore());
    http = FakeHttpPort((_) => throw const SocketException('offline'));
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(f.db),
        capturePipelineProvider.overrideWithValue(
          CapturePipeline(
            db: f.db,
            keys: keys,
            client: GroqClient(http, keys),
            models: ModelManager(http, () async => dir),
            localEngine: (_) async => null,
          ),
        ),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await f.db.close();
    await dir.delete(recursive: true);
  });

  Conversation chat() => c.read(conversationProvider.notifier);
  List<ChatMessage> messages() => c.read(conversationProvider);
  AssistantMessage last() => messages().whereType<AssistantMessage>().last;

  Future<void> online(List<Map<String, Object?>> intents) async {
    await keys.write(const Sensitive('gsk_test'));
    await SettingsRepository(f.db).setConsent(AiFeature.parse, ConsentState.granted);
    http.reply = (_) => _llm(intents);
  }

  test('send shows the owner bubble, then a reply with one card to confirm', () async {
    await chat().send('دفعت 40 الف تكسي');
    expect(messages().first, isA<UserMessage>());
    expect((messages().first as UserMessage).text, 'دفعت 40 الف تكسي');
    final reply = last();
    expect(reply.cards, hasLength(1));
    expect(reply.cards.single.state, CardState.open);
    expect(reply.text, contains('40,000'));
    expect(await f.db.select(f.db.transactions).get(), isEmpty, reason: 'nothing is saved before OK');
  });

  test('a missing account is asked with account chips, and the answer fills it', () async {
    await (f.db.update(
      f.db.accounts,
    )..where((a) => a.id.equals(f.personalIqd))).write(const AccountsCompanion(isArchived: Value(true)));
    await chat().send('دفعت 40 الف تكسي');
    final ask = last();
    expect(ask.cards, isEmpty);
    expect(ask.replies, isNotEmpty);
    final buzz = ask.replies.firstWhere((r) => r.value == f.buzzIqd);
    await chat().answer(buzz);
    final card = last().cards.single;
    expect((card.proposal as MoneyProposal).accountId, f.buzzIqd);
  });

  test('typing the answer to a question works like tapping the chip', () async {
    await online([
      {'type': 'expense', 'amount': null, 'currency': 'IQD', 'category': null, 'description': 'taxi'},
    ]);
    await chat().send('taxi');
    expect(last().replies, isEmpty, reason: 'an amount is typed, not picked');
    await chat().send('15000');
    expect((last().cards.single.proposal as MoneyProposal).amountMinor, 15000);
    expect(messages().whereType<UserMessage>(), hasLength(2));
  });

  test('OK on the only card saves it and offers undo', () async {
    await chat().send('دفعت 40 الف تكسي');
    await chat().accept(last().cards.single);
    final txs = await f.db.select(f.db.transactions).get();
    expect(txs.single.amountMinor, 40000);
    expect(last().undoCaptureId, isNotNull);
  });

  test('two cards save together once both are decided', () async {
    await online([
      {'type': 'expense', 'amount': '25000', 'currency': 'IQD', 'account': 'Personal · Cash IQD'},
      {'type': 'expense', 'amount': '10000', 'currency': 'IQD', 'account': 'Personal · Cash IQD'},
    ]);
    await chat().send('25 الف اكل و 10 الاف تكسي');
    final cards = last().cards;
    expect(cards, hasLength(2));
    await chat().accept(cards[0]);
    expect(await f.db.select(f.db.transactions).get(), isEmpty);
    await chat().drop(cards[1]);
    final txs = await f.db.select(f.db.transactions).get();
    expect(txs.map((t) => t.amountMinor), [25000]);
  });

  test('dropping every card saves nothing and discards the capture', () async {
    await chat().send('دفعت 40 الف تكسي');
    final card = last().cards.single;
    await chat().drop(card);
    expect(await f.db.select(f.db.transactions).get(), isEmpty);
    expect((await CaptureRepository(f.db).get(card.captureId))!.status, 'discarded');
  });

  test('undo takes back what the capture saved', () async {
    await chat().send('دفعت 40 الف تكسي');
    await chat().accept(last().cards.single);
    await chat().undo(last().undoCaptureId!);
    expect(await f.db.select(f.db.transactions).get(), isEmpty);
    expect(last().text, isNotEmpty);
  });

  test('a low-confidence parse still shows a card with its question, not the inbox', () async {
    await chat().send('تكسي');
    final reply = last();
    expect(reply.cards.isNotEmpty || reply.replies.isNotEmpty || reply.asksFor != null, isTrue);
  });

  test('something it cannot read goes to the inbox and says so', () async {
    await chat().send('   ');
    expect(messages(), isEmpty, reason: 'blank text is ignored');
    await chat().send('مرحبا');
    expect(last().cards, isEmpty);
    expect(last().text, isNotEmpty);
  });

  test('delete by text: the card names the entry, OK deletes, undo brings it back', () async {
    await chat().send('دفعت 40 الف تكسي');
    await chat().accept(last().cards.single);
    await chat().send('احذف آخر مصروف');
    final card = last().cards.single;
    expect(card.proposal, isA<DeleteProposal>());
    expect(card.text, contains('دفعت تكسي'));
    expect(card.text, isNot(contains('40,000')), reason: 'an old entry is named without its amount');
    await chat().accept(card);
    expect(await f.db.select(f.db.transactions).get(), isEmpty);
    await chat().undo(last().undoCaptureId!);
    expect((await f.db.select(f.db.transactions).get()).single.amountMinor, 40000);
  });

  test('edit by text changes the amount of the last entry', () async {
    await chat().send('دفعت 40 الف تكسي');
    await chat().accept(last().cards.single);
    await chat().send('غير المبلغ لـ 30 الف');
    await chat().accept(last().cards.single);
    expect((await f.db.select(f.db.transactions).get()).single.amountMinor, 30000);
  });

  test('nothing to delete says so', () async {
    await chat().send('احذف آخر مصروف');
    expect(last().cards, isEmpty);
    expect(last().text, isNotEmpty);
  });
}
