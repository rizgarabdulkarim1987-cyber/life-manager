import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/logging/app_logger.dart';
import 'package:life_manager/core/net/http_port.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/core/storage/secure_store.dart';
import 'package:life_manager/features/capture/ai/ai_config.dart';
import 'package:life_manager/features/capture/ai/ai_payload.dart';
import 'package:life_manager/features/capture/ai/groq_client.dart';
import 'package:life_manager/features/capture/ai/llm_parser.dart';
import 'package:life_manager/features/capture/data/capture_repository.dart';
import 'package:life_manager/features/capture/domain/lexicon.dart';
import 'package:life_manager/features/capture/domain/proposal.dart';
import 'package:life_manager/features/capture/rules/rule_parser.dart';
import 'package:life_manager/l10n/gen/app_localizations.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/finance_fixtures.dart';

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
  late Lexicon lex;
  late GroqKeyStore keys;
  final now = DateTime(2026, 10, 23, 15, 40);
  final lines = <String>[];
  late void Function(String) oldSink;

  setUp(() async {
    f = await financeFixture();
    lex = await loadLexicon(f.db, lookupAppLocalizations(const Locale('ar')));
    keys = GroqKeyStore(InMemorySecureStore());
    await keys.write(const Sensitive('gsk_1234'));
    lines.clear();
    oldSink = AppLogger.sink;
    AppLogger.sink = lines.add;
  });
  tearDown(() async {
    AppLogger.sink = oldSink;
    await f.db.close();
  });

  LlmParser parserWith(FakeHttpPort http) =>
      LlmParser(GroqClient(http, keys), () => 'llama-3.3-70b-versatile', const RuleParser());

  test('LlmParser falls back to rules on malformed json and logs only the type', () async {
    final p = parserWith(FakeHttpPort((_) => _content('{"intents":[{"type":"expense","amount":15000}]}')));
    final out = await p.parse('غدا 15 الف', lex, now);
    final rules = await const RuleParser().parse('غدا 15 الف', lex, now);
    expect(encodeProposals(out), encodeProposals(rules));
    expect(p.lastParsedBy, 'rules');
    expect(lines.join('\n'), contains('InvalidAiOutput'));
    expect(lines.join('\n'), isNot(contains('غدا')));
    expect(lines.join('\n'), isNot(contains('15000')));
  });

  test('network trouble and non-JSON content fall back to rules too', () async {
    for (final reply in <HttpReply Function(FakeRequest)>[
      (_) => throw TimeoutException('slow'),
      (_) => const HttpReply(500, 'oops'),
      (_) => _content('sure! here you go'),
    ]) {
      final p = parserWith(FakeHttpPort(reply));
      final out = await p.parse('دفعت 40 الف تكسي', lex, now);
      expect(p.lastParsedBy, 'rules');
      expect((out.single as MoneyProposal).amountMinor, 40000);
    }
  });

  test('valid AI output is used, and the request carries the minimal payload', () async {
    final http = FakeHttpPort(
      (_) => _content('{"intents":[{"type":"expense","amount":"15000","currency":"IQD","category":"أكل"}]}'),
    );
    final p = parserWith(http);
    final out = await p.parse('غدا 15 الف', lex, now);
    expect(p.lastParsedBy, 'ai');
    final m = out.single as MoneyProposal;
    expect((m.amountMinor, m.accountId, m.categoryId), (15000, f.personalIqd, f.cat('food')));
    final body = jsonDecode(http.requests.single.body!) as Map<String, Object?>;
    final messages = body['messages'] as List;
    expect((messages[0] as Map)['content'], kParseSystemPrompt);
    expect(jsonDecode((messages[1] as Map)['content'] as String), buildParsePayload('غدا 15 الف', lex, now));
  });
}
